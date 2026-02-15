// 拠点・設備系

export interface Site {
  id: number
  name: string
  prefecture: string
  address: string
  is_active: boolean
  closed_on: string | null
  created_at: string
  updated_at: string
}

export interface Equipment {
  id: number
  site_id: number
  name: string
  description: string
  created_at: string
  updated_at: string
}

export interface Instrument {
  id: number
  equipment_id: number
  tag_number: string
  instrument_type: string
  service_id: number
  line_class_id: number | null
  location: string
  notes: string | null
  created_at: string
  updated_at: string
}

export interface Service {
  id: number
  name: string
  temperature: string
  pressure: string
  hazard_level: string
  hazard_description: string | null
  created_at: string
  updated_at: string
}

export interface LineClass {
  id: number
  code: string
  description: string | null
  created_at: string
  updated_at: string
}

// ユーザ・部署系

export interface Department {
  id: number
  name: string
  department_type: string
  level: string
  site_id: number
  parent_id: number | null
  parent?: { id: number; name: string; level: string }
  children?: Department[]
  created_at: string
  updated_at: string
}

export interface User {
  id: number
  email: string
  password_digest: string
  name: string
  role: string
  position: string | null
  department_id: number
  join_year: number
  home_prefecture: string
  previous_company: string | null
  is_active: boolean
  deactivated_on: string | null
  created_at: string
  updated_at: string
}

export interface EquipmentAssignment {
  id: number
  user_id: number
  equipment_id: number
  role: string
  started_on: string
  ended_on: string | null
  created_at: string
  updated_at: string
}

export interface DepartmentHistory {
  id: number
  user_id: number
  department_id: number
  started_on: string
  ended_on: string | null
  role_note: string | null
  created_at: string
  updated_at: string
}

// 点検・作業記録系

export interface ChecklistTemplate {
  id: number
  name: string
  department_id: number
  inspection_type: string
  created_at: string
  updated_at: string
}

export interface ChecklistTemplateItem {
  id: number
  checklist_template_id: number
  position: number
  content: string
  item_type: string
  created_at: string
  updated_at: string
}

export interface Inspection {
  id: number
  checklist_template_id: number | null
  user_id: number
  equipment_id: number
  instrument_id: number | null
  department_id: number
  inspection_type: string
  status: string
  inspected_at: string
  notes: string | null
  created_at: string
  updated_at: string
}

export interface InspectionItem {
  id: number
  inspection_id: number
  checklist_template_item_id: number | null
  position: number
  content: string
  item_type: string
  checked: boolean
  measured_value: string | null
  text_value: string | null
  has_defect: boolean
  instrument_id: number | null
  created_at: string
  updated_at: string
}

// トラブル管理系

export interface Trouble {
  id: number
  inspection_item_id: number | null
  equipment_id: number
  instrument_id: number | null
  reported_by_id: number
  assigned_to_id: number | null
  title: string
  description: string | null
  status: string
  priority: string
  reported_at: string
  resolved_at: string | null
  created_at: string
  updated_at: string
}

export interface TroubleResponse {
  id: number
  trouble_id: number
  user_id: number
  response_type: string
  description: string | null
  used_materials: string | null
  responded_at: string
  created_at: string
  updated_at: string
}

// 定期整備系

export interface ScheduledMaintenance {
  id: number
  equipment_id: number
  title: string
  description: string | null
  scheduled_date: string
  completed_date: string | null
  status: string
  used_materials: string | null
  created_at: string
  updated_at: string
}

export interface MaintenanceAssignment {
  id: number
  scheduled_maintenance_id: number
  user_id: number
  role: string
  created_at: string
  updated_at: string
}

// 資材管理系

export interface Manufacturer {
  id: number
  name: string
  former_names: string | null
  notes: string | null
  created_at: string
  updated_at: string
}

export interface Material {
  id: number
  manufacturer_id: number
  part_number: string
  normalized_part_number: string
  name: string
  description: string | null
  former_part_numbers: string | null
  availability: string
  category: string
  rating: string | null
  lead_time_days: number | null
  is_hazardous: boolean
  hazard_note: string | null
  reorder_method: string
  reorder_point: number | null
  reorder_quantity: number | null
  created_at: string
  updated_at: string
}

export interface MaterialAlternative {
  id: number
  material_id: number
  alternative_material_id: number
  notes: string | null
  created_at: string
  updated_at: string
}

// 在庫・入出庫系

export interface Warehouse {
  id: number
  site_id: number
  name: string
  created_at: string
  updated_at: string
}

export interface Stock {
  id: number
  material_id: number
  warehouse_id: number
  quantity: number
  purchased_on: string
  status: string
  serial_number: string | null
  notes: string | null
  created_at: string
  updated_at: string
}

export interface StockTransaction {
  id: number
  stock_id: number
  user_id: number
  transaction_type: string
  quantity: number
  from_warehouse_id: number | null
  to_warehouse_id: number | null
  reason: string | null
  transacted_at: string
  created_at: string
  updated_at: string
}

// 修理管理系

export interface Repair {
  id: number
  stock_id: number
  trouble_id: number | null
  requested_by_id: number
  status: string
  repair_vendor: string
  shipped_on: string | null
  completed_on: string | null
  received_on: string | null
  repair_cost: number | null
  shipping_cost: number | null
  disposition: string
  notes: string | null
  created_at: string
  updated_at: string
}

// 発注系

export interface Order {
  id: number
  material_id: number
  user_id: number
  quantity: number
  unit_price: number
  supplier_name: string
  supplier_link: string | null
  status: string
  ordered_on: string
  received_on: string | null
  notes: string | null
  created_at: string
  updated_at: string
}

// 監査ログ

export interface AuditLog {
  id: number
  user_id: number | null
  action: string
  auditable_type: string
  auditable_id: number
  changes_json: Record<string, unknown>
  ip_address: string | null
  performed_at: string
  created_at: string
}
