// 詳細画面の「変更履歴」用に、監査ログの changes_json（{ カラム名: [前, 後] }）を、画面に出す形に整える。
// カラム名は日本語のラベルに、状態などの値は呼び方に、日時は日本時間にする。
// ID（equipment_id など）は、そのままでは何のことか分からないため、作成のときは出さず、更新のときは「変更あり」とだけ出す
// （名前は履歴の元の画面で見られる。ID そのものが要る管理者は、監査ログの画面で見る）。
// 知らないカラムは、情報を失わないよう、カラム名のまま出す
import { inspectionStatusLabel, inspectionTypeLabel, priorityLabel, troubleStatusLabel } from '@/constants/recordLabels'
import { ACCEPTANCE_RESULT_LABEL, MAINTENANCE_STATUS_LABEL, TASK_KIND_LABEL, TASK_STATUS_LABEL } from '@/constants/maintenanceStatus'

export interface AuditChange {
  key: string
  label: string
  from: string
  to: string
  // true のときは、前後の値を出さず「変更あり」とだけ出す（ID の変更）
  opaque: boolean
}

// 履歴に出さないカラム（どの対象でも意味がない）
const HIDDEN_KEYS = new Set(['id', 'created_at', 'updated_at'])

const FIELD_LABELS: Record<string, string> = {
  title: 'タイトル', description: '内容', notes: '備考', name: '名称',
  status: '状態', priority: '優先度', kind: '種別', location: '設置場所',
  reported_at: '報告日時', resolved_at: '解決日時', responded_at: '対応日時', inspected_at: '点検日時',
  response_type: '対応種別', used_materials: '使用資材',
  inspection_type: '点検種別', has_defect: '不具合', checked: '確認', content: '内容', item_type: '項目の種類',
  measured_value: '測定値', text_value: '入力内容', calibration_result: '校正の結果',
  planned_start_on: '予定開始日', planned_end_on: '予定終了日', actual_start_on: '実績開始日', actual_end_on: '実績終了日',
  completed_on: '完了日', accepted_on: '検収日', acceptance_result: '検収の結果', acceptance_notes: '検収の備考',
  tag_number: 'タグ番号', instrument_type: '計器の種類', seal_fluid: 'シール液',
  management_number: '管理番号', category: '区分', model_number: '型番', serial_number: 'シリアル番号',
  measuring_range: '測定範囲', accuracy: '精度',
  range_lower: '範囲の下限', range_upper: '範囲の上限', range_unit: '範囲の単位',
  tolerance_percent: '許容差（%）', tolerance_basis: '許容差の基準',
  output_characteristic: '出力特性', dcs_characteristic: 'DCSの特性',
  dcs_range_lower: 'DCS範囲の下限', dcs_range_upper: 'DCS範囲の上限', dcs_range_unit: 'DCS範囲の単位',
  telemetry: 'テレメトリ', custody_transfer: '取引用',
  deactivated_on: '退職日', is_active: '有効',
  // 設備・拠点などの ID の対象（opaque。日本語ラベルは「何が変わったか」を示す）
  equipment_id: '設備', instrument_id: '計器', site_id: '拠点', department_id: '部署', user_id: 'ユーザ',
  service_id: 'サービス（流体）', line_class_id: '配管クラス', reported_by_id: '報告者', assigned_to_id: '担当者', accepted_by_id: '検収者',
  trouble_id: 'トラブル', maintenance_task_id: '定期整備の作業', scheduled_maintenance_id: '定期整備',
  maintenance_series_id: '系列', checklist_template_id: 'チェックリスト', checklist_template_item_id: 'チェックリストの項目',
  inspection_item_id: '点検の項目', inspection_id: '点検',
  equipment_ids: '対象設備', regulation_ids: '適用法規', intervals: '周期',
  ai_suggestion_id: 'プラナの整理案',
}

const STATUS_BY_TYPE: Record<string, Record<string, string>> = {
  Trouble: troubleStatusLabel,
  Inspection: inspectionStatusLabel,
  ScheduledMaintenance: MAINTENANCE_STATUS_LABEL,
  MaintenanceTask: TASK_STATUS_LABEL,
  ReferenceStandard: { usable: '使用可', in_calibration: '校正中', retired: '使用停止' },
}

// 対象に依らない、カラム名ごとの値の呼び方
const VALUE_LABELS: Record<string, Record<string, string>> = {
  priority: priorityLabel,
  inspection_type: inspectionTypeLabel,
  acceptance_result: ACCEPTANCE_RESULT_LABEL,
  kind: TASK_KIND_LABEL,
  response_type: { investigation: '調査', repair: '修理', replacement: '交換', observation: '経過観察' },
  item_type: { check: 'チェック', measurement: '測定', text: '入力', calibration: '校正' },
  category: { pressure: '圧力', electrical: '電気', temperature: '温度', other: 'その他' },
}

const isIdKey = (key: string) => key.endsWith('_id')

const pad = (n: number) => String(n).padStart(2, '0')

// 「2026-09-21T09:50:10.509+09:00」のような日時の文字列だけを、日本時間の「2026/09/21 09:50」にする（日付だけの値はそのまま）
function formatIfDateTime(value: string): string {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value)) return value
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return value
  const jst = new Date(d.getTime() + 9 * 60 * 60 * 1000)
  return `${jst.getUTCFullYear()}/${pad(jst.getUTCMonth() + 1)}/${pad(jst.getUTCDate())} ${pad(jst.getUTCHours())}:${pad(jst.getUTCMinutes())}`
}

function formatValue(auditableType: string, key: string, value: unknown): string {
  if (value == null || value === '') return '—'
  if (typeof value === 'boolean') return value ? 'はい' : 'いいえ'
  if (Array.isArray(value)) return `${value.length}件`
  if (typeof value === 'object') return JSON.stringify(value)
  const text = String(value)
  if (key === 'status') return STATUS_BY_TYPE[auditableType]?.[text] ?? text
  if (key === 'ai_suggestion_id') return '使用'
  return VALUE_LABELS[key]?.[text] ?? formatIfDateTime(text)
}

// action: 'create' のとき、ID のカラムは出さない（作成の履歴に「設備」「報告者」が並んでも、意味がないため。ただしプラナの下書きの使用は残す）
export function formatAuditChanges(changes: unknown, auditableType: string, action: string): AuditChange[] {
  if (!changes || typeof changes !== 'object') return []
  return Object.entries(changes as Record<string, unknown>)
    .filter(([key]) => !HIDDEN_KEYS.has(key))
    .filter(([key]) => !(action === 'create' && isIdKey(key) && key !== 'ai_suggestion_id'))
    .map(([key, raw]) => {
      const [from, to] = Array.isArray(raw) && raw.length === 2 ? raw : [null, raw]
      const fromText = formatValue(auditableType, key, from)
      const toText = formatValue(auditableType, key, to)
      // ID の変更と、件数だけでは違いが分からない配列（対象設備が同じ数のまま入れ替わったときの「2件 → 2件」）は、「変更あり」とだけ出す
      const opaque = (isIdKey(key) && key !== 'ai_suggestion_id') || (Array.isArray(from) && Array.isArray(to) && fromText === toText)
      return { key, label: FIELD_LABELS[key] ?? key, from: fromText, to: toText, opaque }
    })
}
