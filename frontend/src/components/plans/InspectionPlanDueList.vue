<script lang="ts">
export type DueFilters = {
  site_ids: number[]
  department_id: number | null
  regulation_ids: number[]
  equipment_ids: number[]
  inspection_plan_group_ids: number[]
  overdue: boolean
  interval_review: string | null
  diagnostic_advance: boolean
}
</script>
<script setup lang="ts">
// 点検計画の期限順の一覧（「計画」画面の「点検の期限順」。旧の点検計画の一覧）。期限超過・周期の見直しの候補・機器の診断による前倒しの候補で絞り込み、行から点検を始める。
// 絞り込みの条件と選択肢は「計画」画面が持つ（表示を切り替えても条件を保つため）。ここは一覧の取得と行の操作だけ
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import StatusChip from '@/components/StatusChip.vue'
import IntervalReviewDialog from '@/components/IntervalReviewDialog.vue'
import CalibrationWorkOrderDialog from '@/components/plans/CalibrationWorkOrderDialog.vue'
import DiagnosticAdvanceDialog from '@/components/plans/DiagnosticAdvanceDialog.vue'
import InspectionPlanDialog from '@/components/plans/InspectionPlanDialog.vue'
import { DIAGNOSTIC_STATUS } from '@/constants/diagnostics'
import { usePermissions } from '@/composables/usePermissions'
import type { InspectionPlan, InspectionPlanGroup } from '@/types/models'
import { dueColor, dueLabel, inspectionFromPlan, referenceStandardFromPlan } from '@/utils/inspectionPlan'
import { equipmentNames } from '@/utils/equipment'
import { REVIEW_COLOR, REVIEW_LABEL } from '@/utils/intervalReview'
import { regulationColor } from '@/utils/regulation'
import { latestGuard } from '@/utils/latestGuard'

const props = defineProps<{
  filters: DueFilters
  equipments: { id: number; name: string; site_id: number }[]
  groups: InspectionPlanGroup[]
}>()

const route = useRoute()
const router = useRouter()
const { canManageReferenceStandard } = usePermissions()

const plans = ref<InspectionPlan[]>([])
const loading = ref(false)
const page = ref(1)

const headers = [
  { title: '期限', key: 'next_due_on', width: '190px' },
  { title: '点検計画', key: 'name', minWidth: '240px' },
  { title: 'まとまり', key: 'inspection_plan_group.name', minWidth: '200px' },
  { title: '設備・基準器', key: 'equipment.name', width: '180px' },
  { title: '計器', key: 'instrument.tag_number', width: '110px' },
  { title: '周期', key: 'interval_days', width: '110px' },
  { title: '見直し', key: 'interval_review', sortable: false, width: '120px' },
  { title: '前回実施', key: 'last_inspected_on', width: '120px' },
  { title: '', key: 'actions', sortable: false, width: '130px' },
]

const params = computed(() => {
  const f = props.filters
  const result: any = { per_page: 1000 }
  if (f.site_ids.length) result.site_ids = f.site_ids
  if (f.equipment_ids.length) result.equipment_ids = f.equipment_ids
  if (f.inspection_plan_group_ids.length) result.inspection_plan_group_ids = f.inspection_plan_group_ids
  if (f.regulation_ids.length) result.regulation_ids = f.regulation_ids
  if (f.department_id) result.department_id = f.department_id
  if (f.overdue) result.overdue = 'true'
  if (f.interval_review) result.interval_review = f.interval_review
  if (f.diagnostic_advance) result.diagnostic_advance = 'true'
  return result
})

const fetchPlansGuard = latestGuard()

async function fetchPlans() {
  const isLatest = fetchPlansGuard()
  loading.value = true
  try {
    const res = await api.get('/inspection_plans', { params: params.value })
    if (!isLatest()) return
    plans.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

// --- 周期の見直しの候補 ---
const reviewDialog = ref(false)
const reviewing = ref<InspectionPlan | null>(null)

function openReview(plan: InspectionPlan) {
  reviewing.value = plan
  reviewDialog.value = true
}

// --- 機器の診断による前倒しの候補 ---
const advanceDialog = ref(false)
const advancing = ref<InspectionPlan | null>(null)

function openAdvance(plan: InspectionPlan) {
  advancing.value = plan
  advanceDialog.value = true
}

function openReferenceStandard(plan: InspectionPlan) {
  router.push(referenceStandardFromPlan(plan, canManageReferenceStandard.value))
}

function startInspection(plan: InspectionPlan) {
  router.push(inspectionFromPlan(plan, route.fullPath))
}

// 計画の追加と、校正の作業指示の書き出し（ボタンは「計画」画面の見出しにある。書き出しの候補は表示中の拠点の計画）
const dialog = ref(false)
const workOrderDialog = ref(false)
defineExpose({
  firstPage: () => { page.value = 1 },
  openCreate: () => { dialog.value = true },
  openWorkOrder: () => { workOrderDialog.value = true },
})

// 条件が同じなら取り直さない（「計画」画面の定期整備の状態など、この一覧に関係しない条件の変更で取得しない）
watch(() => JSON.stringify(params.value), fetchPlans, { immediate: true })
</script>

<template>
  <section aria-labelledby="plan-due-heading">
    <h2 id="plan-due-heading" class="pk-plan-heading">定期点検<span>点検の期限順（設備・計器ごとの点検計画）</span></h2>
    <v-data-table
      v-model:page="page"
      :headers="headers"
      :items="plans"
      :loading="loading"
      :sort-by="[{ key: 'next_due_on', order: 'asc' }]"
      hover
      data-testid="plan-due"
    >
      <template #item.next_due_on="{ item }">
        <StatusChip :label="dueLabel(item)" :color="dueColor(item)" :alert="item.overdue" />
      </template>
      <template #item.inspection_plan_group.name="{ item }">
        {{ item.inspection_plan_group?.name }}
        <v-chip
          v-if="item.inspection_plan_group?.regulation"
          size="x-small"
          label
          variant="tonal"
          :color="regulationColor(item.inspection_plan_group.regulation.code)"
          class="ml-1"
        >
          {{ item.inspection_plan_group.regulation.name }}
        </v-chip>
      </template>
      <template #item.equipment.name="{ item }">
        <template v-if="item.reference_standard">
          {{ item.reference_standard.name }}
          <v-chip size="x-small" label variant="tonal" color="brown" class="ml-1">基準器</v-chip>
        </template>
        <template v-else>{{ equipmentNames(item) }}</template>
      </template>
      <template #item.interval_days="{ item }"><span class="text-no-wrap">{{ item.interval_days }}日ごと</span></template>
      <template #item.interval_review="{ item }">
        <v-chip
          v-if="item.interval_review"
          :color="REVIEW_COLOR[item.interval_review.kind]"
          size="small"
          label
          variant="flat"
          append-icon="mdi-chevron-right"
          :data-testid="`interval-review-${item.id}`"
          @click="openReview(item)"
        >
          {{ REVIEW_LABEL[item.interval_review.kind] }}
        </v-chip>
        <v-chip
          v-if="item.diagnostic_advance"
          :color="DIAGNOSTIC_STATUS[item.diagnostic_advance.diagnostic_status].color"
          size="small"
          label
          variant="flat"
          append-icon="mdi-chevron-right"
          :title="`機器の診断: ${DIAGNOSTIC_STATUS[item.diagnostic_advance.diagnostic_status].label}`"
          :data-testid="`diagnostic-advance-chip-${item.id}`"
          @click="openAdvance(item)"
        >
          前倒し
        </v-chip>
      </template>
      <template #item.last_inspected_on="{ item }">{{ item.last_inspected_on ?? '未実施' }}</template>
      <template #item.actions="{ item }">
        <v-btn v-if="item.reference_standard" size="small" variant="outlined" @click="openReferenceStandard(item)">
          {{ canManageReferenceStandard ? '校正を記録' : '基準器を見る' }}
        </v-btn>
        <v-btn v-else size="small" variant="outlined" @click="startInspection(item)">点検を実施</v-btn>
      </template>
    </v-data-table>

    <IntervalReviewDialog v-model="reviewDialog" :plan="reviewing" @saved="fetchPlans" />
    <DiagnosticAdvanceDialog
      v-model="advanceDialog"
      :plan="advancing"
      :diagnostic="advancing?.diagnostic_advance ?? null"
      :tag-number="advancing?.instrument?.tag_number"
      @saved="fetchPlans"
    />

    <InspectionPlanDialog v-model="dialog" :equipments="equipments" :groups="groups" @saved="fetchPlans" />
    <CalibrationWorkOrderDialog v-model="workOrderDialog" :site-ids="filters.site_ids" />
  </section>
</template>

<style scoped>
.pk-plan-heading { display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 12px; margin-bottom: 8px; font-size: 1rem; font-weight: 700; }
.pk-plan-heading span { color: var(--pk-muted); font-size: 0.8125rem; font-weight: 400; }
</style>
