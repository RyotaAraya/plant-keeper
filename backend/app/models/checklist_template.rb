require Rails.root.join("db/data/checklist_templates")

class ChecklistTemplate < ApplicationRecord
  # 選択肢・一覧の並び: カタログ（db/data/checklist_templates.rb）の順。作成順には頼らない
  # （シードは巡回点検が先頭になるが、マイグレーションで足した環境では最後になるため）
  DISPLAY_ORDER = ChecklistTemplateCatalog::TEMPLATES.map { |template| template[:name] }.freeze

  # カタログにないもの（廃止した旧テンプレート・利用者が作ったもの）は、カタログのあとに作成順
  def self.in_display_order(templates)
    templates.sort_by { |template| [ DISPLAY_ORDER.index(template.name) || DISPLAY_ORDER.size, template.id ] }
  end

  belongs_to :department

  has_many :checklist_template_items, -> { order(:position) }, dependent: :destroy
  has_many :inspections, dependent: :restrict_with_error

  enum :inspection_type, { routine: "routine", periodic: "periodic", telemetry: "telemetry", operation_check: "operation_check" }

  # 周期: patrol=巡回 / monthly=月次 / annual=年次 / turnaround=定修（定期整備の作業で使い、点検計画には使えない）
  enum :cycle, { patrol: "patrol", monthly: "monthly", annual: "annual", turnaround: "turnaround" }, prefix: true

  validates :name, presence: true
end
