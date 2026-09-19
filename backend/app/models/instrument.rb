class Instrument < ApplicationRecord
  belongs_to :equipment
  belongs_to :service, optional: true
  belongs_to :line_class, optional: true

  has_many :inspections, dependent: :restrict_with_error
  has_many :inspection_items, dependent: :restrict_with_error
  has_many :troubles, dependent: :restrict_with_error

  validates :tag_number, presence: true
  validate :tag_number_unique_within_site

  private

  # タグ番号は拠点内で一意（別拠点なら同じ番号があり得る）
  def tag_number_unique_within_site
    return if tag_number.blank? || equipment.nil?

    duplicates = Instrument.joins(:equipment)
                           .where(tag_number: tag_number, equipments: { site_id: equipment.site_id })
    duplicates = duplicates.where.not(id: id) if persisted?
    errors.add(:tag_number, :taken) if duplicates.exists?
  end
end
