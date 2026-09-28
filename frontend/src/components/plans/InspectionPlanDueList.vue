<script setup lang="ts">
// 点検計画の期限順の一覧（「計画」画面の「点検の期限順」。旧の点検計画の一覧）。期限超過・周期の見直しの候補・機器の診断による前倒しの候補で絞り込み、行から点検を始める
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import StatusChip from '@/components/StatusChip.vue'
import FilterSelect from '@/components/FilterSelect.vue'
import IntervalReviewDialog from '@/components/IntervalReviewDialog.vue'
import CalibrationWorkOrderDialog from '@/components/plans/CalibrationWorkOrderDialog.vue'
import DiagnosticAdvanceDialog from '@/components/plans/DiagnosticAdvanceDialog.vue'
import InspectionPlanDialog from '@/components/plans/InspectionPlanDialog.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { DIAGNOSTIC_STATUS } from '@/constants/diagnostics'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { InspectionPlan, InspectionPlanGroup } from '@/types/models'
import { dueColor, dueLabel, inspectionFromPlan, referenceStandardFromPlan } from '@/utils/inspectionPlan'
import { groupLabel } from '@/utils/inspectionPlanGroup'
import { equipmentNames } from '@/utils/equipment'
import { REVIEW_COLOR, REVIEW_FILTER_OPTIONS, REVIEW_LABEL } from '@/utils/intervalReview'
import { regulationColor } from '@/utils/regulation'
import { siteIdsFromQuery } from '@/utils/listQuery'
import { latestGuard } from '@/utils/latestGuard'

const route = useRoute()
const router = useRouter()
const { canManageReferenceStandard } = usePermissions()
const authStore = useAuthStore()

const plans = ref<InspectionPlan[]>([])
const { equipments, departments, load: loadSiteOptions } = useSiteScopeOptions()
// 点検のまとまり（表示する拠点の分）と、法規区分の選択肢
const groups = ref<InspectionPlanGroup[]>([])
const regulations = ref<{ id: number; name: string }[]>([])
const loading = ref(false)

// 通常業務では自拠点の計画だけ見ればよいため、自分の所属拠点を初期値にする
const filters = ref({
  site_ids: siteIdsFromQuery(route.query.site_ids, (authStore.user?.site_id ? [authStore.user.site_id] : []) as number[]),
  equipment_ids: [] as number[],
  inspection_plan_group_ids: [] as number[],
  regulation_ids: [] as number[],
  // 担当部署（まとまりの部署。配下の部署を含む）
  department_id: null as number | null,
  overdue: route.query.overdue === 'true',
  // 周期の見直しの候補（5点校正の記録から。any / extend / shorten）
  interval_review: (typeof route.query.interval_review === 'string' ? route.query.interval_review : null) as string | null,
  // 機器の診断（保守要求・仕様外）で、次回期限を前倒しする候補
  diagnostic_advance: route.query.diagnostic_advance === 'true',
})

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

const fetchPlansGuard = latestGuard()

async function fetchPlans() {
  const isLatest = fetchPlansGuard()
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.equipment_ids.length) params.equipment_ids = filters.value.equipment_ids
    if (filters.value.inspection_plan_group_ids.length) params.inspection_plan_group_ids = filters.value.inspection_plan_group_ids
    if (filters.value.regulation_ids.length) params.regulation_ids = filters.value.regulation_ids
    if (filters.value.department_id) params.department_id = filters.value.department_id
    if (filters.value.overdue) params.overdue = 'true'
    if (filters.value.interval_review) params.interval_review = filters.value.interval_review
    if (filters.value.diagnostic_advance) params.diagnostic_advance = 'true'
    const res = await api.get('/inspection_plans', { params })
    if (!isLatest()) return
    plans.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

const groupsGuard = latestGuard()

async function loadGroups(siteIds: number[]) {
  const isLatest = groupsGuard()
  const res = await api.get('/inspection_plan_groups', { params: siteIds.length ? { site_ids: siteIds } : {} })
  if (isLatest()) groups.value = res.data.data
}

// 拠点が1つに決まらないときは、まとまりの名前に拠点名を付けて区別する
const groupTitle = (group: InspectionPlanGroup) => groupLabel(group, filters.value.site_ids.length !== 1)

async function fetchMasters() {
  const [, regulationRes] = await Promise.all([
    loadSiteOptions(filters.value.site_ids),
    api.get('/regulations'),
    loadGroups(filters.value.site_ids),
  ])
  regulations.value = regulationRes.data.data
}

// 拠点を変えたら、表示する拠点にない設備・まとまり・部署の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
function changeSite(siteIds: number[]) {
  const shown = (id: number) => siteIds.length === 0 || siteIds.includes(id)
  const keepEquipment = filters.value.equipment_ids.filter((id) => equipments.value.find((e) => e.id === id && shown(e.site_id)))
  const keepGroups = filters.value.inspection_plan_group_ids.filter((id) => groups.value.find((g) => g.id === id && shown(g.site_id)))
  const keepDepartment = departments.value.find((d) => d.id === filters.value.department_id && shown(d.site_id))
  filters.value = {
    ...filters.value,
    site_ids: siteIds,
    equipment_ids: keepEquipment,
    inspection_plan_group_ids: keepGroups,
    department_id: keepDepartment ? keepDepartment.id : null,
  }
  loadSiteOptions(siteIds)
  loadGroups(siteIds)
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
  router.push(inspectionFromPlan(plan))
}

// 計画の追加と、校正の作業指示の書き出し（ボタンは「計画」画面の見出しにある。書き出しの候補は表示中の拠点の計画）
const dialog = ref(false)
const workOrderDialog = ref(false)
defineExpose({
  openCreate: () => { dialog.value = true },
  openWorkOrder: () => { workOrderDialog.value = true },
})

onMounted(() => {
  fetchMasters()
  fetchPlans()
})
watch(filters, fetchPlans, { deep: true })
</script>

<template>
  <div>
    <div class="pk-filters">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <!-- 「計画」画面の表示の切り替え（ほかの表示と同じ位置に置くため、親から受け取る） -->
      <slot name="view" />
      <FilterSelect v-model="filters.equipment_ids" :items="equipments" item-title="name" item-value="id" label="設備" searchable style="max-width: 240px" />
      <FilterSelect
        v-model="filters.inspection_plan_group_ids"
        :items="groups.map((g) => ({ id: g.id, title: groupTitle(g) }))"
        item-title="title"
        item-value="id"
        label="まとまり"
        searchable
        style="max-width: 260px"
        data-testid="plan-group-filter"
      />
      <FilterSelect v-model="filters.regulation_ids" :items="regulations" item-title="name" item-value="id" label="法規区分" style="max-width: 220px" />
      <v-select
        v-model="filters.department_id"
        :items="departments"
        item-title="display_name"
        item-value="id"
        label="担当部署"
        clearable
        density="compact"
        hide-details
        style="min-width: 200px; max-width: 280px"
      />
      <v-switch v-model="filters.overdue" label="期限超過のみ" color="error" density="compact" hide-details />
      <v-select
        v-model="filters.interval_review"
        :items="REVIEW_FILTER_OPTIONS"
        label="周期の見直し"
        density="compact"
        hide-details
        clearable
        style="min-width: 220px; max-width: 240px"
        data-testid="interval-review-filter"
      />
      <v-switch v-model="filters.diagnostic_advance" label="診断で前倒しの候補" color="primary" density="compact" hide-details data-testid="diagnostic-advance-filter" />
    </div>

    <v-data-table
      :headers="headers"
      :items="plans"
      :loading="loading"
      :sort-by="[{ key: 'next_due_on', order: 'asc' }]"
      hover
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
  </div>
</template>
