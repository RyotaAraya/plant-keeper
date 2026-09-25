class ChecklistTemplateItem < ApplicationRecord
  include ChecklistCriteria

  belongs_to :checklist_template

  has_many :inspection_items, dependent: :restrict_with_error

  # 点検の項目に写す基準（点検した時点の基準を残す。あとでテンプレートを変えても、過去の記録は変わらない）
  CRITERIA_ATTRIBUTES = %w[section criterion unit lower_limit upper_limit options required].freeze

  def criteria = attributes.slice(*CRITERIA_ATTRIBUTES)
end
