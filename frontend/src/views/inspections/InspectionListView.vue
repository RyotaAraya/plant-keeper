<script setup lang="ts">
import { computed, ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import { formatDate } from '@/utils/datetime'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import CalibrationImportDialog from '@/components/CalibrationImportDialog.vue'
import FilterResetButton from '@/components/FilterResetButton.vue'
import FilterSelect from '@/components/FilterSelect.vue'
import InstrumentFilterChip from '@/components/InstrumentFilterChip.vue'
import StatusChip from '@/components/StatusChip.vue'
import { inspectionName } from '@/utils/inspectionWorkflow'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { hasQueryConditions, useSavedFilters, withoutQueryConditions } from '@/composables/useSavedFilters'
import { keepInSites, keepOneInSites, useSiteScope } from '@/composables/useSiteScope'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { inspectionTypeLabel } from '@/constants/recordLabels'
import { idFromQuery, listFromQuery } from '@/utils/listQuery'
import { equipmentNames } from '@/utils/equipment'
import { latestGuard } from '@/utils/latestGuard'

const route = useRoute()
const router = useRouter()
const { initialSiteIds, savedSiteIds } = useSiteScope()

// URLで記録の見方を保持する。見方は記録の範囲（すべて・本人の下書き・承認待ち）だけを変え、絞り込みは3つで共通
const view = computed(() => route.query.view === 'drafts' || route.query.view === 'approvals' ? route.query.view : 'all')
function changeView(value: string) {
  void router.replace({ query: { ...route.query, view: value === 'all' ? undefined : value } })
}
const inspections = ref<any[]>([])
const { equipments, departments, load: loadSiteOptions } = useSiteScopeOptions()
const loading = ref(false)
const totalCount = ref(0)
const importOpen = ref(false)
function onImported() {
  if (view.value === 'drafts') void fetchInspections()
  else changeView('drafts')
}

const inspectionTypeOptions = [
  { title: '日常点検', value: 'routine' },
  { title: '定期点検', value: 'periodic' },
  { title: 'テレメトリ', value: 'telemetry' },
  { title: '運転チェック', value: 'operation_check' },
]

const statusOptions = [
  { title: '下書き', value: 'draft' },
  { title: '承認待ち', value: 'approval_requested' },
  { title: '承認済', value: 'approved' },
]

type Filters = {
  site_ids: number[]
  equipment_ids: number[]
  department_id: number | null
  inspection_types: string[]
  // 「すべての記録」のステータス（下書き・承認待ちの見方では使わない）
  statuses: string[]
  // 計器の「すべて見る」から来たときだけの一時的な絞り込み（保存しない）
  instrument_id: number | null
}

// 3つの見方で1つの保存を共有する（計器の絞り込みは保存しない）
const saved = useSavedFilters<Filters>('inspections', {
  site_ids: 'ids',
  equipment_ids: 'ids',
  department_id: 'id',
  inspection_types: { type: 'strings', values: inspectionTypeOptions.map((o) => o.value) },
  statuses: { type: 'strings', values: statusOptions.map((o) => o.value) },
})

// 通常は既定（自拠点・絞り込みなし）＋保存した条件。ほかの画面のリンクから検索条件付きで来たときは、
// 保存した条件を混ぜず、そのリンクの拠点・ステータス・部署・計器で開く（保存した設備などで目的の記録が隠れないように）
function filtersForRoute(): Filters {
  if (hasQueryConditions(route.query)) {
    return {
      site_ids: initialSiteIds(route.query.site_ids),
      equipment_ids: [],
      department_id: idFromQuery(route.query.department_id),
      inspection_types: [],
      statuses: listFromQuery(route.query.status),
      instrument_id: idFromQuery(route.query.instrument_id),
    }
  }
  const stored = saved.load()
  return {
    equipment_ids: [],
    department_id: null,
    inspection_types: [],
    statuses: [],
    ...stored,
    site_ids: savedSiteIds(stored.site_ids),
    instrument_id: null,
  }
}

const filters = ref<Filters>(filtersForRoute())
saved.hold(filters.value)

const headers = computed(() => [
  { title: '点検日', key: 'inspected_at', width: '120px' },
  { title: '点検内容', key: 'name', sortable: false },
  { title: 'ステータス', key: 'status', width: '120px' },
  { title: '設備', key: 'equipments', sortable: false },
  { title: '計器', key: 'instrument.tag_number', width: '110px' },
  { title: '実施者', key: 'user.name', width: '120px' },
  { title: '部署', key: 'department.name', width: '140px' },
  { title: '種別', key: 'inspection_type', width: '110px' },
  ...(view.value === 'drafts' ? [{ title: '', key: 'actions', sortable: false, width: '130px' }] : []),
])

// 絞り込み・見方を続けて変えると取得が重なり、古い取得の応答が後から返ると新しい結果を上書きしてしまう。
// 最新の取得だけを反映する
const fetchGuard = latestGuard()

async function fetchInspections() {
  const isLatest = fetchGuard()
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.equipment_ids.length) params.equipment_ids = filters.value.equipment_ids
    if (filters.value.instrument_id) params.instrument_id = filters.value.instrument_id
    if (filters.value.department_id) params.department_id = filters.value.department_id
    if (filters.value.inspection_types.length) params.inspection_types = filters.value.inspection_types
    // 見方で固定する条件。本人の下書きはサーバーで本人の記録だけに絞る（他人の下書きは取得しない）
    if (view.value === 'drafts') Object.assign(params, { mine: true, status: 'draft' })
    else if (view.value === 'approvals') params.status = 'approval_requested'
    else if (filters.value.statuses.length) params.statuses = filters.value.statuses

    const res = await api.get('/inspections', { params })
    if (!isLatest()) return
    inspections.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    if (isLatest()) loading.value = false
  }
}

// 表示する拠点の設備・部署を取り直し、選択肢にない設備・部署の絞り込み（保存したあとに無効になったものなど）を外す。
// 取得に失敗したとき・取り直しが重なったときは、選択を外さない
async function loadOptions(siteIds: number[]) {
  if (!(await loadSiteOptions(siteIds).catch(() => false))) return
  const equipmentIds = keepInSites(filters.value.equipment_ids, equipments.value, siteIds)
  const departmentId = keepOneInSites(filters.value.department_id, departments.value, siteIds)
  if (equipmentIds.length !== filters.value.equipment_ids.length || departmentId !== filters.value.department_id) {
    filters.value = { ...filters.value, equipment_ids: equipmentIds, department_id: departmentId }
  }
}

// 拠点を変えたら、表示する拠点にない設備・部署の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
function changeSite(siteIds: number[]) {
  filters.value = {
    ...filters.value,
    site_ids: siteIds,
    equipment_ids: keepInSites(filters.value.equipment_ids, equipments.value, siteIds),
    department_id: keepOneInSites(filters.value.department_id, departments.value, siteIds),
  }
  void loadOptions(siteIds)
}

// 保存した条件とURLの検索条件を消し、既定（自拠点・絞り込みなし）に戻す。見方（タブ）はそのまま
function reset() {
  saved.clear()
  if (hasQueryConditions(route.query)) {
    void router.replace({ query: withoutQueryConditions(route.query) })
    return
  }
  applyRoute()
}

function applyRoute() {
  filters.value = filtersForRoute()
  saved.hold(filters.value)
  void loadOptions(filters.value.site_ids)
}

function goToDetail(row: any) {
  router.push(`/inspections/${row.id}`)
}

onMounted(() => {
  void loadOptions(filters.value.site_ids)
  void fetchInspections()
})
watch(filters, (value) => {
  saved.save(value)
  void fetchInspections()
}, { deep: true })

// 見方（view）だけが変わったときは、絞り込みはそのままで取り直す。
// それ以外でクエリが変わったとき（計器で絞り込み中に、サイドバーから開き直したときなど）は、画面は使い回されるので、クエリに合わせ直す
watch(() => route.query, (query, previous) => {
  if (route.path !== '/inspections') return
  if (JSON.stringify({ ...query, view: undefined }) === JSON.stringify({ ...previous, view: undefined })) {
    void fetchInspections()
    return
  }
  applyRoute()
})
</script>

<template>
  <MainLayout>
    <PageHeader title="点検・作業記録" description="点検の結果をチェックリストで記録し、承認まで進めます。不具合はトラブルに自動登録されます。">
      <v-btn variant="outlined" color="primary" prepend-icon="mdi-file-import-outline" class="mr-2" @click="importOpen = true">校正結果の取り込み</v-btn>
      <v-btn color="primary" class="mr-2" :to="{ path: '/plans', query: { tab: 'due', site_ids: filters.site_ids.join(',') || 'all' } }">予定から点検</v-btn>
      <v-btn variant="outlined" :to="{ path: '/inspections/new', query: { return_to: route.fullPath } }">予定外の点検</v-btn>
    </PageHeader>
    <CalibrationImportDialog v-model="importOpen" @imported="onImported" />

    <v-btn-toggle :model-value="view" mandatory divided color="primary" variant="outlined" class="pk-record-views mb-4" aria-label="記録の表示" @update:model-value="changeView">
      <v-btn value="all">すべての記録</v-btn>
      <v-btn value="drafts">自分の下書き</v-btn>
      <v-btn value="approvals">承認待ち</v-btn>
    </v-btn-toggle>

    <div class="pk-filters">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <FilterSelect v-model="filters.equipment_ids" :items="equipments" item-title="name" item-value="id" label="設備" searchable style="max-width: 240px" />
      <v-select
        v-model="filters.department_id"
        :items="departments"
        item-title="display_name"
        item-value="id"
        label="部署"
        clearable
        density="compact"
        hide-details
        style="max-width: 320px"
      />
      <FilterSelect v-model="filters.inspection_types" :items="inspectionTypeOptions" label="種別" style="max-width: 200px" />
      <FilterSelect v-if="view === 'all'" v-model="filters.statuses" :items="statusOptions" label="ステータス" style="max-width: 200px" />
      <InstrumentFilterChip v-if="filters.instrument_id" :instrument-id="filters.instrument_id" @clear="filters.instrument_id = null" />
      <FilterResetButton @reset="reset" />
    </div>

    <p v-if="view === 'drafts'" class="text-body-2 text-medium-emphasis mb-2">自分が作成した下書きです。前日以前の記録も含め、途中から再開できます。</p>
    <p v-else-if="view === 'approvals'" class="text-body-2 text-medium-emphasis mb-2">承認依頼中の記録です。</p>

    <v-data-table
      :headers="headers"
      :items="inspections"
      :loading="loading"
      hover
      class="cursor-pointer"
      :data-testid="`inspection-list-${view}`"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.name="{ item }">{{ inspectionName(item) }}</template>
      <template #item.inspected_at="{ item }">
        <span class="text-no-wrap">{{ formatDate(item.inspected_at) }}</span>
      </template>
      <template #item.equipments="{ item }">
        {{ equipmentNames(item) }}
      </template>
      <template #item.inspection_type="{ item }">
        {{ inspectionTypeLabel[item.inspection_type] || item.inspection_type }}
      </template>
      <template #item.status="{ item }">
        <StatusChip kind="inspection" :value="item.status" />
      </template>
      <template #item.actions="{ item }">
        <!-- 行のクリック（詳細へ）とは別に、入力の画面へ。戻り先はこの一覧 -->
        <v-btn
          size="small"
          variant="outlined"
          color="primary"
          :to="{ path: `/inspections/${item.id}/edit`, query: { return_to: route.fullPath } }"
          :aria-label="`${inspectionName(item)}（記録 #${item.id}）の入力を再開`"
          :data-testid="`inspection-draft-resume-${item.id}`"
          @click.stop
        >
          入力を再開
        </v-btn>
      </template>
      <template #no-data>{{ view === 'drafts' ? '自分の下書きはありません。' : '該当する記録はありません。' }}</template>
    </v-data-table>
  </MainLayout>
</template>

<style scoped>
.pk-record-views { max-width: 100%; }
@media (max-width: 600px) { .pk-record-views :deep(.v-btn) { min-width: 0; padding-inline: 12px; } }
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
