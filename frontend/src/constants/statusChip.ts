// 状態・優先度のチップの規則（デザインガイド「状態の表示」）。
// 状態は淡い色（tonal）のラベル型にそろえ、今すぐ見るべきもの（緊急・期限超過・復帰期限超過）だけ塗りつぶす（flat）。
// 塗りが多いと注意が埋もれるため、塗りは「注意」の印として取っておく
import { MAINTENANCE_STATUS_COLOR, MAINTENANCE_STATUS_LABEL, TASK_STATUS_COLOR, TASK_STATUS_LABEL } from '@/constants/maintenanceStatus'
import { inspectionStatusColor, inspectionStatusLabel, priorityColor, priorityLabel, troubleStatusColor, troubleStatusLabel } from '@/constants/recordLabels'

export type StatusKind = 'trouble' | 'priority' | 'inspection' | 'maintenance' | 'task'

export interface ChipSpec {
  label: string
  color: string
  // 塗りつぶす（今すぐ見るべきもの）
  alert: boolean
}

const TABLES: Record<StatusKind, { label: Record<string, string>; color: Record<string, string>; alert?: string[] }> = {
  trouble: { label: troubleStatusLabel, color: troubleStatusColor },
  priority: { label: priorityLabel, color: priorityColor, alert: ['critical'] },
  inspection: { label: inspectionStatusLabel, color: inspectionStatusColor },
  maintenance: { label: MAINTENANCE_STATUS_LABEL, color: MAINTENANCE_STATUS_COLOR },
  task: { label: TASK_STATUS_LABEL, color: TASK_STATUS_COLOR },
}

export function chipFor(kind: StatusKind, value: string): ChipSpec {
  const table = TABLES[kind]
  return { label: table.label[value] ?? value, color: table.color[value] ?? 'grey', alert: table.alert?.includes(value) ?? false }
}
