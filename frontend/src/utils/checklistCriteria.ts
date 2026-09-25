// チェックリストの項目の型と基準（テンプレートの項目・点検の項目で共有）と、判定（良好／不具合あり／該当なし）。
// 測定値の判定の規則は、バックエンドの ChecklistCriteria（app/models/concerns/checklist_criteria.rb）と同じ（変えるときは両方を直す）

export type ItemResult = 'good' | 'defect' | 'na'
export type LimitStatus = 'within' | 'below' | 'above' | 'invalid'

// 項目の基準。API の decimal は文字列で返るため、数値は文字列も受け付ける
export interface ItemCriteria {
  item_type: string
  section?: string | null
  criterion?: string | null
  unit?: string | null
  lower_limit?: string | number | null
  upper_limit?: string | number | null
  options?: string[] | null
  required?: boolean
}

export const ITEM_TYPE_OPTIONS = [
  { title: '確認', value: 'check' },
  { title: '測定値', value: 'measurement' },
  { title: '選択式', value: 'choice' },
  { title: '自由記述', value: 'text' },
  { title: '5点校正', value: 'calibration' },
]

export const RESULT_LABEL: Record<ItemResult, string> = { good: '良好', defect: '不具合あり', na: '－' }
export const RESULT_COLOR: Record<ItemResult, string> = { good: 'success', defect: 'error', na: 'grey' }

// 良好・不具合あり・該当なしを付ける種別。選択式・自由記述は、不具合あり・該当なしだけ
const JUDGED_TYPES = ['check', 'measurement', 'calibration']
export const isJudgedType = (itemType: string) => JUDGED_TYPES.includes(itemType)

const NUMBER = /^[-+]?(\d+(\.\d*)?|\.\d+)$/

function limit(value: string | number | null | undefined): number | null {
  if (value === null || value === undefined || value === '') return null
  const n = Number(value)
  return Number.isFinite(n) ? n : null
}

// 測定値を数値にする（全角は半角にしてから。読めなければ null）
export function parseMeasurement(value: string | null | undefined): number | null {
  const text = (value ?? '').normalize('NFKC').trim()
  return NUMBER.test(text) ? Number(text) : null
}

export function hasLimits(item: ItemCriteria) {
  return limit(item.lower_limit) !== null || limit(item.upper_limit) !== null
}

// 測定値と許容範囲の関係。範囲がない・値が空なら null（判定は人が付ける）
export function limitStatus(item: ItemCriteria, value: string | null | undefined): LimitStatus | null {
  if (item.item_type !== 'measurement' || !hasLimits(item) || !(value ?? '').trim()) return null
  const n = parseMeasurement(value)
  if (n === null) return 'invalid'
  const lower = limit(item.lower_limit)
  const upper = limit(item.upper_limit)
  if (lower !== null && n < lower) return 'below'
  if (upper !== null && n > upper) return 'above'
  return 'within'
}

// 数値の表示（末尾の 0 を落とす: "3.9200" → "3.92"）
const num = (value: string | number | null | undefined) => String(Number(value))

// 許容範囲の表示（「3.92〜4.08 mA」「10 秒以下」「10 MΩ以上」）
export function limitsText(item: ItemCriteria): string {
  const lower = limit(item.lower_limit)
  const upper = limit(item.upper_limit)
  const unit = item.unit ? ` ${item.unit}` : ''
  if (lower !== null && upper !== null) return `${num(lower)}〜${num(upper)}${unit}`
  if (upper !== null) return `${num(upper)}${unit}以下`
  if (lower !== null) return `${num(lower)}${unit}以上`
  return ''
}

// 必須の項目に記入があるか（判定を付ける種別は判定、選択式・自由記述は値か該当なし）
export function isFilled(item: ItemCriteria & { result?: string | null; text_value?: string | null }) {
  if (isJudgedType(item.item_type)) return !!item.result
  return !!(item.text_value ?? '').trim() || !!item.result
}

// 点検の項目に写す基準（テンプレートの項目から）
export function criteriaOf(item: ItemCriteria) {
  return {
    section: item.section ?? null,
    criterion: item.criterion ?? null,
    unit: item.unit ?? null,
    lower_limit: item.lower_limit ?? null,
    upper_limit: item.upper_limit ?? null,
    options: item.options ?? null,
    required: !!item.required,
  }
}

// 区分の見出しを、その区分の最初の項目の前にだけ出す
export function startsSection<T extends { section?: string | null }>(items: T[], index: number) {
  const section = items[index]?.section
  return !!section && (index === 0 || items[index - 1]?.section !== section)
}
