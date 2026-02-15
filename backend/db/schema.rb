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

ActiveRecord::Schema[8.0].define(version: 2026_02_15_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.jsonb "changes_json", default: {}
    t.string "ip_address"
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["performed_at"], name: "index_audit_logs_on_performed_at"
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
    t.index ["checklist_template_item_id"], name: "index_inspection_items_on_checklist_template_item_id"
    t.index ["inspection_id"], name: "index_inspection_items_on_inspection_id"
    t.index ["instrument_id"], name: "index_inspection_items_on_instrument_id"
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
    t.index ["checklist_template_id"], name: "index_inspections_on_checklist_template_id"
    t.index ["department_id"], name: "index_inspections_on_department_id"
    t.index ["equipment_id"], name: "index_inspections_on_equipment_id"
    t.index ["inspection_type"], name: "index_inspections_on_inspection_type"
    t.index ["instrument_id"], name: "index_inspections_on_instrument_id"
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
    t.index ["equipment_id"], name: "index_instruments_on_equipment_id"
    t.index ["line_class_id"], name: "index_instruments_on_line_class_id"
    t.index ["service_id"], name: "index_instruments_on_service_id"
    t.index ["tag_number"], name: "index_instruments_on_tag_number", unique: true
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
    t.index ["material_id"], name: "index_orders_on_material_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
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

  create_table "scheduled_maintenances", force: :cascade do |t|
    t.bigint "equipment_id", null: false
    t.string "title", null: false
    t.text "description"
    t.date "scheduled_date", null: false
    t.date "completed_date"
    t.string "status", default: "planned", null: false
    t.text "used_materials"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["equipment_id"], name: "index_scheduled_maintenances_on_equipment_id"
    t.index ["scheduled_date"], name: "index_scheduled_maintenances_on_scheduled_date"
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
    t.string "jti", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "position"
    t.string "employment_type", default: "employee", null: false
    t.string "system_role", default: "member", null: false
    t.bigint "company_id"
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["department_id"], name: "index_users_on_department_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["employment_type"], name: "index_users_on_employment_type"
    t.index ["is_active"], name: "index_users_on_is_active"
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["position"], name: "index_users_on_position"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["system_role"], name: "index_users_on_system_role"
  end

  create_table "warehouses", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "site_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id"], name: "index_warehouses_on_site_id"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "checklist_template_items", "checklist_templates"
  add_foreign_key "checklist_templates", "departments"
  add_foreign_key "department_histories", "departments"
  add_foreign_key "department_histories", "users"
  add_foreign_key "departments", "departments", column: "parent_id"
  add_foreign_key "departments", "sites"
  add_foreign_key "equipment_assignments", "equipments"
  add_foreign_key "equipment_assignments", "users"
  add_foreign_key "equipments", "sites"
  add_foreign_key "inspection_items", "checklist_template_items"
  add_foreign_key "inspection_items", "inspections"
  add_foreign_key "inspection_items", "instruments"
  add_foreign_key "inspections", "checklist_templates"
  add_foreign_key "inspections", "departments"
  add_foreign_key "inspections", "equipments"
  add_foreign_key "inspections", "instruments"
  add_foreign_key "inspections", "users"
  add_foreign_key "instruments", "equipments"
  add_foreign_key "instruments", "line_classes"
  add_foreign_key "instruments", "services"
  add_foreign_key "maintenance_assignments", "scheduled_maintenances"
  add_foreign_key "maintenance_assignments", "users"
  add_foreign_key "material_alternatives", "materials"
  add_foreign_key "material_alternatives", "materials", column: "alternative_material_id"
  add_foreign_key "materials", "manufacturers"
  add_foreign_key "orders", "materials"
  add_foreign_key "orders", "users"
  add_foreign_key "repairs", "stocks"
  add_foreign_key "repairs", "troubles"
  add_foreign_key "repairs", "users", column: "requested_by_id"
  add_foreign_key "scheduled_maintenances", "equipments"
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
  add_foreign_key "warehouses", "sites"
end
