class Material < ApplicationRecord
  belongs_to :manufacturer

  has_many :material_alternatives, dependent: :destroy
  has_many :stocks, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error

  has_many :alternative_materials, through: :material_alternatives

  has_many_attached :attachments

  enum :availability, { custom: "custom", catalog: "catalog", commodity: "commodity" }
  enum :category, { instrument: "instrument", valve: "valve", electrical: "electrical", piping: "piping" }
  enum :reorder_method, { reorder_point: "reorder_point", use_based: "use_based" }

  validates :part_number, presence: true
  validates :name, presence: true

  before_save :set_normalized_part_number

  private

  def set_normalized_part_number
    self.normalized_part_number = part_number&.gsub(/[-\s]/, "")
  end
end
