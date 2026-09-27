# 点検のまとまり（点検計画の親）。例: 「テレメータ計器の定期検査」の下に計器ごとの計画が並び、周期は計画ごとに持つ。
# 担当部署・法規区分で計画を絞り込めるようにする。既定の周期は、計画を足すときの初期値
class InspectionPlanGroup < ApplicationRecord
  REFERENCE_STANDARD_NAME = "%s 基準器の年次校正".freeze
  NO_TEMPLATE_NAME = "チェックリストなしの点検".freeze

  belongs_to :site
  belongs_to :department, optional: true
  belongs_to :regulation, optional: true

  has_many :inspection_plans, dependent: :restrict_with_error

  validates :name, presence: true
  validates :default_interval_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :department_in_site
  validate :name_unique_in_site

  scope :active, -> { where(is_active: true) }

  # まとまりを指定せずに作った計画の入れ先（既存の計画を移したマイグレーション CreateInspectionPlanGroups と同じ規則）。
  # 拠点 × チェックリストの名前（担当部署はチェックリストの部署）。基準器の校正は拠点ごとに1つ。なければ作る（計画と一緒に保存する）
  def self.default_for(site:, checklist_template: nil, reference_standard: false, interval_days: nil)
    name = if reference_standard then format(REFERENCE_STANDARD_NAME, site.name)
    elsif checklist_template then checklist_template.name
    else NO_TEMPLATE_NAME
    end
    find_or_initialize_by(site: site, name: name) do |group|
      department = checklist_template&.department
      group.department = department if department&.site_id == site.id
      group.default_interval_days = interval_days
    end
  end

  private

  def name_unique_in_site
    return if name.blank? || !self.class.where(site_id: site_id, name: name).where.not(id: id).exists?

    errors.add(:base, "「#{name}」は、同じ拠点のまとまりで使われています")
  end

  def department_in_site
    errors.add(:base, "担当部署は、まとまりと同じ拠点の部署にしてください") if department && department.site_id != site_id
  end
end
