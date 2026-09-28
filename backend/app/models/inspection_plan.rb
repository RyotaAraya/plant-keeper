# 点検計画: 「この設備（計器）を、この周期で点検する」と「次はいつまでか」を持つ。
# 点検記録（Inspection）だけでは「やった」ことしか分からず、「やるべきなのにやっていない」を検出できないため
class InspectionPlan < ApplicationRecord
  include InstrumentBelongsToEquipment
  include CoversEquipments

  # 点検の対象は、設備か、基準器（年次の校正）のどちらか一方
  belongs_to :equipment, optional: true
  belongs_to :reference_standard, optional: true
  belongs_to :instrument, optional: true
  belongs_to :checklist_template, optional: true
  # 点検のまとまり（親）。指定しなければ、拠点 × チェックリストのまとまりに入れる（InspectionPlanGroup.default_for）
  belongs_to :inspection_plan_group, optional: true # 必須（DBも NOT NULL）。検証は group_in_same_site（日本語の文言にするため）

  has_many :inspections, dependent: :nullify
  has_many :inspection_plan_equipments, dependent: :destroy
  # 対象の設備（代表の設備を含む）。複数の設備をまとめた計画（巡回など）は、2つ以上になる
  has_many :equipments, through: :inspection_plan_equipments

  enum :inspection_type, { routine: "routine", periodic: "periodic", telemetry: "telemetry", operation_check: "operation_check" }

  validates :name, presence: true
  validates :interval_days, numericality: { only_integer: true, greater_than: 0 }
  validates :next_due_on, presence: true
  validate :exactly_one_target
  validate :template_is_not_turnaround
  validate :instrument_only_for_single_equipment
  validate :group_in_same_site

  before_validation :assign_default_group, unless: :inspection_plan_group

  scope :active, -> { where(is_active: true) }
  scope :overdue, -> { active.where(next_due_on: ...today) }
  scope :due_within, ->(days) { active.where(next_due_on: today..(today + days)) }
  # 拠点の計画（設備は設備の拠点、基準器は基準器の拠点）
  scope :for_sites, lambda { |site_ids|
    where(equipment_id: Equipment.where(site_id: site_ids).select(:id))
      .or(where(reference_standard_id: ReferenceStandard.where(site_id: site_ids).select(:id)))
  }

  # 機器の自己診断で、次回期限の前倒しを勧める状態（保守要求・仕様外）
  DIAGNOSTIC_ADVANCE_STATUSES = %w[maintenance_required out_of_specification].freeze

  # 機器の診断で、次回期限を前倒しする候補（決めるのは人。ここでは候補を出すだけ）:
  # 有効な計器の計画で、計器がいま保守要求・仕様外、期限が明日以降、かつ診断が出た日より前に点検したきり（点検していない）もの。
  # 診断が出た日以降に点検した計画・期限を今日以前にした計画は、もう候補にしない（同じ診断で候補を出し続けないため）。
  # #diagnostic_advance? と同じ規則（変えるときは両方を直す）
  scope :diagnostic_advance_candidates, lambda {
    active.where(next_due_on: (today + 1)..).joins(:instrument).where(instruments: { diagnostic_status: DIAGNOSTIC_ADVANCE_STATUSES })
          .where("inspection_plans.last_inspected_on IS NULL OR inspection_plans.last_inspected_on < " \
                 "(instruments.diagnostic_since AT TIME ZONE 'UTC' AT TIME ZONE ?)::date", Time.zone.tzinfo.name)
  }

  # 部署（まとまりの担当部署）の、有効な計器の点検計画の計器（サブクエリ。NOT IN で使えるよう NULL を含めない）
  def self.instrument_ids_for_departments(department_ids)
    active.where.not(instrument_id: nil)
          .where(inspection_plan_group_id: InspectionPlanGroup.where(department_id: department_ids).select(:id))
          .select(:instrument_id)
  end

  # アプリのタイムゾーン（日本時間）での今日。朝の時間帯に前日扱いにならない
  def self.today = Time.zone.today

  def overdue = is_active && next_due_on < self.class.today

  def days_until_due = (next_due_on - self.class.today).to_i

  # 機器の診断で、次回期限を前倒しする候補か（scope :diagnostic_advance_candidates と同じ規則）
  def diagnostic_advance?
    return false unless is_active && instrument&.diagnostic_status.in?(DIAGNOSTIC_ADVANCE_STATUSES) && instrument.diagnostic_since
    return false unless next_due_on > self.class.today

    last_inspected_on.nil? || last_inspected_on < instrument.diagnostic_since.in_time_zone.to_date
  end

  # 点検が実施されたら、実施日を起点に次回期限を進める。
  # 古い点検の後追い登録や、同じ点検の再保存で期限が戻らないよう、実施日が前回以前なら何もしない
  def complete!(inspected_on)
    return if last_inspected_on && inspected_on <= last_inspected_on

    update!(last_inspected_on: inspected_on, next_due_on: inspected_on + interval_days)
  end

  # 基準器の校正のように、次回期限が周期の計算ではなく校正の有効期限で決まるとき
  def reschedule!(last_inspected_on:, next_due_on:)
    update!(last_inspected_on: last_inspected_on, next_due_on: next_due_on)
  end

  # CoversEquipments が使う、対象設備の中間テーブル
  def equipment_links = inspection_plan_equipments

  # 計画の拠点（設備は設備の拠点、基準器は基準器の拠点）
  def site = equipment&.site || reference_standard&.site

  # チェックリストの（先頭の）5点校正の項目。なければ nil
  def calibration_template_item
    checklist_template&.checklist_template_items&.find(&:calibration?)
  end

  # 5点校正を回す計画か（計器が校正できて、チェックリストに5点校正の項目がある）。
  # 周期の見直しの候補（CalibrationIntervalReview）と、校正の作業指示の書き出し（CalibrationWorkOrder）の対象
  def five_point_calibration?
    return false unless instrument&.calibratable?

    calibration_template_item.present?
  end

  private

  def assign_default_group
    return unless site

    self.inspection_plan_group = InspectionPlanGroup.default_for(site: site, checklist_template: checklist_template,
                                                                 reference_standard: reference_standard.present?, interval_days: interval_days)
  end

  def group_in_same_site
    return unless site # 対象がないときは exactly_one_target が知らせる
    return errors.add(:base, "点検のまとまりを指定してください") unless inspection_plan_group

    errors.add(:base, "点検のまとまりは、計画と同じ拠点のものにしてください") if inspection_plan_group.site_id != site.id
  end

  # 計器を指定できるのは、設備が1つの計画だけ（計器は代表の設備のもの）
  def instrument_only_for_single_equipment
    errors.add(:instrument, "は、複数の設備をまとめた計画には指定できません") if instrument_id.present? && covered_equipment_ids.size > 1
  end

  # 定修のチェックリストは、点検計画ではなく、定期整備の作業で使う（変更したときだけ確認する）
  def template_is_not_turnaround
    return unless checklist_template&.cycle_turnaround? && (new_record? || checklist_template_id_changed?)

    errors.add(:checklist_template, "は定修のチェックリストのため、点検計画には使えません（定期整備の作業で使います）")
  end

  def exactly_one_target
    errors.add(:base, "点検の対象は、設備か基準器のどちらか一方を指定してください") if equipment_id.present? == reference_standard_id.present?
  end
end
