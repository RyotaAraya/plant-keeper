<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import FilterSelect from '@/components/FilterSelect.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { useAuthStore } from '@/stores/auth'
import { listFromQuery, siteIdsFromQuery } from '@/utils/listQuery'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const inspections = ref<any[]>([])
const { equipments, departments, load: loadSiteOptions } = useSiteScopeOptions()
const loading = ref(false)
const totalCount = ref(0)

// 通常業務では自拠点の記録だけ見ればよいため、自分の所属拠点を初期値にする（部署は絞らず、拠点全体を見る）
// ダッシュボードから来たときは、その拠点・ステータスで絞り込んだ状態で開く
const filters = ref({
  site_ids: siteIdsFromQuery(route.query.site_ids, (authStore.user?.site_id ? [authStore.user.site_id] : []) as number[]),
  equipment_ids: [] as number[],
  department_id: null as number | null,
  inspection_types: [] as string[],
  statuses: listFromQuery(route.query.status),
})

const headers = [
  { title: '点検日時', key: 'inspected_at', width: '160px' },
  { title: '種別', key: 'inspection_type', width: '110px' },
  { title: '設備', key: 'equipment.name' },
  { title: '計器', key: 'instrument.tag_number', width: '110px' },
  { title: '実施者', key: 'user.name', width: '120px' },
  { title: '部署', key: 'department.name', width: '140px' },
  { title: 'ステータス', key: 'status', width: '120px' },
]

const inspectionTypeLabel: Record<string, string> = {
  routine: '日常点検', periodic: '定期点検', telemetry: 'テレメトリ', operation_check: '運転チェック'
}

const statusLabel: Record<string, string> = {
  draft: '下書き', submitted: '提出済', approval_requested: '承認待ち', approved: '承認済'
}

const statusColor: Record<string, string> = {
  draft: 'grey', submitted: 'info', approval_requested: 'warning', approved: 'success'
}

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
  const shown = (id: number) => siteIds.length === 0 || siteIds.includes(id)
  const keepEquipment = filters.value.equipment_ids.filter((id) => equipments.value.find((e) => e.id === id && shown(e.site_id)))
  const keepDepartment = departments.value.find((d) => d.id === filters.value.department_id && shown(d.site_id))
  filters.value = { ...filters.value, site_ids: siteIds, equipment_ids: keepEquipment, department_id: keepDepartment ? keepDepartment.id : null }
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
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">点検・作業記録</h1>
      <v-spacer />
      <v-btn color="primary" prepend-icon="mdi-plus" @click="router.push('/inspections/new')">新規点検</v-btn>
    </div>

    <div class="d-flex ga-4 mb-4 flex-wrap align-center">
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
      <template #item.inspection_type="{ item }">
        {{ inspectionTypeLabel[item.inspection_type] || item.inspection_type }}
      </template>
      <template #item.status="{ item }">
        <v-chip :color="statusColor[item.status]" size="small">
          {{ statusLabel[item.status] || item.status }}
        </v-chip>
      </template>
    </v-data-table>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
