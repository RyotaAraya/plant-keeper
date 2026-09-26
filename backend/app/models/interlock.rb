# インターロック（安全計装。異常時にプラントを自動で止める仕組み）の台帳。
# 関係する計器（検出端・遮断弁など）を持ち、点検・故障のときの一時的なバイパスは InterlockBypass で管理する
class Interlock < ApplicationRecord
  belongs_to :equipment

  has_many :interlock_instruments, dependent: :destroy
  has_many :instruments, through: :interlock_instruments
  has_many :bypasses, -> { order(requested_at: :desc, id: :desc) }, class_name: "InterlockBypass", dependent: :restrict_with_error

  validates :tag_number, presence: true, uniqueness: { scope: :equipment_id }
  validates :name, presence: true
  validate :instruments_belong_to_equipment

  scope :active, -> { where(is_active: true) }

  # 終わっていない（申請中〜復帰確認待ち）バイパス。1つのインターロックに1件だけ
  def open_bypass = bypasses.detect(&:open?)

  private

  def instruments_belong_to_equipment
    return if equipment_id.nil?

    others = instruments.reject { |instrument| instrument.equipment_id == equipment_id }
    errors.add(:base, "関係する計器（#{others.map(&:tag_number).join('、')}）が、インターロックの設備に属していません") if others.any?
  end
end
