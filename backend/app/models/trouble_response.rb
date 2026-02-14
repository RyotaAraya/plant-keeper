class TroubleResponse < ApplicationRecord
  belongs_to :trouble
  belongs_to :user

  enum :response_type, { investigation: 'investigation', repair: 'repair', replacement: 'replacement', observation: 'observation' }

  validates :description, presence: true
  validates :responded_at, presence: true
end
