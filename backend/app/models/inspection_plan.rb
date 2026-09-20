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

  scope :active, -> { where(is_active: true) }
  scope :overdue, -> { active.where(next_due_on: ...today) }
  scope :due_within, ->(days) { active.where(next_due_on: today..(today + days)) }
  # 拠点の計画（設備は設備の拠点、基準器は基準器の拠点）
  scope :for_sites, lambda { |site_ids|
    where(equipment_id: Equipment.where(site_id: site_ids).select(:id))
      .or(where(reference_standard_id: ReferenceStandard.where(site_id: site_ids).select(:id)))
  }

  # アプリのタイムゾーン（日本時間）での今日。朝の時間帯に前日扱いにならない
  def self.today = Time.zone.today

  def overdue = is_active && next_due_on < self.class.today

  def days_until_due = (next_due_on - self.class.today).to_i

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

  private

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
