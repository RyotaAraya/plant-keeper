<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import CalibrationImportDialog from '@/components/CalibrationImportDialog.vue'
import FilterSelect from '@/components/FilterSelect.vue'
import InstrumentFilterChip from '@/components/InstrumentFilterChip.vue'
import StatusChip from '@/components/StatusChip.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { keepInSites, keepOneInSites, useSiteScope } from '@/composables/useSiteScope'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { inspectionTypeLabel } from '@/constants/recordLabels'
import { idFromQuery, listFromQuery } from '@/utils/listQuery'
import { equipmentNames } from '@/utils/equipment'

const route = useRoute()
const router = useRouter()
const { initialSiteIds } = useSiteScope()

const inspections = ref<any[]>([])
const { equipments, departments, load: loadSiteOptions } = useSiteScopeOptions()
const loading = ref(false)
const totalCount = ref(0)
const importOpen = ref(false)

// 通常業務では自拠点の記録だけ見ればよいため、自分の所属拠点を初期値にする（部署は絞らず、拠点全体を見る）
// ほかの画面のリンクから来たときは、その拠点・ステータスで、計器の「すべて見る」から来たときは、その計器で絞り込んだ状態で開く
function filtersFromQuery() {
  return {
    site_ids: initialSiteIds(route.query.site_ids),
    statuses: listFromQuery(route.query.status),
    instrument_id: idFromQuery(route.query.instrument_id),
    department_id: idFromQuery(route.query.department_id),
  }
}

const filters = ref({
  ...filtersFromQuery(),
  equipment_ids: [] as number[],
  inspection_types: [] as string[],
})

const headers = [
  { title: '点検日時', key: 'inspected_at', width: '160px' },
  { title: '種別', key: 'inspection_type', width: '110px' },
  { title: '設備', key: 'equipments', sortable: false },
  { title: '計器', key: 'instrument.tag_number', width: '110px' },
  { title: '実施者', key: 'user.name', width: '120px' },
  { title: '部署', key: 'department.name', width: '140px' },
  { title: 'ステータス', key: 'status', width: '120px' },
]

const inspectionTypeOptions = [
  { title: '日常点検', value: 'routine' },
  { title: '定期点検', value: 'periodic' },
  { title: 'テレメトリ', value: 'telemetry' },
  { title: '運転チェック', value: 'operation_check' },
]

const statusOptions = [
  { title: '下書き', value: 'draft' },
  { title: '提出済', value: 'submitted' },
  { title: '承認待ち', value: 'approval_requested' },
  { title: '承認済', value: 'approved' },
]

// 絞り込みを続けて変えると取得が重なり、古い取得の応答が後から返ると新しい結果を上書きしてしまう。
// 最新の取得だけを反映する
let fetchSeq = 0

async function fetchInspections() {
  const seq = ++fetchSeq
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.equipment_ids.length) params.equipment_ids = filters.value.equipment_ids
    if (filters.value.instrument_id) params.instrument_id = filters.value.instrument_id
    if (filters.value.department_id) params.department_id = filters.value.department_id
    if (filters.value.inspection_types.length) params.inspection_types = filters.value.inspection_types
    if (filters.value.statuses.length) params.statuses = filters.value.statuses

    const res = await api.get('/inspections', { params })
    if (seq !== fetchSeq) return
    inspections.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    if (seq === fetchSeq) loading.value = false
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
  loadSiteOptions(siteIds)
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function goToDetail(row: any) {
  router.push(`/inspections/${row.id}`)
}

onMounted(() => {
  loadSiteOptions(filters.value.site_ids)
  fetchInspections()
})
watch(filters, fetchInspections, { deep: true })

// 同じ一覧のままクエリだけが変わったとき（計器で絞り込み中に、サイドバーから開き直したときなど）は、
// 画面は使い回されるので、クエリの絞り込みに合わせ直す（クエリがなければ、初期値の自拠点・絞り込みなし）
watch(() => route.query, () => {
  if (route.path !== '/inspections') return
  const q = filtersFromQuery()
  filters.value = { ...filters.value, ...q, equipment_ids: [], inspection_types: [] }
  loadSiteOptions(q.site_ids)
})
</script>

<template>
  <MainLayout>
    <PageHeader title="点検・作業記録" description="点検の結果をチェックリストで記録し、承認まで進めます。不具合はトラブルに自動登録されます。">
      <v-btn variant="outlined" color="primary" prepend-icon="mdi-file-import-outline" class="mr-2" @click="importOpen = true">校正結果の取り込み</v-btn>
      <v-btn color="primary" prepend-icon="mdi-plus" @click="router.push('/inspections/new')">新規点検</v-btn>
    </PageHeader>
    <CalibrationImportDialog v-model="importOpen" @imported="fetchInspections" />

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
      <FilterSelect v-model="filters.statuses" :items="statusOptions" label="ステータス" style="max-width: 200px" />
      <InstrumentFilterChip v-if="filters.instrument_id" :instrument-id="filters.instrument_id" @clear="filters.instrument_id = null" />
    </div>

    <v-data-table
      :headers="headers"
      :items="inspections"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.inspected_at="{ item }">
        {{ formatDate(item.inspected_at) }}
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
    </v-data-table>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
