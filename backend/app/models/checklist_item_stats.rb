# チェックリストのテンプレートの項目ごとに、実施回数と「不具合あり」の件数を集計する（項目の見直しの材料。AIは使わない）。
# 項目を変える・消すのは人で、ここでは数えるだけ。
# - 対象: 下書きを出た点検（提出・承認依頼中・承認済み）の、テンプレートの項目から作った点検の項目。期間は点検日、拠点は点検の代表の設備の拠点
# - 実施: 判定が良好か不具合あり（選択式・自由記述は判定なしで値を記入したものも）。該当なし（－）は実施に数えず別に数え、未記入は数えない
# テンプレートの項目を作り直したマイグレーションの前の記録は、項目との結び付きを外してあるため数えない
class ChecklistItemStats
  PERIODS = { "1y" => 1.year, "3y" => 3.years, "all" => nil }.freeze
  DEFAULT_PERIOD = "1y"
  PERFORMED = <<~SQL.squish.freeze
    inspection_items.result IN ('good', 'defect')
    OR (inspection_items.result IS NULL AND inspection_items.item_type IN ('choice', 'text') AND BTRIM(COALESCE(inspection_items.text_value, '')) <> '')
  SQL

  def self.valid_period?(period) = PERIODS.key?(period)

  def initialize(template, period: DEFAULT_PERIOD, site_ids: nil)
    @template = template
    @period = period
    @site_ids = site_ids
  end

  def result
    rows = counts
    {
      "period" => @period,
      "from" => from&.to_date,
      # 項目と結び付いた記録のある点検だけ（項目を作り直す前の点検は、項目ごとの件数に入らないため数えない）
      "inspections_count" => inspections.where(id: linked_items.select(:inspection_id)).count,
      "items" => @template.checklist_template_items.map do |item|
        row = rows[item.id] || {}
        item.slice(:id, :position, :section, :content, :item_type).merge(
          "performed_count" => row[:performed].to_i,
          "defect_count" => row[:defect].to_i,
          "na_count" => row[:na].to_i,
          "last_defect_at" => row[:last_defect_at]&.in_time_zone
        )
      end
    }
  end

  private

  def from
    duration = PERIODS.fetch(@period)
    duration && Time.current - duration
  end

  def inspections
    scope = Inspection.where(checklist_template_id: @template.id).where.not(status: "draft")
    scope = scope.where(inspected_at: from..) if from
    scope = scope.where(equipment_id: Equipment.where(site_id: @site_ids).select(:id)) if @site_ids
    scope
  end

  def linked_items = InspectionItem.where(checklist_template_item_id: @template.checklist_template_items.map(&:id))

  def counts
    linked_items.joins(:inspection).merge(inspections)
                .group(:checklist_template_item_id)
                .pluck(:checklist_template_item_id,
                       Arel.sql("COUNT(*) FILTER (WHERE #{PERFORMED})"),
                       Arel.sql("COUNT(*) FILTER (WHERE inspection_items.result = 'defect')"),
                       Arel.sql("COUNT(*) FILTER (WHERE inspection_items.result = 'na')"),
                       Arel.sql("MAX(inspections.inspected_at) FILTER (WHERE inspection_items.result = 'defect')"))
                .to_h { |id, performed, defect, na, last| [ id, { performed:, defect:, na:, last_defect_at: last } ] }
  end
end
