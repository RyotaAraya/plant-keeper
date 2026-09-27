import type { RouteLocationRaw } from 'vue-router'
import type { InspectionPlan } from '@/types/models'
import { coveredEquipments, type NamedEquipment } from '@/utils/equipment'

type PlanTarget = Pick<InspectionPlan, 'id' | 'equipment_id' | 'instrument_id' | 'checklist_template_id' | 'inspection_type'> & {
  equipment?: NamedEquipment | null
  equipments?: NamedEquipment[]
}

// 計画から点検を実施する画面（点検計画の一覧・朝会ボードで共用）。
// 設備・計器・チェックリストを引き継ぎ、複数の設備をまとめた計画は、その設備すべてを点検に引き継ぐ（先頭が代表の設備）
export function inspectionFromPlan(plan: PlanTarget): RouteLocationRaw {
  const query: Record<string, string> = {
    inspection_plan_id: String(plan.id),
    equipment_id: String(plan.equipment_id ?? ''),
    equipment_ids: coveredEquipments(plan).map((e) => e.id).join(','),
    inspection_type: plan.inspection_type,
  }
  if (plan.instrument_id) query.instrument_id = String(plan.instrument_id)
  if (plan.checklist_template_id) query.checklist_template_id = String(plan.checklist_template_id)
  return { path: '/inspections/new', query }
}

// 基準器の校正計画は、点検ではなく基準器の画面で校正を記録する（記録できるのは管理者・マネージャー）
export function referenceStandardFromPlan(plan: Pick<InspectionPlan, 'reference_standard_id'>, canRecord: boolean): RouteLocationRaw {
  return { path: `/reference-standards/${plan.reference_standard_id}`, query: canRecord ? { record: '1' } : {} }
}

// 期限までの日数で色分け（超過=赤、7日以内=橙）。点検計画の期限順の一覧と、「計画」画面のまとまりの中で共用
export function dueColor(plan: Pick<InspectionPlan, 'overdue' | 'days_until_due'>) {
  if (plan.overdue) return 'error'
  if (plan.days_until_due <= 7) return 'warning'
  return 'success'
}

export function dueLabel(plan: Pick<InspectionPlan, 'overdue' | 'days_until_due' | 'next_due_on'>) {
  if (plan.overdue) return `${plan.next_due_on}（${-plan.days_until_due}日超過）`
  if (plan.days_until_due === 0) return `${plan.next_due_on}（本日）`
  return `${plan.next_due_on}（あと${plan.days_until_due}日）`
}
