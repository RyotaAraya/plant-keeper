class StockTransaction < ApplicationRecord
  belongs_to :stock
  belongs_to :user
  belongs_to :from_warehouse, class_name: 'Warehouse', optional: true
  belongs_to :to_warehouse, class_name: 'Warehouse', optional: true

  enum :transaction_type, { incoming: 'incoming', outgoing: 'outgoing', transfer: 'transfer', disposal: 'disposal' }

  validates :quantity, presence: true
  validates :transacted_at, presence: true
end
