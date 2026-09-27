# 法規区分（高圧ガス保安法・ボイラー則など）。どの設備・計器がどの法規の対象かが、点検周期を決める起点になる
class Regulation < ApplicationRecord
  has_many :regulation_inspections, -> { order(:interval_days) }, dependent: :destroy
  has_many :equipment_regulations, dependent: :restrict_with_error
  has_many :equipments, through: :equipment_regulations
  has_many :inspection_plan_groups, dependent: :restrict_with_error

  # 法規が掛かる単位。計器単位のもの（取引メータ）は設備には付けられない
  enum :target, { equipment: "equipment", instrument: "instrument" }, prefix: true

  validates :code, presence: true, uniqueness: true
  validates :name, :law_name, presence: true
end
