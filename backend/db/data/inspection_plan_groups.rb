# 点検のまとまり（点検計画の親）のデモ用の法規区分。シード（24_inspection_plan_groups.rb）と、
# 既存環境へ反映するマイグレーション（CreateInspectionPlanGroups）が共有する。
# まとまりの名前（どの拠点でも）→ 法規区分のコード。周期などはデモ用の想定
module InspectionPlanGroupCatalog
  REGULATIONS = {
    "安全弁 年次点検" => "boiler_pressure_vessel",
    "タンク液面計 年次点検" => "fire_service"
  }.freeze
end
