<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import FilterSelect from '@/components/FilterSelect.vue'
import IntervalReviewDialog from '@/components/IntervalReviewDialog.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { InspectionPlan } from '@/types/models'
import { todayForInput } from '@/utils/datetime'
import { coveredEquipments, equipmentNames } from '@/utils/equipment'
import { intervalLabel } from '@/utils/interval'
import { REVIEW_COLOR, REVIEW_FILTER_OPTIONS, REVIEW_LABEL } from '@/utils/intervalReview'
import { regulationColor } from '@/utils/regulation'
import type { RegulationInspection } from '@/types/models'
import { siteIdsFromQuery } from '@/utils/listQuery'
import { latestGuard } from '@/utils/latestGuard'

const route = useRoute()
const router = useRouter()
const { canManageInspectionPlan, canManageReferenceStandard } = usePermissions()
const authStore = useAuthStore()

const plans = ref<InspectionPlan[]>([])
const { equipments, load: loadSiteOptions } = useSiteScopeOptions({ withDepartments: false })
const templates = ref<any[]>([])
const instruments = ref<any[]>([])
const loading = ref(false)

// 通常業務では自拠点の計画だけ見ればよいため、自分の所属拠点を初期値にする
const filters = ref({
  site_ids: siteIdsFromQuery(route.query.site_ids, (authStore.user?.site_id ? [authStore.user.site_id] : []) as number[]),
  equipment_ids: [] as number[],
  overdue: route.query.overdue === 'true',
  // 周期の見直しの候補（5点校正の記録から。any / extend / shorten）
  interval_review: (typeof route.query.interval_review === 'string' ? route.query.interval_review : null) as string | null,
})

const headers = [
  { title: '期限', key: 'next_due_on', width: '190px' },
  { title: '点検計画', key: 'name', minWidth: '240px' },
  { title: '設備・基準器', key: 'equipment.name', width: '180px' },
  { title: '計器', key: 'instrument.tag_number', width: '110px' },
  { title: '周期', key: 'interval_days', width: '110px' },
  { title: '見直し', key: 'interval_review', sortable: false, width: '120px' },
  { title: '前回実施', key: 'last_inspected_on', width: '120px' },
  { title: '', key: 'actions', sortable: false, width: '130px' },
]

const inspectionTypeOptions = [
  { title: '日常点検', value: 'routine' },
  { title: '定期点検', value: 'periodic' },
  { title: 'テレメトリ', value: 'telemetry' },
  { title: '運転チェック', value: 'operation_check' },
]

// 期限までの日数で色分け（超過=赤、7日以内=橙）
function dueColor(plan: InspectionPlan) {
  if (plan.overdue) return 'error'
  if (plan.days_until_due <= 7) return 'warning'
  return 'success'
}

function dueLabel(plan: InspectionPlan) {
  if (plan.overdue) return `${plan.next_due_on}（${-plan.days_until_due}日超過）`
  if (plan.days_until_due === 0) return `${plan.next_due_on}（本日）`
  return `${plan.next_due_on}（あと${plan.days_until_due}日）`
}

const fetchPlansGuard = latestGuard()

async function fetchPlans() {
  const isLatest = fetchPlansGuard()
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.equipment_ids.length) params.equipment_ids = filters.value.equipment_ids
    if (filters.value.overdue) params.overdue = 'true'
    if (filters.value.interval_review) params.interval_review = filters.value.interval_review
    const res = await api.get('/inspection_plans', { params })
    if (!isLatest()) return
    plans.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

async function fetchMasters() {
  const [, tmplRes] = await Promise.all([
    loadSiteOptions(filters.value.site_ids),
    api.get('/checklist_templates'),
  ])
  // 定修のチェックリストは、点検計画ではなく、定期整備の作業で使う
  templates.value = tmplRes.data.data.filter((t: any) => t.cycle !== 'turnaround')
}

// 拠点を変えたら、表示する拠点にない設備の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
function changeSite(siteIds: number[]) {
  const shown = (id: number) => siteIds.length === 0 || siteIds.includes(id)
  const keepEquipment = filters.value.equipment_ids.filter((id) => equipments.value.find((e) => e.id === id && shown(e.site_id)))
  filters.value = { ...filters.value, site_ids: siteIds, equipment_ids: keepEquipment }
  loadSiteOptions(siteIds)
}

// --- 周期の見直しの候補 ---
const reviewDialog = ref(false)
const reviewing = ref<InspectionPlan | null>(null)

function openReview(plan: InspectionPlan) {
  reviewing.value = plan
  reviewDialog.value = true
}

// 基準器の校正計画は、点検ではなく基準器の画面で校正を記録する（記録できるのは管理者・マネージャー）
function openReferenceStandard(plan: InspectionPlan) {
  router.push({ path: `/reference-standards/${plan.reference_standard_id}`, query: canManageReferenceStandard.value ? { record: '1' } : {} })
}

function startInspection(plan: InspectionPlan) {
  const query: Record<string, string> = {
    inspection_plan_id: String(plan.id),
    equipment_id: String(plan.equipment_id ?? ''),
    // 複数の設備をまとめた計画は、その設備すべてを点検に引き継ぐ（先頭が代表の設備）
    equipment_ids: coveredEquipments(plan).map((e) => e.id).join(','),
    inspection_type: plan.inspection_type,
  }
  if (plan.instrument_id) query.instrument_id = String(plan.instrument_id)
  if (plan.checklist_template_id) query.checklist_template_id = String(plan.checklist_template_id)
  router.push({ path: '/inspections/new', query })
}

// 計画の登録ダイアログ
const dialog = ref(false)
const saving = ref(false)
const errors = ref<string[]>([])
const form = ref({
  name: '',
  // 対象の設備。複数の設備をまとめた計画（巡回など）を作れる。先頭が代表の設備（equipment_id）
  equipment_ids: [] as number[],
  equipment_id: null as number | null,
  instrument_id: null as number | null,
  checklist_template_id: null as number | null,
  inspection_type: 'periodic',
  interval_days: 30,
  next_due_on: todayForInput(),
})

// 選んだ設備に適用される法規の、法定検査（周期の目安として表示する）
const legalInspections = ref<(RegulationInspection & { regulation_code: string; regulation_name: string })[]>([])

const equipmentChangeGuard = latestGuard()

async function onEquipmentChange() {
  const isLatest = equipmentChangeGuard()
  form.value.instrument_id = null
  form.value.equipment_id = form.value.equipment_ids[0] ?? null
  legalInspections.value = []
  // 計器の指定と、法定検査の周期の目安は、設備が1つのときだけ
  if (form.value.equipment_ids.length !== 1) {
    instruments.value = []
    return
  }
  const [instrumentRes, equipmentRes] = await Promise.all([
    api.get('/instruments', { params: { equipment_id: form.value.equipment_id, per_page: 100 } }),
    api.get(`/equipments/${form.value.equipment_id}`),
  ])
  if (!isLatest()) return
  instruments.value = instrumentRes.data.data
  legalInspections.value = (equipmentRes.data.data.regulations || []).flatMap((regulation: any) =>
    (regulation.regulation_inspections || []).map((inspection: RegulationInspection) => ({ ...inspection, regulation_code: regulation.code, regulation_name: regulation.name })),
  )
}

// 法定検査の周期を計画に反映する（計画名が空なら「設備名 検査名」を入れる）
function applyLegalInspection(inspection: RegulationInspection) {
  form.value.interval_days = inspection.interval_days
  if (!form.value.name) {
    const equipmentName = equipments.value.find((e) => e.id === form.value.equipment_id)?.name ?? ''
    form.value.name = `${equipmentName} ${inspection.name}`.trim()
  }
}

function openDialog() {
  errors.value = []
  instruments.value = []
  legalInspections.value = []
  form.value = {
    name: '',
    equipment_ids: [],
    equipment_id: null,
    instrument_id: null,
    checklist_template_id: null,
    inspection_type: 'periodic',
    interval_days: 30,
    next_due_on: todayForInput(),
  }
  dialog.value = true
}

async function save() {
  errors.value = []
  saving.value = true
  try {
    await api.post('/inspection_plans', { inspection_plan: form.value })
    dialog.value = false
    await fetchPlans()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  fetchMasters()
  fetchPlans()
})
watch(filters, fetchPlans, { deep: true })
</script>

<template>
  <MainLayout>
    <PageHeader title="点検計画" description="設備・計器の点検と、基準器の年次校正について、周期と次回期限を管理します。期限が来たものから点検・校正を始めます。">
      <v-btn v-if="canManageInspectionPlan" color="primary" prepend-icon="mdi-plus" @click="openDialog">計画を追加</v-btn>
    </PageHeader>

    <div class="pk-filters">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <FilterSelect v-model="filters.equipment_ids" :items="equipments" item-title="name" item-value="id" label="設備" searchable style="max-width: 240px" />
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
    </div>

    <v-data-table
      :headers="headers"
      :items="plans"
      :loading="loading"
      :sort-by="[{ key: 'next_due_on', order: 'asc' }]"
      hover
    >
      <template #item.next_due_on="{ item }">
        <v-chip :color="dueColor(item)" size="small">{{ dueLabel(item) }}</v-chip>
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

    <v-dialog v-model="dialog" max-width="560">
      <v-card>
        <v-card-title>点検計画を追加</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" variant="tonal" class="mb-3">{{ errors.join('、') }}</v-alert>
          <v-text-field v-model="form.name" label="計画名" class="mb-2" />
          <v-select
            v-model="form.equipment_ids"
            :items="equipments"
            item-title="name"
            item-value="id"
            label="設備"
            multiple
            chips
            closable-chips
            hint="複数の設備をまとめた計画（巡回など）を作れます（同じ拠点の設備。最初に選んだ設備が代表になります）"
            persistent-hint
            class="mb-2"
            @update:model-value="onEquipmentChange"
          />
          <div v-if="legalInspections.length" class="mb-3">
            <div class="text-caption text-medium-emphasis mb-1">この設備に適用される法定検査（押すと周期を入れます）</div>
            <v-chip
              v-for="inspection in legalInspections"
              :key="`${inspection.regulation_name}-${inspection.id}`"
              size="small"
              label
              variant="tonal"
              :color="regulationColor(inspection.regulation_code)"
              class="mr-1 mb-1"
              @click="applyLegalInspection(inspection)"
            >
              {{ inspection.name }}（{{ intervalLabel(inspection.interval_days) }}）
            </v-chip>
          </div>
          <v-select
            v-if="form.equipment_ids.length <= 1"
            v-model="form.instrument_id"
            :items="instruments"
            item-title="tag_number"
            item-value="id"
            label="計器（任意）"
            clearable
            class="mb-2"
          />
          <v-select
            v-model="form.checklist_template_id"
            :items="templates"
            item-title="name"
            item-value="id"
            label="チェックリスト（任意）"
            clearable
            class="mb-2"
          />
          <v-select
            v-model="form.inspection_type"
            :items="inspectionTypeOptions"
            item-title="title"
            item-value="value"
            label="種別"
            class="mb-2"
          />
          <v-text-field v-model.number="form.interval_days" label="周期（日）" type="number" min="1" class="mb-2" />
          <v-text-field v-model="form.next_due_on" label="次回期限" type="date" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>
