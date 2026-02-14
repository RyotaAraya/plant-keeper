class Order < ApplicationRecord
  belongs_to :material
  belongs_to :user

  enum :status, { draft: 'draft', ordered: 'ordered', received: 'received', cancelled: 'cancelled' }

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :ordered_on, presence: true
end
