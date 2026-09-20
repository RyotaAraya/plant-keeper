// 定期整備の状態（計画中 → 準備中 → 実施中 → 検収 → 完了）の表示と遷移。
// 遷移は、バックエンド（ScheduledMaintenance::STATUS_TRANSITIONS）と同じ。変えるときは両方を直す

export const MAINTENANCE_STATUS_LABEL: Record<string, string> = {
  planned: '計画中', preparing: '準備中', in_progress: '実施中', acceptance: '検収', completed: '完了',
}
export const MAINTENANCE_STATUS_COLOR: Record<string, string> = {
  planned: 'blue-grey', preparing: 'info', in_progress: 'warning', acceptance: 'deep-purple', completed: 'success',
}
export const MAINTENANCE_STATUS_FLOW = ['planned', 'preparing', 'in_progress', 'acceptance', 'completed'] as const

export const MAINTENANCE_TRANSITIONS: Record<string, string[]> = {
  planned: ['preparing', 'in_progress'],
  preparing: ['planned', 'in_progress'],
  in_progress: ['preparing', 'acceptance'],
  acceptance: ['in_progress', 'completed'],
  completed: [],
}

// 状態を変えるボタンの名前（今の状態 → 次の状態）
export function transitionLabel(from: string, to: string): string {
  if (from === 'acceptance' && to === 'in_progress') return '手直しに戻す'
  if (to === 'acceptance') return '検収へ進む'
  if (to === 'completed') return '完了にする'
  const back = MAINTENANCE_STATUS_FLOW.indexOf(to as (typeof MAINTENANCE_STATUS_FLOW)[number]) < MAINTENANCE_STATUS_FLOW.indexOf(from as (typeof MAINTENANCE_STATUS_FLOW)[number])
  return `${MAINTENANCE_STATUS_LABEL[to]}${back ? 'に戻す' : 'にする'}`
}

// 定期整備の作業（部署ごとの、設備・計器の点検や整備）
export const TASK_STATUS_LABEL: Record<string, string> = { not_started: '未着手', in_progress: '実施中', completed: '完了', cancelled: '見送り' }
export const TASK_STATUS_COLOR: Record<string, string> = { not_started: 'blue-grey', in_progress: 'warning', completed: 'success', cancelled: 'grey' }
export const TASK_KIND_LABEL: Record<string, string> = { inspection: '点検', overhaul: '整備', replacement: '交換', work: '工事' }
// チェックリストの周期
export const TEMPLATE_CYCLE_LABEL: Record<string, string> = { patrol: '巡回', monthly: '月次', annual: '年次', turnaround: '定修' }

export const ACCEPTANCE_RESULT_LABEL: Record<string, string> = {
  passed: '合格', passed_with_remarks: '指摘つき合格', rework_required: '手直しあり',
}
export const ACCEPTANCE_RESULT_COLOR: Record<string, string> = {
  passed: 'success', passed_with_remarks: 'warning', rework_required: 'error',
}

// 予定・実績の期間の表示（終了日がなければ開始日だけ）
export function periodLabel(start: string | null | undefined, end: string | null | undefined): string {
  if (!start && !end) return '—'
  return end && end !== start ? `${start ?? ''}〜${end}` : (start ?? '')
}
