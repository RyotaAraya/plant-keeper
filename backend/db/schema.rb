# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_21_050000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_suggestions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "equipment_id", null: false
    t.bigint "instrument_id"
    t.string "kind", null: false
    t.string "status", default: "pending", null: false
    t.string "model"
    t.jsonb "input_json", default: {}, null: false
    t.jsonb "output_json"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.string "error_class"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_suggestions_on_created_at"
    t.index ["equipment_id"], name: "index_ai_suggestions_on_equipment_id"
    t.index ["instrument_id"], name: "index_ai_suggestions_on_instrument_id"
    t.index ["user_id", "created_at"], name: "index_ai_suggestions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_ai_suggestions_on_user_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.jsonb "changes_json", default: {}
    t.string "ip_address"
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.bigint "site_id"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["performed_at"], name: "index_audit_logs_on_performed_at"
    t.index ["site_id"], name: "index_audit_logs_on_site_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "checklist_template_items", force: :cascade do |t|
    t.bigint "checklist_template_id", null: false
    t.integer "position", null: false
    t.string "content", null: false
    t.string "item_type", default: "check", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checklist_template_id"], name: "index_checklist_template_items_on_checklist_template_id"
  end

  create_table "checklist_templates", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "department_id", null: false
    t.string "inspection_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "cycle"
    t.index ["department_id"], name: "index_checklist_templates_on_department_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "company_type", default: "owner", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_type"], name: "index_companies_on_company_type"
  end

  create_table "department_histories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "department_id", null: false
    t.date "started_on", null: false
    t.date "ended_on"
    t.string "role_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_department_histories_on_department_id"
    t.index ["user_id"], name: "index_department_histories_on_user_id"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", null: false
    t.string "department_type", null: false
    t.bigint "site_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_id"
    t.string "level", default: "section", null: false
    t.index ["department_type"], name: "index_departments_on_department_type"
    t.index ["level"], name: "index_departments_on_level"
    t.index ["parent_id"], name: "index_departments_on_parent_id"
    t.index ["site_id"], name: "index_departments_on_site_id"
  end

  create_table "equipment_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "equipment_id", null: false
    t.string "role"
    t.date "started_on", null: false
    t.date "ended_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_equipment_assignments_on_equipment_id"
    t.index ["user_id"], name: "index_equipment_assignments_on_user_id"
  end

  create_table "equipment_regulations", force: :cascade do |t|
    t.bigint "equipment_id", null: false
    t.bigint "regulation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id", "regulation_id"], name: "index_equipment_regulations_on_equipment_id_and_regulation_id", unique: true
    t.index ["equipment_id"], name: "index_equipment_regulations_on_equipment_id"
    t.index ["regulation_id"], name: "index_equipment_regulations_on_regulation_id"
  end

  create_table "equipments", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "site_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id"], name: "index_equipments_on_site_id"
  end

  create_table "inspection_items", force: :cascade do |t|
    t.bigint "inspection_id", null: false
    t.bigint "checklist_template_item_id"
    t.integer "position", null: false
    t.string "content", null: false
    t.string "item_type", default: "check", null: false
    t.boolean "checked"
    t.string "measured_value"
    t.text "text_value"
    t.boolean "has_defect", default: false
    t.bigint "instrument_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "calibration_data"
    t.string "calibration_result"
    t.index ["checklist_template_item_id"], name: "index_inspection_items_on_checklist_template_item_id"
    t.index ["inspection_id"], name: "index_inspection_items_on_inspection_id"
    t.index ["instrument_id"], name: "index_inspection_items_on_instrument_id"
  end

  create_table "inspection_plans", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "equipment_id"
    t.bigint "instrument_id"
    t.bigint "checklist_template_id"
    t.string "inspection_type", null: false
    t.integer "interval_days", null: false
    t.date "last_inspected_on"
    t.date "next_due_on", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "reference_standard_id"
    t.index ["checklist_template_id"], name: "index_inspection_plans_on_checklist_template_id"
    t.index ["equipment_id"], name: "index_inspection_plans_on_equipment_id"
    t.index ["instrument_id"], name: "index_inspection_plans_on_instrument_id"
    t.index ["next_due_on"], name: "index_inspection_plans_on_next_due_on"
    t.index ["reference_standard_id"], name: "index_inspection_plans_on_reference_standard_id"
    t.check_constraint "(equipment_id IS NOT NULL) <> (reference_standard_id IS NOT NULL)", name: "inspection_plans_one_target"
    t.check_constraint "interval_days > 0", name: "inspection_plans_interval_positive"
  end

  create_table "inspection_reference_standards", force: :cascade do |t|
    t.bigint "inspection_id", null: false
    t.bigint "reference_standard_id", null: false
    t.boolean "pre_check_passed"
    t.string "pre_check_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inspection_id", "reference_standard_id"], name: "index_inspection_reference_standards_unique", unique: true
    t.index ["inspection_id"], name: "index_inspection_reference_standards_on_inspection_id"
    t.index ["reference_standard_id"], name: "index_inspection_reference_standards_on_reference_standard_id"
  end

  create_table "inspections", force: :cascade do |t|
    t.bigint "checklist_template_id"
    t.bigint "user_id", null: false
    t.bigint "equipment_id", null: false
    t.bigint "instrument_id"
    t.bigint "department_id", null: false
    t.string "inspection_type", null: false
    t.string "status", default: "draft", null: false
    t.datetime "inspected_at", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "inspection_plan_id"
    t.bigint "maintenance_task_id"
    t.index ["checklist_template_id"], name: "index_inspections_on_checklist_template_id"
    t.index ["department_id"], name: "index_inspections_on_department_id"
    t.index ["equipment_id"], name: "index_inspections_on_equipment_id"
    t.index ["inspection_plan_id"], name: "index_inspections_on_inspection_plan_id"
    t.index ["inspection_type"], name: "index_inspections_on_inspection_type"
    t.index ["instrument_id"], name: "index_inspections_on_instrument_id"
    t.index ["maintenance_task_id"], name: "index_inspections_on_maintenance_task_id"
    t.index ["status"], name: "index_inspections_on_status"
    t.index ["user_id"], name: "index_inspections_on_user_id"
  end

  create_table "instruments", force: :cascade do |t|
    t.string "tag_number", null: false
    t.string "instrument_type"
    t.bigint "equipment_id", null: false
    t.bigint "service_id"
    t.bigint "line_class_id"
    t.string "location"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "range_lower", precision: 14, scale: 4
    t.decimal "range_upper", precision: 14, scale: 4
    t.string "range_unit"
    t.string "output_characteristic", default: "linear", null: false
    t.string "dcs_characteristic", default: "linear", null: false
    t.decimal "dcs_range_lower", precision: 14, scale: 4
    t.decimal "dcs_range_upper", precision: 14, scale: 4
    t.string "dcs_range_unit"
    t.decimal "tolerance_percent", precision: 6, scale: 3
    t.string "tolerance_basis"
    t.boolean "telemetry", default: false, null: false
    t.boolean "custody_transfer", default: false, null: false
    t.index ["equipment_id", "tag_number"], name: "index_instruments_on_equipment_id_and_tag_number", unique: true
    t.index ["equipment_id"], name: "index_instruments_on_equipment_id"
    t.index ["line_class_id"], name: "index_instruments_on_line_class_id"
    t.index ["service_id"], name: "index_instruments_on_service_id"
    t.index ["tag_number"], name: "index_instruments_on_tag_number"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "exp", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti", unique: true
  end

  create_table "line_classes", force: :cascade do |t|
    t.string "code", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_line_classes_on_code", unique: true
  end

  create_table "maintenance_assignments", force: :cascade do |t|
    t.bigint "scheduled_maintenance_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_maintenance_id"], name: "index_maintenance_assignments_on_scheduled_maintenance_id"
    t.index ["user_id"], name: "index_maintenance_assignments_on_user_id"
  end

  create_table "maintenance_series", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id"], name: "index_maintenance_series_on_site_id"
  end

  create_table "maintenance_series_equipments", force: :cascade do |t|
    t.bigint "maintenance_series_id", null: false
    t.bigint "equipment_id", null: false
    t.integer "interval_months", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_maintenance_series_equipments_on_equipment_id"
    t.index ["maintenance_series_id", "equipment_id"], name: "index_ms_equipments_on_series_and_equipment", unique: true
    t.index ["maintenance_series_id"], name: "index_maintenance_series_equipments_on_maintenance_series_id"
    t.check_constraint "interval_months > 0", name: "maintenance_series_equipments_interval_positive"
  end

  create_table "maintenance_tasks", force: :cascade do |t|
    t.bigint "scheduled_maintenance_id", null: false
    t.bigint "department_id"
    t.bigint "equipment_id", null: false
    t.bigint "instrument_id"
    t.bigint "checklist_template_id"
    t.bigint "assigned_to_id"
    t.string "kind", default: "inspection", null: false
    t.string "title", null: false
    t.string "status", default: "not_started", null: false
    t.date "completed_on"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "trouble_id"
    t.index ["assigned_to_id"], name: "index_maintenance_tasks_on_assigned_to_id"
    t.index ["checklist_template_id"], name: "index_maintenance_tasks_on_checklist_template_id"
    t.index ["department_id"], name: "index_maintenance_tasks_on_department_id"
    t.index ["equipment_id"], name: "index_maintenance_tasks_on_equipment_id"
    t.index ["instrument_id"], name: "index_maintenance_tasks_on_instrument_id"
    t.index ["scheduled_maintenance_id", "status"], name: "index_maintenance_tasks_on_scheduled_maintenance_id_and_status"
    t.index ["scheduled_maintenance_id"], name: "index_maintenance_tasks_on_scheduled_maintenance_id"
    t.index ["trouble_id"], name: "index_maintenance_tasks_on_trouble_id"
  end

  create_table "manufacturers", force: :cascade do |t|
    t.string "name", null: false
    t.text "former_names"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "material_alternatives", force: :cascade do |t|
    t.bigint "material_id", null: false
    t.bigint "alternative_material_id", null: false
    t.string "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alternative_material_id"], name: "index_material_alternatives_on_alternative_material_id"
    t.index ["material_id", "alternative_material_id"], name: "index_material_alternatives_uniqueness", unique: true
    t.index ["material_id"], name: "index_material_alternatives_on_material_id"
  end

  create_table "materials", force: :cascade do |t|
    t.bigint "manufacturer_id"
    t.string "part_number", null: false
    t.string "normalized_part_number"
    t.string "name", null: false
    t.text "description"
    t.text "former_part_numbers"
    t.string "availability", default: "catalog"
    t.string "category"
    t.string "rating"
    t.integer "lead_time_days"
    t.boolean "is_hazardous", default: false
    t.string "hazard_note"
    t.string "reorder_method", default: "reorder_point"
    t.integer "reorder_point"
    t.integer "reorder_quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["manufacturer_id"], name: "index_materials_on_manufacturer_id"
    t.index ["normalized_part_number"], name: "index_materials_on_normalized_part_number"
    t.index ["part_number"], name: "index_materials_on_part_number"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "material_id", null: false
    t.bigint "user_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price"
    t.string "supplier_name"
    t.string "supplier_link"
    t.string "status", default: "draft", null: false
    t.date "ordered_on", null: false
    t.date "received_on"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "warehouse_id"
    t.index ["material_id"], name: "index_orders_on_material_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
    t.index ["warehouse_id"], name: "index_orders_on_warehouse_id"
  end

  create_table "reference_standard_calibrations", force: :cascade do |t|
    t.bigint "reference_standard_id", null: false
    t.date "performed_on", null: false
    t.string "performed_by", null: false
    t.string "certificate_number"
    t.string "result", default: "pass", null: false
    t.boolean "traceable", default: false, null: false
    t.date "valid_until", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reference_standard_id", "performed_on"], name: "index_rs_calibrations_on_standard_and_performed_on"
    t.index ["reference_standard_id"], name: "index_reference_standard_calibrations_on_reference_standard_id"
  end

  create_table "reference_standards", force: :cascade do |t|
    t.bigint "site_id", null: false
    t.string "management_number", null: false
    t.string "name", null: false
    t.string "category", default: "other", null: false
    t.string "model_number"
    t.string "serial_number"
    t.string "measuring_range"
    t.string "accuracy"
    t.string "location"
    t.string "status", default: "usable", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["management_number"], name: "index_reference_standards_on_management_number", unique: true
    t.index ["site_id"], name: "index_reference_standards_on_site_id"
  end

  create_table "regulation_inspections", force: :cascade do |t|
    t.bigint "regulation_id", null: false
    t.string "name", null: false
    t.integer "interval_days", null: false
    t.string "basis", default: "statutory", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["regulation_id"], name: "index_regulation_inspections_on_regulation_id"
  end

  create_table "regulations", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "law_name", null: false
    t.string "target", default: "equipment", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_regulations_on_code", unique: true
  end

  create_table "repairs", force: :cascade do |t|
    t.bigint "stock_id", null: false
    t.bigint "trouble_id"
    t.bigint "requested_by_id", null: false
    t.string "status", default: "pending", null: false
    t.string "repair_vendor"
    t.date "shipped_on"
    t.date "completed_on"
    t.date "received_on"
    t.decimal "repair_cost"
    t.decimal "shipping_cost"
    t.string "disposition"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_by_id"], name: "index_repairs_on_requested_by_id"
    t.index ["status"], name: "index_repairs_on_status"
    t.index ["stock_id"], name: "index_repairs_on_stock_id"
    t.index ["trouble_id"], name: "index_repairs_on_trouble_id"
  end

  create_table "scheduled_maintenance_equipments", force: :cascade do |t|
    t.bigint "scheduled_maintenance_id", null: false
    t.bigint "equipment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_scheduled_maintenance_equipments_on_equipment_id"
    t.index ["scheduled_maintenance_id", "equipment_id"], name: "index_sm_equipments_on_maintenance_and_equipment", unique: true
    t.index ["scheduled_maintenance_id"], name: "idx_on_scheduled_maintenance_id_442d9fc3a6"
  end

  create_table "scheduled_maintenances", force: :cascade do |t|
    t.bigint "equipment_id"
    t.string "title", null: false
    t.text "description"
    t.date "scheduled_date"
    t.date "completed_date"
    t.string "status", default: "planned", null: false
    t.text "used_materials"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "site_id", null: false
    t.date "planned_start_on", null: false
    t.date "planned_end_on"
    t.date "actual_start_on"
    t.date "actual_end_on"
    t.date "accepted_on"
    t.bigint "accepted_by_id"
    t.string "acceptance_result"
    t.text "acceptance_notes"
    t.bigint "maintenance_series_id"
    t.index ["accepted_by_id"], name: "index_scheduled_maintenances_on_accepted_by_id"
    t.index ["equipment_id"], name: "index_scheduled_maintenances_on_equipment_id"
    t.index ["maintenance_series_id"], name: "index_scheduled_maintenances_on_maintenance_series_id"
    t.index ["planned_start_on"], name: "index_scheduled_maintenances_on_planned_start_on"
    t.index ["scheduled_date"], name: "index_scheduled_maintenances_on_scheduled_date"
    t.index ["site_id"], name: "index_scheduled_maintenances_on_site_id"
    t.index ["status"], name: "index_scheduled_maintenances_on_status"
  end

  create_table "services", force: :cascade do |t|
    t.string "name", null: false
    t.string "temperature"
    t.string "pressure"
    t.string "hazard_level"
    t.text "hazard_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sites", force: :cascade do |t|
    t.string "name", null: false
    t.string "prefecture"
    t.string "address"
    t.boolean "is_active", default: true, null: false
    t.date "closed_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_sites_on_is_active"
  end

  create_table "stock_transactions", force: :cascade do |t|
    t.bigint "stock_id", null: false
    t.bigint "user_id", null: false
    t.string "transaction_type", null: false
    t.integer "quantity", null: false
    t.bigint "from_warehouse_id"
    t.bigint "to_warehouse_id"
    t.string "reason"
    t.datetime "transacted_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stock_id"], name: "index_stock_transactions_on_stock_id"
    t.index ["transaction_type"], name: "index_stock_transactions_on_transaction_type"
    t.index ["user_id"], name: "index_stock_transactions_on_user_id"
    t.check_constraint "quantity > 0", name: "stock_transactions_quantity_positive"
  end

  create_table "stocks", force: :cascade do |t|
    t.bigint "material_id", null: false
    t.bigint "warehouse_id", null: false
    t.integer "quantity", default: 0, null: false
    t.date "purchased_on"
    t.string "status", default: "available", null: false
    t.string "serial_number"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["material_id"], name: "index_stocks_on_material_id"
    t.index ["status"], name: "index_stocks_on_status"
    t.index ["warehouse_id"], name: "index_stocks_on_warehouse_id"
    t.check_constraint "quantity >= 0", name: "stocks_quantity_non_negative"
  end

  create_table "trouble_responses", force: :cascade do |t|
    t.bigint "trouble_id", null: false
    t.bigint "user_id", null: false
    t.string "response_type", null: false
    t.text "description", null: false
    t.text "used_materials"
    t.datetime "responded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trouble_id"], name: "index_trouble_responses_on_trouble_id"
    t.index ["user_id"], name: "index_trouble_responses_on_user_id"
  end

  create_table "troubles", force: :cascade do |t|
    t.bigint "inspection_item_id"
    t.bigint "equipment_id", null: false
    t.bigint "instrument_id"
    t.bigint "reported_by_id", null: false
    t.bigint "assigned_to_id"
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "open", null: false
    t.string "priority", default: "medium", null: false
    t.datetime "reported_at", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_troubles_on_assigned_to_id"
    t.index ["equipment_id"], name: "index_troubles_on_equipment_id"
    t.index ["inspection_item_id"], name: "index_troubles_on_inspection_item_id"
    t.index ["instrument_id"], name: "index_troubles_on_instrument_id"
    t.index ["priority"], name: "index_troubles_on_priority"
    t.index ["reported_by_id"], name: "index_troubles_on_reported_by_id"
    t.index ["status"], name: "index_troubles_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name", null: false
    t.bigint "department_id"
    t.integer "join_year"
    t.string "home_prefecture"
    t.string "previous_company"
    t.boolean "is_active", default: true, null: false
    t.date "deactivated_on"
    t.string "jti"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "position"
    t.string "employment_type", default: "employee", null: false
    t.string "system_role", default: "member", null: false
    t.bigint "company_id"
    t.bigint "site_id"
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["department_id"], name: "index_users_on_department_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["employment_type"], name: "index_users_on_employment_type"
    t.index ["is_active"], name: "index_users_on_is_active"
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["position"], name: "index_users_on_position"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["site_id"], name: "index_users_on_site_id"
    t.index ["system_role"], name: "index_users_on_system_role"
  end

  create_table "warehouses", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "site_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id"], name: "index_warehouses_on_site_id"
  end

  add_foreign_key "ai_suggestions", "equipments"
  add_foreign_key "ai_suggestions", "instruments"
  add_foreign_key "ai_suggestions", "users"
  add_foreign_key "audit_logs", "sites"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "checklist_template_items", "checklist_templates"
  add_foreign_key "checklist_templates", "departments"
  add_foreign_key "department_histories", "departments"
  add_foreign_key "department_histories", "users"
  add_foreign_key "departments", "departments", column: "parent_id"
  add_foreign_key "departments", "sites"
  add_foreign_key "equipment_assignments", "equipments"
  add_foreign_key "equipment_assignments", "users"
  add_foreign_key "equipment_regulations", "equipments"
  add_foreign_key "equipment_regulations", "regulations"
  add_foreign_key "equipments", "sites"
  add_foreign_key "inspection_items", "checklist_template_items"
  add_foreign_key "inspection_items", "inspections"
  add_foreign_key "inspection_items", "instruments"
  add_foreign_key "inspection_plans", "checklist_templates"
  add_foreign_key "inspection_plans", "equipments"
  add_foreign_key "inspection_plans", "instruments"
  add_foreign_key "inspection_plans", "reference_standards"
  add_foreign_key "inspection_reference_standards", "inspections"
  add_foreign_key "inspection_reference_standards", "reference_standards"
  add_foreign_key "inspections", "checklist_templates"
  add_foreign_key "inspections", "departments"
  add_foreign_key "inspections", "equipments"
  add_foreign_key "inspections", "inspection_plans"
  add_foreign_key "inspections", "instruments"
  add_foreign_key "inspections", "maintenance_tasks"
  add_foreign_key "inspections", "users"
  add_foreign_key "instruments", "equipments"
  add_foreign_key "instruments", "line_classes"
  add_foreign_key "instruments", "services"
  add_foreign_key "maintenance_assignments", "scheduled_maintenances"
  add_foreign_key "maintenance_assignments", "users"
  add_foreign_key "maintenance_series", "sites"
  add_foreign_key "maintenance_series_equipments", "equipments"
  add_foreign_key "maintenance_series_equipments", "maintenance_series"
  add_foreign_key "maintenance_tasks", "checklist_templates"
  add_foreign_key "maintenance_tasks", "departments"
  add_foreign_key "maintenance_tasks", "equipments"
  add_foreign_key "maintenance_tasks", "instruments"
  add_foreign_key "maintenance_tasks", "scheduled_maintenances"
  add_foreign_key "maintenance_tasks", "troubles"
  add_foreign_key "maintenance_tasks", "users", column: "assigned_to_id"
  add_foreign_key "material_alternatives", "materials"
  add_foreign_key "material_alternatives", "materials", column: "alternative_material_id"
  add_foreign_key "materials", "manufacturers"
  add_foreign_key "orders", "materials"
  add_foreign_key "orders", "users"
  add_foreign_key "orders", "warehouses"
  add_foreign_key "reference_standard_calibrations", "reference_standards"
  add_foreign_key "reference_standards", "sites"
  add_foreign_key "regulation_inspections", "regulations"
  add_foreign_key "repairs", "stocks"
  add_foreign_key "repairs", "troubles"
  add_foreign_key "repairs", "users", column: "requested_by_id"
  add_foreign_key "scheduled_maintenance_equipments", "equipments"
  add_foreign_key "scheduled_maintenance_equipments", "scheduled_maintenances"
  add_foreign_key "scheduled_maintenances", "equipments"
  add_foreign_key "scheduled_maintenances", "maintenance_series"
  add_foreign_key "scheduled_maintenances", "sites"
  add_foreign_key "scheduled_maintenances", "users", column: "accepted_by_id"
  add_foreign_key "stock_transactions", "stocks"
  add_foreign_key "stock_transactions", "users"
  add_foreign_key "stock_transactions", "warehouses", column: "from_warehouse_id"
  add_foreign_key "stock_transactions", "warehouses", column: "to_warehouse_id"
  add_foreign_key "stocks", "materials"
  add_foreign_key "stocks", "warehouses"
  add_foreign_key "trouble_responses", "troubles"
  add_foreign_key "trouble_responses", "users"
  add_foreign_key "troubles", "equipments"
  add_foreign_key "troubles", "inspection_items"
  add_foreign_key "troubles", "instruments"
  add_foreign_key "troubles", "users", column: "assigned_to_id"
  add_foreign_key "troubles", "users", column: "reported_by_id"
  add_foreign_key "users", "companies"
  add_foreign_key "users", "departments"
  add_foreign_key "users", "sites"
  add_foreign_key "warehouses", "sites"
end
