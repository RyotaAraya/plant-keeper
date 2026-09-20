# 既存の監査ログに、変更されたデータの拠点を埋める。
# 1件ずつモデルをたどらず、対象の種類ごとに1回のUPDATEでまとめて埋める（記録が多くても短時間で終わり、モデルのコードにも依存しない）。
# 拠点が決まらないもの（全社共通のマスタなど）は NULL のまま。何度実行しても同じ結果になる。
# 対象の種類を増やしたときは、AuditLog.site_id_for と、ここの SOURCES にも足す
class BackfillAuditLogSites < ActiveRecord::Migration[8.0]
  VIA_EQUIPMENT = "JOIN equipments e ON e.id = t.equipment_id".freeze
  VIA_DEPARTMENT = "JOIN departments d ON d.id = t.department_id".freeze
  VIA_WAREHOUSE = "JOIN warehouses w ON w.id = t.warehouse_id".freeze

  # 対象の種類 => [テーブル, 拠点を求めるためのJOIN, 拠点IDの式]（テーブルの別名は t）
  SOURCES = {
    "Site" => [ "sites", "", "t.id" ],
    "User" => [ "users", "", "t.site_id" ],
    "Equipment" => [ "equipments", "", "t.site_id" ],
    "Warehouse" => [ "warehouses", "", "t.site_id" ],
    "Department" => [ "departments", "", "t.site_id" ],
    "DepartmentHistory" => [ "department_histories", VIA_DEPARTMENT, "d.site_id" ],
    "ChecklistTemplate" => [ "checklist_templates", VIA_DEPARTMENT, "d.site_id" ],
    "EquipmentAssignment" => [ "equipment_assignments", VIA_EQUIPMENT, "e.site_id" ],
    "Instrument" => [ "instruments", VIA_EQUIPMENT, "e.site_id" ],
    "Inspection" => [ "inspections", VIA_EQUIPMENT, "e.site_id" ],
    "InspectionPlan" => [ "inspection_plans", VIA_EQUIPMENT, "e.site_id" ],
    "Trouble" => [ "troubles", VIA_EQUIPMENT, "e.site_id" ],
    "ScheduledMaintenance" => [ "scheduled_maintenances", VIA_EQUIPMENT, "e.site_id" ],
    "InspectionItem" => [
      "inspection_items",
      "JOIN inspections i ON i.id = t.inspection_id JOIN equipments e ON e.id = i.equipment_id",
      "e.site_id"
    ],
    "TroubleResponse" => [
      "trouble_responses",
      "JOIN troubles r ON r.id = t.trouble_id JOIN equipments e ON e.id = r.equipment_id",
      "e.site_id"
    ],
    "MaintenanceAssignment" => [
      "maintenance_assignments",
      "JOIN scheduled_maintenances m ON m.id = t.scheduled_maintenance_id JOIN equipments e ON e.id = m.equipment_id",
      "e.site_id"
    ],
    "Stock" => [ "stocks", VIA_WAREHOUSE, "w.site_id" ],
    "Order" => [ "orders", VIA_WAREHOUSE, "w.site_id" ],
    "Repair" => [
      "repairs",
      "JOIN stocks s ON s.id = t.stock_id JOIN warehouses w ON w.id = s.warehouse_id",
      "w.site_id"
    ],
    "StockTransaction" => [
      "stock_transactions",
      "LEFT JOIN warehouses tw ON tw.id = t.to_warehouse_id " \
      "LEFT JOIN warehouses fw ON fw.id = t.from_warehouse_id " \
      "LEFT JOIN stocks s ON s.id = t.stock_id " \
      "LEFT JOIN warehouses sw ON sw.id = s.warehouse_id",
      "COALESCE(tw.site_id, fw.site_id, sw.site_id)"
    ]
  }.freeze

  def up
    SOURCES.each do |type, (table, joins, site_expr)|
      execute <<~SQL.squish
        UPDATE audit_logs a
        SET site_id = src.site_id
        FROM (SELECT t.id AS target_id, #{site_expr} AS site_id FROM #{table} t #{joins}) src
        WHERE a.auditable_type = #{connection.quote(type)}
          AND a.auditable_id = src.target_id
          AND a.site_id IS NULL
          AND src.site_id IS NOT NULL
      SQL
    end
  end

  def down
    # 埋めた拠点は、列ごと AddSiteToAuditLogs の down で消える。ここでは何もしない
  end
end
