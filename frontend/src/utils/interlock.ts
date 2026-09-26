// インターロックのバイパスの表示用のラベル・色と、状態ごとに次にできる操作
import type { InterlockBypass, InterlockBypassStatus } from '@/types/models'

export const BYPASS_STATUS_LABEL: Record<InterlockBypassStatus, string> = {
  requested: '承認待ち', approved: '承認済（未実施）', bypassed: 'バイパス中', restored: '復帰確認待ち',
  completed: '完了', rejected: '却下', cancelled: '取消',
}

export const BYPASS_STATUS_COLOR: Record<InterlockBypassStatus, string> = {
  requested: 'info', approved: 'info', bypassed: 'warning', restored: 'secondary',
  completed: 'success', rejected: 'grey', cancelled: 'grey',
}

// 一覧の絞り込み（台帳の bypass_state）
export const BYPASS_STATE_OPTIONS = [
  { title: '復帰期限超過', value: 'overdue' },
  { title: 'バイパス中', value: 'bypassed' },
  { title: '復帰確認待ち', value: 'restored' },
  { title: '承認待ち', value: 'requested' },
  { title: '終わっていないバイパスあり', value: 'open' },
  { title: 'バイパスなし', value: 'none' },
]

export function bypassLabel(bypass: Pick<InterlockBypass, 'status' | 'overdue'>): string {
  return bypass.overdue ? '復帰期限超過' : BYPASS_STATUS_LABEL[bypass.status]
}

export function bypassColor(bypass: Pick<InterlockBypass, 'status' | 'overdue'>): string {
  return bypass.overdue ? 'error' : BYPASS_STATUS_COLOR[bypass.status]
}

// 日本時間の「9/26 14:05」
export function formatDateTime(value: string | null | undefined): string {
  if (!value) return '—'
  return new Date(value).toLocaleString('ja-JP', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })
}

// 経過時間を「1日2時間」「5時間」のように
export function formatHours(hours: number | null | undefined): string {
  if (hours == null) return '—'
  if (hours < 24) return `${hours}時間`
  const days = Math.floor(hours / 24)
  const rest = hours % 24
  return rest ? `${days}日${rest}時間` : `${days}日`
}

// 予定の復帰日時まで（過ぎていれば「◯時間超過」）
export function restoreDueLabel(bypass: Pick<InterlockBypass, 'planned_restore_at'>, now: Date = new Date()): string {
  const diff = Math.round((new Date(bypass.planned_restore_at).getTime() - now.getTime()) / 3600000)
  return diff < 0 ? `${formatHours(-diff)}超過` : `あと${formatHours(diff)}`
}
