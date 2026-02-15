class Department < ApplicationRecord
  belongs_to :site
  belongs_to :parent, class_name: "Department", optional: true

  has_many :children, class_name: "Department", foreign_key: :parent_id, dependent: :destroy
  has_many :users, dependent: :restrict_with_error
  has_many :department_histories, dependent: :destroy
  has_many :checklist_templates, dependent: :restrict_with_error
  has_many :inspections, dependent: :restrict_with_error

  enum :department_type, { maintenance: "maintenance", operation: "operation", environment: "environment" }
  enum :level, { division: "division", section: "section", team: "team" }

  validates :name, presence: true

  # 部 > 課 > チーム のフルパスを返す
  def full_path
    ancestors = []
    current = self
    while current
      ancestors.unshift(current)
      current = current.parent
    end
    ancestors.map(&:name).join(" > ")
  end

  # 祖先チェーンを配列で返す（ルートから自身まで）
  def ancestor_chain
    chain = []
    current = self
    while current
      chain.unshift({ id: current.id, name: current.name, level: current.level })
      current = current.parent
    end
    chain
  end
end
