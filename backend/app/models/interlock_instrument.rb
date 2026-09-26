# インターロックに関係する計器（検出端・遮断弁など）
class InterlockInstrument < ApplicationRecord
  belongs_to :interlock
  belongs_to :instrument

  validates :instrument_id, uniqueness: { scope: :interlock_id }
end
