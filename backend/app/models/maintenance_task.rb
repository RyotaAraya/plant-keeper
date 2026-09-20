# 定期整備の作業（部署ごとに、どの設備・計器で何をするか）。
# 点検の作業は、対象の計器とチェックリスト（定修点検）を持ち、点検記録が下書きを出ると完了になる
class MaintenanceTask < ApplicationRecord
  include StatusTransitions
  include InstrumentBelongsToEquipment

  belongs_to :scheduled_maintenance
  belongs_to :department, optional: true
  belongs_to :equipment
  belongs_to :instrument, optional: true
  belongs_to :checklist_template, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true

  has_many :inspections, dependent: :nullify

  # inspection=点検 / overhaul=整備 / replacement=交換 / work=工事
  enum :kind, { inspection: "inspection", overhaul: "overhaul", replacement: "replacement", work: "work" }, prefix: true
  # not_started=未着手 / in_progress=実施中 / completed=完了 / cancelled=見送り
  enum :status, { not_started: "not_started", in_progress: "in_progress", completed: "completed", cancelled: "cancelled" }

  STATUS_TRANSITIONS = {
    "not_started" => %w[in_progress completed cancelled],
    "in_progress" => %w[not_started completed cancelled],
    "completed" => %w[in_progress not_started],
    "cancelled" => %w[not_started]
  }.freeze

  # 計器の種類 => 定修点検のチェックリスト
  TEMPLATE_NAMES = {
    transmitter: "伝送器 定修点検", positioner: "調節弁 定修点検",
    shutoff_valve: "遮断弁・インターロック 定修点検", safety_valve: "安全弁 定修点検"
  }.freeze

  before_validation :fill_title
  before_save :stamp_completed_on, if: :status_changed?

  validates :title, presence: true
  validate :equipment_is_in_maintenance
  validate :department_is_in_site
  validate :checklist_template_is_for_inspection

  # 計器の種類から、使う定修点検のチェックリストの種類。テンプレートのない計器（手動弁など）は nil
  def self.template_key_for(instrument)
    return :safety_valve if instrument.instrument_type == "safety_valve"
    return :shutoff_valve if instrument.instrument_type == "shutoff_valve"

    { "transmitter" => :transmitter, "positioner" => :positioner }[instrument.calibration_kind]
  end

  def self.turnaround_template_for(instrument)
    key = template_key_for(instrument)
    key && ChecklistTemplate.where(name: TEMPLATE_NAMES.fetch(key), cycle: "turnaround", is_active: true).order(:id).first
  end

  # 点検記録が下書きを出たら、作業を完了にする（完了日は点検日）。見送りにした作業は変えない
  def complete_by_inspection!(date)
    return if completed? || cancelled?

    update!(status: "completed", completed_on: date)
  end

  # 未完了（未着手・実施中）か
  def unfinished? = not_started? || in_progress?

  private

  # 内容が空のとき、点検の作業は「計器のタグ番号 チェックリスト名」にする
  def fill_title
    return if title.present?

    self.title = [ instrument&.tag_number, checklist_template&.name ].compact.join(" ").presence
  end

  def stamp_completed_on
    if completed?
      self.completed_on ||= Date.current
    else
      self.completed_on = nil
    end
  end

  def equipment_is_in_maintenance
    return if scheduled_maintenance.nil? || equipment.nil?

    errors.add(:equipment, "は、定期整備の対象設備にしてください") unless scheduled_maintenance.equipment_ids.include?(equipment_id)
  end

  def department_is_in_site
    return if department.nil? || scheduled_maintenance.nil?

    errors.add(:department, "は、定期整備と同じ拠点の部署にしてください") if department.site_id != scheduled_maintenance.site_id
  end

  def checklist_template_is_for_inspection
    errors.add(:checklist_template, "は点検の作業にだけ指定できます") if checklist_template && !kind_inspection?
  end
end
