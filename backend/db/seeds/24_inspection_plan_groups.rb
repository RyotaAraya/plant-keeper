# frozen_string_literal: true

puts "点検のまとまりに既定の周期と法規区分を設定中..."

# まとまりは点検計画を作るときに、拠点 × チェックリストで作られる（InspectionPlanGroup.default_for。既定の周期は最初の計画の周期）。
# 既存環境を移したマイグレーション（CreateInspectionPlanGroups）とそろえ、既定の周期を、まとめた計画で最も多い周期（同数なら短いほう）にする。
# あわせて、法定の点検のまとまりに法規区分を付ける（定義は db/data/inspection_plan_groups.rb）
require Rails.root.join("db/data/inspection_plan_groups")

InspectionPlanGroup.includes(:inspection_plans).find_each do |group|
  interval = group.inspection_plans.map(&:interval_days).tally.max_by { |days, count| [ count, -days ] }&.first
  group.update!(default_interval_days: interval) if interval
end

InspectionPlanGroupCatalog::REGULATIONS.each do |name, code|
  InspectionPlanGroup.where(name: name).update_all(regulation_id: Regulation.find_by!(code: code).id)
end
