class LineClass < ApplicationRecord
  has_many :instruments, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
end
