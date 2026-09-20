# 点検計画: 「この設備（計器）を、この周期で点検する」と「次はいつまでか」を持つ。
# 点検記録（Inspection）だけでは「やった」ことしか分からず、「やるべきなのにやっていない」を検出できないため
class InspectionPlan < ApplicationRecord
  include InstrumentBelongsToEquipment

  # 点検の対象は、設備か、基準器（年次の校正）のどちらか一方
  belongs_to :equipment, optional: true
  belongs_to :reference_standard, optional: true
  belongs_to :instrument, optional: true
  belongs_to :checklist_template, optional: true

  has_many :inspections, dependent: :nullify

  enum :inspection_type, { routine: "routine", periodic: "periodic", telemetry: "telemetry", operation_check: "operation_check" }

  validates :name, presence: true
  validates :interval_days, numericality: { only_integer: true, greater_than: 0 }
  validates :next_due_on, presence: true
  validate :exactly_one_target

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

  private

  def exactly_one_target
    errors.add(:base, "点検の対象は、設備か基準器のどちらか一方を指定してください") if equipment_id.present? == reference_standard_id.present?
  end
end
