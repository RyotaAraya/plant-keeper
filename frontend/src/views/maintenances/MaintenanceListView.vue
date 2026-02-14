<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const router = useRouter()

const maintenances = ref<any[]>([])
const equipments = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)
const dialog = ref(false)
const errors = ref<string[]>([])

const filters = ref({
  equipment_id: null as number | null,
  status: null as string | null,
})

const form = ref({
  equipment_id: null as number | null,
  title: '',
  description: '',
  scheduled_date: '',
  status: 'planned',
})

const headers = [
  { title: '予定日', key: 'scheduled_date', width: '120px' },
  { title: 'タイトル', key: 'title' },
  { title: '設備', key: 'equipment.name', width: '180px' },
  { title: '担当者', key: 'assignees', width: '180px' },
  { title: 'ステータス', key: 'status', width: '110px' },
]

const statusLabel: Record<string, string> = {
  planned: '計画中', in_progress: '実施中', completed: '完了'
}
const statusColor: Record<string, string> = {
  planned: 'info', in_progress: 'warning', completed: 'success'
}

const statusOptions = [
  { title: '計画中', value: 'planned' },
  { title: '実施中', value: 'in_progress' },
  { title: '完了', value: 'completed' },
]

async function fetchMaintenances() {
  loading.value = true
  try {
    const params: any = { page: page.value, per_page: 25 }
    if (filters.value.equipment_id) params.equipment_id = filters.value.equipment_id
    if (filters.value.status) params.status = filters.value.status
    const res = await api.get('/scheduled_maintenances', { params })
    maintenances.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

async function fetchEquipments() {
  const res = await api.get('/equipments', { params: { per_page: 100 } })
  equipments.value = res.data.data
}

function getAssignees(item: any) {
  return (item.maintenance_assignments || [])
    .map((a: any) => `${a.user?.name || ''}${a.role === 'lead' ? '(主)' : ''}`)
    .join(', ')
}

function openCreate() {
  form.value = {
    equipment_id: null,
    title: '',
    description: '',
    scheduled_date: '',
    status: 'planned',
  }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    await api.post('/scheduled_maintenances', { scheduled_maintenance: form.value })
    dialog.value = false
    await fetchMaintenances()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleDateString('ja-JP')
}

function goToDetail(row: any) {
  router.push(`/maintenances/${row.id}`)
}

onMounted(() => {
  fetchEquipments()
  fetchMaintenances()
})
watch([filters, page], fetchMaintenances, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">定期整備</h1>
      <v-spacer />
      <v-btn color="primary" prepend-icon="mdi-plus" @click="openCreate">新規作成</v-btn>
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
      :items="maintenances"
      :loading="loading"
      hover
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
      class="cursor-pointer"
    >
      <template #item.scheduled_date="{ item }">
        {{ formatDate(item.scheduled_date) }}
      </template>
      <template #item.assignees="{ item }">
        {{ getAssignees(item) || '未割当' }}
      </template>
      <template #item.status="{ item }">
        <v-chip :color="statusColor[item.status]" size="small">
          {{ statusLabel[item.status] }}
        </v-chip>
      </template>
    </v-data-table>

    <div class="d-flex justify-center mt-4" v-if="totalCount > 25">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / 25)" />
    </div>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>定期整備作成</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="form.title" label="タイトル *" class="mb-2" />
          <v-select
            v-model="form.equipment_id"
            :items="equipments"
            item-title="name"
            item-value="id"
            label="設備 *"
            class="mb-2"
          />
          <v-text-field v-model="form.scheduled_date" label="予定日 *" type="date" class="mb-2" />
          <v-textarea v-model="form.description" label="説明" rows="3" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="save">作成</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
