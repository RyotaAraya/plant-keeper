class Trouble < ApplicationRecord
  include StatusTransitions
  include InstrumentBelongsToEquipment

  # 完了（closed）からは戻せない。解決済からは再対応（対応中）に戻せる。
  # 定修待ち（deferred）は、運転中に直せないトラブルを定期整備の作業に回した状態（作業の完了で解決済、作業の見送り・削除で未対応に戻る）
  STATUS_TRANSITIONS = {
    "open" => %w[in_progress resolved closed deferred],
    "in_progress" => %w[open resolved closed deferred],
    "resolved" => %w[in_progress closed deferred],
    "deferred" => %w[open in_progress resolved closed],
    "closed" => []
  }.freeze

  belongs_to :inspection_item, optional: true
  belongs_to :equipment
  belongs_to :instrument, optional: true
  belongs_to :reported_by, class_name: "User"
  belongs_to :assigned_to, class_name: "User", optional: true

  has_many :trouble_responses, dependent: :destroy
  has_many :repairs, dependent: :restrict_with_error
  has_many :maintenance_tasks, dependent: :nullify

  enum :status, { open: "open", in_progress: "in_progress", deferred: "deferred", resolved: "resolved", closed: "closed" }
  enum :priority, { low: "low", medium: "medium", high: "high", critical: "critical" }

  validates :title, presence: true
  validates :reported_at, presence: true

  validate :deferred_needs_active_task
  before_save :stamp_resolved_at, if: :status_changed?

  # 見送りにしていない作業（定期整備で対応する予定の作業）
  def active_maintenance_task
    maintenance_tasks.where.not(status: "cancelled").order(:id).last
  end

  private

  # 定修待ちにできるのは、定期整備の作業に回したとき（作業のないまま、状態だけを定修待ちにできない）
  def deferred_needs_active_task
    return unless status_changed?(to: "deferred")

    errors.add(:status, "を定修待ちにするには、トラブル詳細の「定期整備に回す」で作業に回してください") unless persisted? && active_maintenance_task
  end

  # 解決日時はステータスから決める（クライアントの値は使わない）。解決済・完了で初めて記録し、再対応で消す
  def stamp_resolved_at
    if resolved? || closed?
      self.resolved_at ||= Time.current
    else
      self.resolved_at = nil
    end
  end
end
