class Order < ApplicationRecord
  include StatusTransitions

  # 下書き→発注済→受領済。キャンセルできるのは受領前だけ
  STATUS_TRANSITIONS = {
    "draft" => %w[ordered cancelled],
    "ordered" => %w[received cancelled],
    "received" => [],
    "cancelled" => []
  }.freeze

  belongs_to :material
  belongs_to :user
  belongs_to :warehouse, optional: true

  enum :status, { draft: "draft", ordered: "ordered", received: "received", cancelled: "cancelled" }

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :ordered_on, presence: true
  validate :warehouse_required_on_receipt, on: :update

  before_validation :default_received_on, if: -> { received? && received_on.blank? }

  private

  # 受領すると在庫に入庫するため、入庫先の倉庫が必要
  def warehouse_required_on_receipt
    errors.add(:warehouse_id, "を指定してください（受領した資材を入庫する倉庫）") if status_changed?(to: "received") && warehouse_id.blank?
  end

  def default_received_on
    self.received_on = Date.current
  end
end
