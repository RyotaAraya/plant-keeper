class Stock < ApplicationRecord
  belongs_to :material
  belongs_to :warehouse

  has_many :stock_transactions, dependent: :restrict_with_error
  has_many :repairs, dependent: :restrict_with_error

  enum :status, { available: "available", in_use: "in_use", awaiting_repair: "awaiting_repair", under_repair: "under_repair", disposed: "disposed" }

  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
