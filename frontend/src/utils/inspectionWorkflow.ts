import type { Inspection } from '@/types/models'
import { inspectionTypeLabel } from '@/constants/recordLabels'

// 戻り先は業務画面の内部URLだけ。直接URLで開いた記録は一覧へ戻す。
export function inspectionReturn(value: unknown): string {
  if (typeof value !== 'string' || !/^\/(home|plans|inspections|maintenances\/\d+)(\?|$)/.test(value) || /[\\\r\n]/.test(value)) return '/inspections'
  const url = new URL(value, 'https://plantkeeper.invalid')
  return `${url.pathname}${url.search}`
}

export function inspectionReturnLabel(value: string): string {
  if (value.startsWith('/home')) return 'ホーム'
  if (value.startsWith('/plans')) return '計画'
  if (value.startsWith('/maintenances/')) return '定期整備の作業'
  return '点検・作業記録'
}

export function inspectionName(inspection: Pick<Inspection, 'inspection_plan' | 'checklist_template' | 'inspection_type'>): string {
  return inspection.inspection_plan?.name || inspection.checklist_template?.name || inspectionTypeLabel[inspection.inspection_type] || '点検'
}
