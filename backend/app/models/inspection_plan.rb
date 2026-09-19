# 点検計画: 「この設備（計器）を、この周期で点検する」と「次はいつまでか」を持つ。
# 点検記録（Inspection）だけでは「やった」ことしか分からず、「やるべきなのにやっていない」を検出できないため
class InspectionPlan < ApplicationRecord
  # 期限の判定は現場（日本）の日付で行う。DBはUTCなので、朝の時間帯に前日扱いにならないようにする
  PLANT_TIME_ZONE = "Asia/Tokyo".freeze

  belongs_to :equipment
  belongs_to :instrument, optional: true
  belongs_to :checklist_template, optional: true

  has_many :inspections, dependent: :nullify

  enum :inspection_type, { routine: "routine", periodic: "periodic", telemetry: "telemetry", operation_check: "operation_check" }

  validates :name, presence: true
  validates :interval_days, numericality: { only_integer: true, greater_than: 0 }
  validates :next_due_on, presence: true
  validate :instrument_belongs_to_equipment

  scope :active, -> { where(is_active: true) }
  scope :overdue, -> { active.where(next_due_on: ...today) }
  scope :due_within, ->(days) { active.where(next_due_on: today..(today + days)) }

  def self.today = Time.find_zone!(PLANT_TIME_ZONE).today

  def overdue = is_active && next_due_on < self.class.today

  def days_until_due = (next_due_on - self.class.today).to_i

  # 点検が実施されたら、実施日を起点に次回期限を進める。
  # 古い点検の後追い登録や、同じ点検の再保存で期限が戻らないよう、実施日が前回以前なら何もしない
  def complete!(inspected_on)
    return if last_inspected_on && inspected_on <= last_inspected_on

    update!(last_inspected_on: inspected_on, next_due_on: inspected_on + interval_days)
  end

  private

  def instrument_belongs_to_equipment
    return if instrument.nil? || equipment.nil?

    errors.add(:instrument, "は選択した設備の計器ではありません") if instrument.equipment_id != equipment_id
  end
end
