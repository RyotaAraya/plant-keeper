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

export interface RegulationInspection {
  id: number
  name: string
  interval_days: number
  basis: 'statutory' | 'voluntary'
  note: string | null
}

// 法規区分（高圧ガス・ボイラーなど）。target は法規が掛かる単位（設備 / 計器）
export interface Regulation {
  id: number
  code: string
  name: string
  law_name: string
  target: 'equipment' | 'instrument'
  description?: string | null
  regulation_inspections?: RegulationInspection[]
}

export interface Equipment {
  id: number
  site_id: number
  name: string
  description: string
  regulations?: Regulation[]
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
  // 校正の条件（数値はAPIから文字列で返る）。5点校正できるのは、範囲と許容差が設定済みの計器
  range_lower?: string | number | null
  range_upper?: string | number | null
  range_unit?: string | null
  output_characteristic?: 'linear' | 'square_root'
  dcs_characteristic?: 'linear' | 'square_root'
  dcs_range_lower?: string | number | null
  dcs_range_upper?: string | number | null
  dcs_range_unit?: string | null
  tolerance_percent?: string | number | null
  tolerance_basis?: 'legal' | 'manufacturer' | 'internal' | null
  telemetry?: boolean
  custody_transfer?: boolean
  calibration_kind?: 'transmitter' | 'positioner' | null
  calibratable?: boolean
  created_at: string
  updated_at: string
}

// 5点校正。校正の条件（snapshot）は点検時に計器の設定から凍結して保存したもの
export interface CalibrationSnapshot {
  kind: 'transmitter' | 'positioner'
  range_lower: number
  range_upper: number
  range_unit: string | null
  output_characteristic: 'linear' | 'square_root'
  dcs_characteristic: 'linear' | 'square_root'
  dcs_range_lower: number | null
  dcs_range_upper: number | null
  dcs_range_unit: string | null
  tolerance_percent: number
  tolerance_basis: 'legal' | 'manufacturer' | 'internal' | null
}

// 入力欄の値（入力中は文字列のことがある）
export interface CalibrationReading {
  output: number | string | null
  dcs: number | string | null
}

export interface CalibrationPointInput {
  percent: number
  up: CalibrationReading
  down: CalibrationReading
}

export interface CalibrationInput {
  adjusted: boolean
  stages: {
    as_found: { points: CalibrationPointInput[] }
    as_left: { points: CalibrationPointInput[] }
  }
}

export type CalibrationResult = 'pass' | 'fail' | 'incomplete' | 'empty'

export interface CalibrationReadingEvaluation {
  output: number | null
  dcs: number | null
  output_error: number | null
  dcs_error: number | null
  ok: boolean | null
}

export interface CalibrationPointEvaluation {
  percent: number
  expected: { percent: number; input: number; output: number; dcs: number }
  up: CalibrationReadingEvaluation
  down: CalibrationReadingEvaluation
  hysteresis: number | null
  hysteresis_ok: boolean | null
}

export interface CalibrationEvaluation {
  stages: Record<'as_found' | 'as_left', { points: CalibrationPointEvaluation[]; result: CalibrationResult }>
  final_stage: 'as_found' | 'as_left'
  result: CalibrationResult
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

export interface Company {
  id: number
  name: string
  company_type: 'owner' | 'contractor'
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface User {
  id: number
  email: string
  name: string
  employment_type: string
  system_role: string
  company_id: number | null
  company?: { id: number; name: string; company_type: string }
  site?: { id: number; name: string } | null
  department_id: number | null
  department?: {
    id: number
    name: string
    level: string
    site_id: number
    full_path: string
    ancestors: { id: number; name: string; level: string }[]
  }
  site_id: number | null
  position: string | null
  join_year: number | null
  home_prefecture: string | null
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
  inspection_plan_id: number | null
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
  // 点検で見た設備（代表の設備 equipment_id を含む。複数の設備をまとめた点検は2つ以上）
  equipments?: { id: number; name: string }[]
}

export interface InspectionPlan {
  id: number
  name: string
  // 点検の対象は、設備か基準器（年次の校正）のどちらか一方
  equipment_id: number | null
  reference_standard_id?: number | null
  instrument_id: number | null
  checklist_template_id: number | null
  inspection_type: string
  interval_days: number
  last_inspected_on: string | null
  next_due_on: string
  is_active: boolean
  overdue: boolean
  days_until_due: number
  equipment?: { id: number; name: string; site_id: number } | null
  // 対象の設備（代表の設備 equipment_id を含む。複数の設備をまとめた計画は2つ以上）
  equipments?: { id: number; name: string; site_id: number }[]
  reference_standard?: { id: number; name: string; management_number: string; site_id: number } | null
  instrument?: { id: number; tag_number: string } | null
  checklist_template?: { id: number; name: string } | null
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
  // 複数の設備をまとめた点検で、項目の対象設備（空は代表の設備）
  equipment_id: number | null
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
  site_id: number
  maintenance_series_id: number | null
  title: string
  description: string | null
  planned_start_on: string
  planned_end_on: string | null
  actual_start_on: string | null
  actual_end_on: string | null
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

// 基準器（校正に使う圧力校正器・マルチテスタ・温度校正器など）。校正はメーカーが行い、その履歴から点検日に使えるかを判定する
export interface ReferenceStandardCalibration {
  id: number
  performed_on: string
  performed_by: string
  certificate_number: string | null
  result: 'pass' | 'fail'
  traceable: boolean
  valid_until: string
  notes?: string | null
}

// never=校正の記録なし / failed=最新の校正が不合格 / expired=有効期限切れ / expiring=期限間近 / valid=有効
export type CalibrationState = 'never' | 'failed' | 'expired' | 'expiring' | 'valid'

export interface ReferenceStandard {
  id: number
  site_id: number
  management_number: string
  name: string
  category: 'pressure' | 'electrical' | 'temperature' | 'other'
  model_number: string | null
  serial_number: string | null
  measuring_range: string | null
  accuracy: string | null
  location: string | null
  status: 'usable' | 'in_calibration' | 'retired'
  notes: string | null
  site?: { id: number; name: string }
  calibration_state: CalibrationState
  next_due_on: string | null
  // 新しい順
  calibrations: ReferenceStandardCalibration[]
}

// 点検で使った基準器と、使用前の1点チェック（pre_check_passed: null=未確認）
export interface InspectionReferenceStandardUse {
  reference_standard_id: number
  pre_check_passed: boolean | null
  pre_check_note: string
}

// AI支援（不具合報告の下書き・類似トラブル・対応記録の下書き）
export interface AiStatus {
  enabled: boolean
  // どのAIか。fake=APIを呼ばないダミー / claude=本物 / null=無効
  provider: 'fake' | 'claude' | null
  daily_limit: number
  remaining_today: number
  max_memo_length: number
}

export interface AiDefectDraft {
  suggestion_id: number
  title: string
  description: string
  // AIが提案しない（使えない値だった）ときは null
  priority: 'low' | 'medium' | 'high' | 'critical' | null
  priority_reason: string
  possible_causes: string[]
  check_points: string[]
  remaining_today: number
}

// 類似トラブル。タイトル・状態などはDBの値で、似ている点と対応の要約がAIの文章
export interface AiSimilarCase {
  trouble_id: number
  title: string
  status: string
  priority: string
  equipment_name: string
  instrument_tag: string | null
  reported_at: string
  similarity: string
  how_handled: string
}

export interface AiSimilarTroubles {
  cases: AiSimilarCase[]
  // 比べた過去のトラブルの件数（0のときはAIを呼んでいない）
  candidates_count: number
  remaining_today: number
}

export interface AiResponseDraft {
  suggestion_id: number
  // AIが提案しない（メモから決められない・使えない値だった）ときは null
  response_type: 'investigation' | 'repair' | 'replacement' | 'observation' | null
  description: string
  used_materials: string
  check_points: string[]
  remaining_today: number
}
