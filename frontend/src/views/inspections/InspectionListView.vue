<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const router = useRouter()

const inspections = ref<any[]>([])
const equipments = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)

const filters = ref({
  equipment_id: null as number | null,
  inspection_type: null as string | null,
  status: null as string | null,
})

const headers = [
  { title: '点検日時', key: 'inspected_at', width: '160px' },
  { title: '種別', key: 'inspection_type', width: '110px' },
  { title: '設備', key: 'equipment.name' },
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

async function fetchInspections() {
  loading.value = true
  try {
    const params: any = { page: page.value, per_page: 25 }
    if (filters.value.equipment_id) params.equipment_id = filters.value.equipment_id
    if (filters.value.inspection_type) params.inspection_type = filters.value.inspection_type
    if (filters.value.status) params.status = filters.value.status

    const res = await api.get('/inspections', { params })
    inspections.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

async function fetchEquipments() {
  const res = await api.get('/equipments', { params: { per_page: 100 } })
  equipments.value = res.data.data
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function goToDetail(row: any) {
  router.push(`/inspections/${row.id}`)
}

onMounted(() => {
  fetchEquipments()
  fetchInspections()
})
watch([filters, page], fetchInspections, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">点検・作業記録</h1>
      <v-spacer />
      <v-btn color="primary" prepend-icon="mdi-plus" @click="router.push('/inspections/new')">新規点検</v-btn>
    </div>

    <div class="d-flex ga-4 mb-4">
      <v-select
        v-model="filters.equipment_id"
        :items="equipments"
        item-title="name"
        item-value="id"
        label="設備"
        clearable
        density="compact"
        hide-details
        style="max-width: 220px"
      />
      <v-select
        v-model="filters.inspection_type"
        :items="inspectionTypeOptions"
        item-title="title"
        item-value="value"
        label="種別"
        clearable
        density="compact"
        hide-details
        style="max-width: 160px"
      />
      <v-select
        v-model="filters.status"
        :items="statusOptions"
        item-title="title"
        item-value="value"
        label="ステータス"
        clearable
        density="compact"
        hide-details
        style="max-width: 160px"
      />
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

    <div v-if="totalCount > 25" class="d-flex justify-center mt-4">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / 25)" />
    </div>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
