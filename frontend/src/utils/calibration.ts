// 5点校正の期待値・誤差・合否の計算。サーバー（backend/app/models/calibration_sheet.rb）と同じ規則で、
// 入力しながら結果を見るために画面でも計算する（保存時の判定はサーバーが行う）。
// - 伝送器: 入力を範囲の各点に加え、出力（4-20mA）とDCS表示を記録する。出力は比例か平方根、DCS表示は出力にさらに平方根をかける設定がある
// - ポジショナ（調節弁）: 開度の指令（%）に対する実開度（%）を記録する
// 誤差は出力のスパン（伝送器は16mA、ポジショナは範囲の幅）に対する%、DCS表示はDCSの範囲の幅に対する%。
// 許容差以内なら合格で、上昇と下降の出力の差（ヒステリシス）も同じ許容差で判定する
import type {
  CalibrationEvaluation,
  CalibrationInput,
  CalibrationPointEvaluation,
  CalibrationPointInput,
  CalibrationReading,
  CalibrationReadingEvaluation,
  CalibrationResult,
  CalibrationSnapshot,
  Instrument,
} from '@/types/models'

export const CALIBRATION_POINTS = [0, 25, 50, 75, 100] as const
export const DIRECTIONS = ['up', 'down'] as const
export const STAGES = ['as_found', 'as_left'] as const
export type Direction = (typeof DIRECTIONS)[number]
export type Stage = (typeof STAGES)[number]

export const STAGE_LABEL: Record<Stage, string> = { as_found: '調整前', as_left: '調整後' }
export const DIRECTION_LABEL: Record<Direction, string> = { up: '上昇', down: '下降' }
export const RESULT_LABEL: Record<CalibrationResult, string> = { pass: '合格', fail: '不合格', incomplete: '未入力あり', empty: '未入力' }
export const RESULT_COLOR: Record<CalibrationResult, string> = { pass: 'success', fail: 'error', incomplete: 'warning', empty: 'grey' }
export const TOLERANCE_BASIS_LABEL: Record<string, string> = { legal: '法令', manufacturer: 'メーカー', internal: '社内基準' }
export const CHARACTERISTIC_LABEL: Record<string, string> = { linear: '比例', square_root: '平方根' }

const TRANSMITTER_MA_MIN = 4
const TRANSMITTER_MA_SPAN = 16
const EPSILON = 1e-9

function emptyReading(): CalibrationReading {
  return { output: null, dcs: null }
}

function emptyStage(): { points: CalibrationPointInput[] } {
  return { points: CALIBRATION_POINTS.map((percent) => ({ percent, up: emptyReading(), down: emptyReading() })) }
}

export function emptyCalibrationInput(): CalibrationInput {
  return { adjusted: false, stages: { as_found: emptyStage(), as_left: emptyStage() } }
}

// 保存済みの記録（calibration_data）を、入力欄の形にする
export function calibrationInputFrom(data: any): CalibrationInput {
  const input = emptyCalibrationInput()
  if (!data) return input
  input.adjusted = !!data.adjusted
  for (const stage of STAGES) {
    for (const point of data.stages?.[stage]?.points ?? []) {
      const target = input.stages[stage].points.find((p) => p.percent === point.percent)
      if (!target) continue
      for (const dir of DIRECTIONS) target[dir] = { output: point[dir]?.output ?? null, dcs: point[dir]?.dcs ?? null }
    }
  }
  return input
}

function toNumber(value: unknown): number | null {
  if (value === null || value === undefined || String(value).trim() === '') return null
  const n = Number(value)
  return Number.isFinite(n) ? n : null
}

// 計器の現在の校正条件。5点校正できない計器（範囲・許容差が未設定など）は null
export function snapshotFromInstrument(instrument: Partial<Instrument> | null | undefined): CalibrationSnapshot | null {
  if (!instrument || !instrument.calibratable || !instrument.calibration_kind) return null
  const lower = toNumber(instrument.range_lower)
  const upper = toNumber(instrument.range_upper)
  const tolerance = toNumber(instrument.tolerance_percent)
  if (lower === null || upper === null || tolerance === null) return null
  return {
    kind: instrument.calibration_kind,
    range_lower: lower,
    range_upper: upper,
    range_unit: instrument.range_unit ?? null,
    output_characteristic: instrument.output_characteristic ?? 'linear',
    dcs_characteristic: instrument.dcs_characteristic ?? 'linear',
    dcs_range_lower: toNumber(instrument.dcs_range_lower),
    dcs_range_upper: toNumber(instrument.dcs_range_upper),
    dcs_range_unit: instrument.dcs_range_unit ?? null,
    tolerance_percent: tolerance,
    tolerance_basis: instrument.tolerance_basis ?? null,
  }
}

export const outputUnit = (s: CalibrationSnapshot) => (s.kind === 'transmitter' ? 'mA' : (s.range_unit ?? ''))
export const dcsUnit = (s: CalibrationSnapshot) => (s.dcs_range_unit ?? s.range_unit ?? '')

function span(s: CalibrationSnapshot) {
  return s.range_upper - s.range_lower
}
function dcsLower(s: CalibrationSnapshot) {
  return s.dcs_range_lower ?? s.range_lower
}
function dcsSpan(s: CalibrationSnapshot) {
  return (s.dcs_range_upper ?? s.range_upper) - dcsLower(s)
}
function outputSpan(s: CalibrationSnapshot) {
  return s.kind === 'transmitter' ? TRANSMITTER_MA_SPAN : span(s)
}

// サーバーの Float#round（四捨五入）に合わせ、負の値も絶対値で丸める
function round3(x: number) {
  const rounded = Math.sign(x) * Math.round(Math.abs(x) * 1000) / 1000
  return rounded === 0 ? 0 : rounded
}

export function expectedAt(s: CalibrationSnapshot, percent: number) {
  const fraction = percent / 100
  const outputFraction = s.output_characteristic === 'square_root' ? Math.sqrt(fraction) : fraction
  const dcsFraction = s.dcs_characteristic === 'square_root' ? Math.sqrt(outputFraction) : outputFraction
  return {
    percent,
    input: s.range_lower + span(s) * fraction,
    output: s.kind === 'transmitter' ? TRANSMITTER_MA_MIN + TRANSMITTER_MA_SPAN * outputFraction : s.range_lower + span(s) * outputFraction,
    dcs: dcsLower(s) + dcsSpan(s) * dcsFraction,
  }
}

function withinTolerance(s: CalibrationSnapshot, error: number) {
  return Math.abs(error) <= s.tolerance_percent + EPSILON
}

function evaluateReading(s: CalibrationSnapshot, expected: { output: number; dcs: number }, reading: CalibrationReading): CalibrationReadingEvaluation {
  const output = toNumber(reading.output)
  const dcs = toNumber(reading.dcs)
  const outputError = output === null ? null : round3(((output - expected.output) / outputSpan(s)) * 100)
  const dcsError = dcs === null ? null : round3(((dcs - expected.dcs) / dcsSpan(s)) * 100)
  const judged = [outputError, dcsError].filter((e): e is number => e !== null).map((e) => withinTolerance(s, e))
  return { output, dcs, output_error: outputError, dcs_error: dcsError, ok: judged.length === 0 ? null : judged.every(Boolean) }
}

function stageResult(s: CalibrationSnapshot, points: CalibrationPointEvaluation[]): CalibrationResult {
  const readings = points.flatMap((row) => [row.up, row.down])
  if (readings.every((r) => r.output === null && r.dcs === null)) return 'empty'
  if (readings.some((r) => r.ok === false) || points.some((row) => row.hysteresis_ok === false)) return 'fail'
  const complete = readings.every((r) => r.output !== null && (s.kind !== 'transmitter' || r.dcs !== null))
  return complete ? 'pass' : 'incomplete'
}

function evaluateStage(s: CalibrationSnapshot, stage: { points: CalibrationPointInput[] } | undefined) {
  const points: CalibrationPointEvaluation[] = CALIBRATION_POINTS.map((percent) => {
    const measured = stage?.points.find((p) => p.percent === percent)
    const expected = expectedAt(s, percent)
    const up = evaluateReading(s, expected, measured?.up ?? emptyReading())
    const down = evaluateReading(s, expected, measured?.down ?? emptyReading())
    const hysteresis = up.output !== null && down.output !== null ? round3((Math.abs(up.output - down.output) / outputSpan(s)) * 100) : null
    return { percent, expected, up, down, hysteresis, hysteresis_ok: hysteresis === null ? null : withinTolerance(s, hysteresis) }
  })
  return { points, result: stageResult(s, points) }
}

// 調整した場合は調整後が最終の判定（調整後が未入力なら調整前）
export function evaluateCalibration(s: CalibrationSnapshot, input: CalibrationInput): CalibrationEvaluation {
  const stages = { as_found: evaluateStage(s, input.stages.as_found), as_left: evaluateStage(s, input.stages.as_left) }
  const finalStage: Stage = input.adjusted && stages.as_left.result !== 'empty' ? 'as_left' : 'as_found'
  return { stages, final_stage: finalStage, result: stages[finalStage].result }
}

// --- 計器の校正条件の入力フォーム ---
export interface CalibrationFields {
  range_lower: string
  range_upper: string
  range_unit: string
  tolerance_percent: string
  tolerance_basis: string | null
  output_characteristic: string
  dcs_characteristic: string
  dcs_range_lower: string
  dcs_range_upper: string
  dcs_range_unit: string
  telemetry: boolean
  custody_transfer: boolean
}

export function emptyCalibrationFields(): CalibrationFields {
  return {
    range_lower: '', range_upper: '', range_unit: '', tolerance_percent: '', tolerance_basis: null,
    output_characteristic: 'linear', dcs_characteristic: 'linear', dcs_range_lower: '', dcs_range_upper: '', dcs_range_unit: '',
    telemetry: false, custody_transfer: false,
  }
}

// APIの数値は "100.0" のような文字列で返るため、入力欄には "100" と表示する
function text(v: unknown): string {
  if (v === null || v === undefined || String(v).trim() === '') return ''
  const n = Number(v)
  return Number.isNaN(n) ? String(v) : String(n)
}

export function calibrationFieldsFrom(i: Partial<Instrument>): CalibrationFields {
  return {
    range_lower: text(i.range_lower), range_upper: text(i.range_upper), range_unit: i.range_unit ?? '',
    tolerance_percent: text(i.tolerance_percent), tolerance_basis: i.tolerance_basis ?? null,
    output_characteristic: i.output_characteristic ?? 'linear', dcs_characteristic: i.dcs_characteristic ?? 'linear',
    dcs_range_lower: text(i.dcs_range_lower), dcs_range_upper: text(i.dcs_range_upper), dcs_range_unit: i.dcs_range_unit ?? '',
    telemetry: !!i.telemetry, custody_transfer: !!i.custody_transfer,
  }
}

// 空欄は null にして送る（未設定に戻す）
export function calibrationFieldsPayload(f: CalibrationFields) {
  const n = (v: string) => (String(v).trim() === '' ? null : Number(v))
  const s = (v: string) => (String(v).trim() === '' ? null : v)
  return {
    range_lower: n(f.range_lower), range_upper: n(f.range_upper), range_unit: s(f.range_unit),
    tolerance_percent: n(f.tolerance_percent), tolerance_basis: f.tolerance_basis || null,
    output_characteristic: f.output_characteristic, dcs_characteristic: f.dcs_characteristic,
    dcs_range_lower: n(f.dcs_range_lower), dcs_range_upper: n(f.dcs_range_upper), dcs_range_unit: s(f.dcs_range_unit),
    telemetry: f.telemetry, custody_transfer: f.custody_transfer,
  }
}
