// 基準器の表示用のラベル・色と、点検日に使えるかの判定。
// 判定はサーバー（backend/app/models/reference_standard.rb の unusable_reasons）と同じ規則で、
// 提出前に画面で分かるようにするためのもの（提出時の確認はサーバーが行う）
import type { CalibrationState, ReferenceStandard, ReferenceStandardCalibration } from '@/types/models'

export const CATEGORY_LABEL: Record<string, string> = { pressure: '圧力・差圧', electrical: '電流・電圧', temperature: '温度', other: 'その他' }
export const STATUS_LABEL: Record<string, string> = { usable: '使用可', in_calibration: '校正中', retired: '使用停止' }
export const STATUS_COLOR: Record<string, string> = { usable: 'success', in_calibration: 'warning', retired: 'grey' }
export const STATE_LABEL: Record<CalibrationState, string> = { never: '校正の記録なし', failed: '校正不合格', expired: '期限切れ', expiring: '期限間近', valid: '校正済み' }
export const STATE_COLOR: Record<CalibrationState, string> = { never: 'grey', failed: 'error', expired: 'error', expiring: 'warning', valid: 'success' }
export const CALIBRATION_RESULT_LABEL: Record<string, string> = { pass: '合格（メーカー点検済み）', fail: '不合格' }
export const DEFAULT_INTERVAL_DAYS = 365

// 実施日の日付に days を足す（サーバーの valid_until の既定値と同じ）。ISO日付（YYYY-MM-DD）で受け渡す
export function addDays(iso: string, days: number): string {
  const d = new Date(`${iso}T00:00:00`)
  d.setDate(d.getDate() + days)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

// 点検日に効いていた校正（その日以前で最新のもの。calibrations は新しい順）
export function calibrationOn(standard: Pick<ReferenceStandard, 'calibrations'>, isoDate: string): ReferenceStandardCalibration | undefined {
  return standard.calibrations.find((c) => c.performed_on <= isoDate)
}

// 点検日 isoDate に、この基準器を使えない理由。取引用の計器の点検では、トレーサビリティのある校正が必要
export function unusableReasons(standard: ReferenceStandard, isoDate: string, requireTraceable: boolean): string[] {
  const reasons: string[] = []
  if (standard.status !== 'usable') reasons.push(`${STATUS_LABEL[standard.status]}のため使えません`)
  const calibration = calibrationOn(standard, isoDate)
  if (!calibration) reasons.push(`点検日（${isoDate}）時点で有効な校正の記録がありません`)
  else if (calibration.result === 'fail') reasons.push(`点検日時点の校正（${calibration.performed_on}）が不合格です`)
  else if (calibration.valid_until < isoDate) reasons.push(`点検日時点で校正の有効期限（${calibration.valid_until}）が切れています`)
  else if (requireTraceable && !calibration.traceable) reasons.push('取引用の計器の点検には、トレーサビリティのある校正が必要です（点検日時点の校正は、トレーサビリティなし）')
  return reasons
}
