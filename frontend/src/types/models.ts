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
  seal_fluid?: string | null
  // 計器種別ごとの一次点検の定型項目（参考。InstrumentTroubleshootingCatalog）。DefectAiAssistで表示する
  troubleshooting_checks?: string[]
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
  // 機器の自己診断（NAMUR NE 107）のいまの状態。未受信は null
  diagnostic_status?: import('@/constants/diagnostics').DiagnosticStatus | null
  diagnostic_since?: string | null
  diagnostic_received_at?: string | null
  // 詳細だけ: 状態が変わった記録（新しい順に20件）
  diagnostics?: InstrumentDiagnostic[]
  // 詳細だけ: 診断（保守要求・仕様外）で次回期限を前倒しする候補の点検計画と、診断から作った未解決のトラブル
  diagnostic_advance_plans?: Pick<InspectionPlan, 'id' | 'name' | 'next_due_on' | 'interval_days' | 'last_inspected_on'>[]
  diagnostic_troubles?: Pick<Trouble, 'id' | 'title' | 'status' | 'priority' | 'reported_at'>[]
  created_at: string
  updated_at: string
}

export interface InstrumentDiagnostic {
  id: number
  status: import('@/constants/diagnostics').DiagnosticStatus
  code: string | null
  message: string | null
  occurred_at: string
  created_at: string
  // 送ってきた連携（トークン）の名前
  source: string | null
}

// 連携用のトークン（機器管理システムなど）。平文の token は発行したときの応答にだけ入る
export interface IntegrationToken {
  id: number
  name: string
  token_hint: string
  last_used_at: string | null
  revoked_at: string | null
  created_at: string
  site: { id: number; name: string }
  created_by: { id: number; name: string }
  revoked_by: { id: number; name: string } | null
  token?: string
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
  // 項目の型と基準（utils/checklistCriteria.ts）。decimal は文字列で返る
  section: string | null
  criterion: string | null
  unit: string | null
  lower_limit: string | null
  upper_limit: string | null
  options: string[] | null
  required: boolean
  created_at: string
  updated_at: string
}

// テンプレートの項目ごとの実施回数・不具合の件数（GET /checklist_templates/:id/item_stats。項目の見直しの材料）
export type ChecklistItemStatsPeriod = '1y' | '3y' | 'all'

export interface ChecklistItemStatsRow {
  id: number
  position: number
  section: string | null
  content: string
  item_type: string
  performed_count: number
  defect_count: number
  na_count: number
  last_defect_at: string | null
}

export interface ChecklistItemStats {
  period: ChecklistItemStatsPeriod
  from: string | null
  inspections_count: number
  items: ChecklistItemStatsRow[]
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
  // 校正結果のファイルから取り込んだ点検の出所（手入力は null）
  import_source?: CalibrationImportSource | null
}

export interface CalibrationImportSource {
  kind: 'calibration_file'
  file_name: string
  format_version: number
  // ファイルの何件目の記録か
  record_index: number
  calibrator: { model: string | null; serial_number: string | null }
  performed_by: string | null
  imported_at: string
}

// 5点校正のある点検計画の、周期の見直しの候補（ルールで判定。決めるのは人）
export interface IntervalReview {
  kind: 'extend' | 'shorten'
  reasons: string[]
  // 延長するときの注意（インターロックに関わる計器など）
  cautions: string[]
  suggested_interval_days: number
  tolerance_percent: number | null
  // 根拠にした直近の校正（古い順）
  evidence: { inspection_id: number; inspected_at: string; adjusted: boolean; as_found: { result: string; max_error: number | null } }[]
}

// 点検のまとまり（点検計画の親）。担当部署・法規区分・既定の周期を持ち、周期と次回期限は子の計画が持つ
export interface InspectionPlanGroup {
  id: number
  site_id: number
  name: string
  department_id: number | null
  regulation_id: number | null
  default_interval_days: number | null
  is_active: boolean
  site?: { id: number; name: string }
  department?: { id: number; name: string } | null
  regulation?: { id: number; code: string; name: string } | null
  // 一覧（GET /inspection_plan_groups）だけが付ける: 有効な計画の数・期限超過の数・いちばん近い次回期限
  plans_count?: number
  overdue_count?: number
  next_due_on?: string | null
}

export interface InspectionPlan {
  id: number
  name: string
  inspection_plan_group_id: number
  inspection_plan_group?: Pick<InspectionPlanGroup, 'id' | 'name' | 'department' | 'regulation'>
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
  interval_review?: IntervalReview | null
  // 機器の診断（保守要求・仕様外）で、次回期限を前倒しする候補のときの、計器のいまの診断
  diagnostic_advance?: DiagnosticAdvance | null
}

export interface DiagnosticAdvance {
  diagnostic_status: 'maintenance_required' | 'out_of_specification'
  diagnostic_since: string
  code?: string | null
  message?: string | null
}

export interface InspectionItem {
  id: number
  inspection_id: number
  checklist_template_item_id: number | null
  position: number
  content: string
  item_type: string
  // 判定: good=良好 / defect=不具合あり / na=該当なし。未判定は null。has_defect は判定から決まる
  result: 'good' | 'defect' | 'na' | null
  // 点検した時点の基準（テンプレートの項目からの写し）
  section: string | null
  criterion: string | null
  unit: string | null
  lower_limit: string | null
  upper_limit: string | null
  options: string[] | null
  required: boolean
  // 測定値と許容範囲の関係（測定値の項目だけ）
  measurement_status?: 'within' | 'below' | 'above' | 'invalid' | null
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
  // 出所: 手入力 / 点検の不具合 / 機器の診断（故障から自動で作る。報告者は連携用のトークンを発行した人）
  source: TroubleSource
  instrument_diagnostic_id: number | null
  reported_at: string
  resolved_at: string | null
  created_at: string
  updated_at: string
}

export type TroubleSource = 'manual' | 'inspection' | 'device_diagnostic'

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

// 計器の5点校正の1回分（校正の傾向。古い順）。max_error は出力・DCS表示の誤差の絶対値の最大（%スパン）
export interface CalibrationStageSummary {
  result: 'pass' | 'fail' | 'incomplete' | 'empty'
  max_error: number | null
  max_hysteresis: number | null
}

export interface CalibrationHistoryRow {
  inspection_id: number
  inspected_at: string
  status: string
  tolerance_percent: number
  adjusted: boolean
  as_found: CalibrationStageSummary
  as_left: CalibrationStageSummary | null
  result: string | null
}

// インターロックのバイパス。requested=申請中 / approved=承認済 / bypassed=バイパス中 / restored=復帰確認待ち / completed=完了 / rejected=却下 / cancelled=取消
export type InterlockBypassStatus = 'requested' | 'approved' | 'bypassed' | 'restored' | 'completed' | 'rejected' | 'cancelled'

type UserRef = { id: number; name: string } | null

export interface InterlockBypass {
  id: number
  interlock_id: number
  request_number: string
  status: InterlockBypassStatus
  reason: string
  compensatory_measure: string
  planned_restore_at: string
  requested_by: UserRef
  requested_at: string
  approved_by: UserRef
  approved_at: string | null
  bypassed_by: UserRef
  bypassed_at: string | null
  restored_by: UserRef
  restored_at: string | null
  confirmed_by: UserRef
  confirmed_at: string | null
  closed_by: UserRef
  closed_at: string | null
  closed_reason: string | null
  // 予定の復帰日時を過ぎてもバイパス中
  overdue: boolean
  // バイパスしてからの時間（バイパス中のときだけ）
  bypassed_hours: number | null
  interlock: { id: number; tag_number: string; name: string; equipment: { id: number; name: string; site: { id: number; name: string } } }
}

export interface Interlock {
  id: number
  equipment_id: number
  tag_number: string
  name: string
  trip_action: string | null
  notes: string | null
  is_active: boolean
  equipment: { id: number; name: string; site: { id: number; name: string } }
  instruments: { id: number; tag_number: string; instrument_type: string | null }[]
  // 終わっていない（申請中〜復帰確認待ち）バイパス
  open_bypass: InterlockBypass | null
  // 詳細だけ。新しい順
  bypasses?: InterlockBypass[]
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

// ホーム（GET /home）。所属のチーム → 課 → 部のエリアごとに、今日やることを出す
type NamedRef = { id: number; name: string }

export interface HomePlan extends Pick<InspectionPlan,
  'id' | 'name' | 'next_due_on' | 'days_until_due' | 'interval_days' | 'inspection_type' | 'equipment_id' | 'instrument_id' | 'checklist_template_id' | 'reference_standard_id'> {
  equipment: NamedRef | null
  equipments: NamedRef[]
  instrument: { id: number; tag_number: string } | null
  reference_standard: NamedRef | null
  inspection_plan_group: NamedRef
}

export interface HomeTask {
  id: number
  title: string
  kind: 'inspection' | 'overhaul' | 'replacement' | 'work'
  status: 'not_started' | 'in_progress'
  notes: string | null
  checklist_template_id: number | null
  scheduled_maintenance: { id: number; title: string }
  equipment: NamedRef
  instrument: { id: number; tag_number: string } | null
  assigned_to: NamedRef | null
}

export interface HomeTrouble {
  id: number
  title: string
  status: string
  priority: string
  reported_at: string
  source: TroubleSource
  equipment: NamedRef
  instrument: { id: number; tag_number: string } | null
  assigned_to: NamedRef | null
}

// 夕会の実績（点検日が今日の点検は、下書きのままのものを含む。画面で積み残しに分ける）。承認待ちの点検も同じ形
export interface HomeInspection {
  id: number
  status: 'draft' | 'submitted' | 'approval_requested' | 'approved'
  inspection_type: string
  inspected_at: string
  equipment_id: number
  equipment: NamedRef
  equipments: NamedRef[]
  instrument: { id: number; tag_number: string } | null
  user: NamedRef
  department: NamedRef
  checklist_template: NamedRef | null
}

export interface HomeResponse {
  id: number
  response_type: string
  description: string
  responded_at: string
  user: NamedRef
  trouble: { id: number; title: string; status: string; equipment: NamedRef; instrument: { id: number; tag_number: string } | null }
}

export interface HomeCompletedTask {
  id: number
  title: string
  kind: HomeTask['kind']
  completed_on: string
  scheduled_maintenance: { id: number; title: string }
  department: NamedRef | null
  equipment: NamedRef
  instrument: { id: number; tag_number: string } | null
  assigned_to: NamedRef | null
}

// department が null のエリアは拠点全体（部署のない人・所属と別の拠点）
export interface HomeArea {
  department: (NamedRef & { level: 'division' | 'section' | 'team' }) | null
  inspection_plans: HomePlan[]
  maintenance_tasks: HomeTask[]
  troubles: { total_count: number; items: HomeTrouble[] }
  results: { inspections: HomeInspection[]; trouble_responses: HomeResponse[]; completed_tasks: HomeCompletedTask[] }
}

export interface HomeBoard {
  today: string
  tomorrow: string
  // manager=承認待ちを先頭に / operator=運転員（不具合の報告・自分の報告の状況） / worker=やること
  kind: 'manager' | 'operator' | 'worker'
  site: NamedRef
  interlock_bypasses: InterlockBypass[]
  // 機器の診断から作ったトラブルのうち、どのエリアにも入らないもの（担当者も、計器の点検計画の担当部署もない）
  diagnostic_troubles: HomeTrouble[]
  areas: HomeArea[]
  approvals?: { inspections: HomeInspection[]; interlock_bypasses: InterlockBypass[] }
  my_troubles?: HomeTrouble[]
}
