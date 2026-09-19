class Trouble < ApplicationRecord
  include StatusTransitions
  include InstrumentBelongsToEquipment

  # 完了（closed）からは戻せない。解決済からは再対応（対応中）に戻せる
  STATUS_TRANSITIONS = {
    "open" => %w[in_progress resolved closed],
    "in_progress" => %w[open resolved closed],
    "resolved" => %w[in_progress closed],
    "closed" => []
  }.freeze

  belongs_to :inspection_item, optional: true
  belongs_to :equipment
  belongs_to :instrument, optional: true
  belongs_to :reported_by, class_name: "User"
  belongs_to :assigned_to, class_name: "User", optional: true

  has_many :trouble_responses, dependent: :destroy
  has_many :repairs, dependent: :restrict_with_error

  enum :status, { open: "open", in_progress: "in_progress", resolved: "resolved", closed: "closed" }
  enum :priority, { low: "low", medium: "medium", high: "high", critical: "critical" }

  validates :title, presence: true
  validates :reported_at, presence: true

  before_save :stamp_resolved_at, if: :status_changed?

  private

  # 解決日時はステータスから決める（クライアントの値は使わない）。解決済・完了で初めて記録し、再対応で消す
  def stamp_resolved_at
    if resolved? || closed?
      self.resolved_at ||= Time.current
    else
      self.resolved_at = nil
    end
  end
end
