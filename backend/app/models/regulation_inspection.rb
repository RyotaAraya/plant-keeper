# 法規区分ごとの法定検査（名称と周期）。周期は日数で持つ（点検計画の interval_days と同じ単位）
class RegulationInspection < ApplicationRecord
  belongs_to :regulation

  # statutory=法定 / voluntary=自主（社内標準）
  enum :basis, { statutory: "statutory", voluntary: "voluntary" }

  validates :name, presence: true
  validates :interval_days, numericality: { only_integer: true, greater_than: 0 }
end
