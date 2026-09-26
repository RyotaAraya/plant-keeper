class Stock < ApplicationRecord
  belongs_to :material
  belongs_to :warehouse

  has_many :stock_transactions, dependent: :restrict_with_error
  has_many :repairs, dependent: :restrict_with_error

  enum :status, { available: "available", in_use: "in_use", awaiting_repair: "awaiting_repair", under_repair: "under_repair", disposed: "disposed" }

  # 入出庫（出庫・廃棄・移動・入庫）できる状態。修理待ち・修理中は修理管理の操作だけで変え、廃棄済みは動かさない
  TRANSACTABLE_STATUSES = %w[available in_use].freeze

  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
