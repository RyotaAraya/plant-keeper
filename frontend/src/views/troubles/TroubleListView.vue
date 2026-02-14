<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const router = useRouter()

const troubles = ref<any[]>([])
const equipments = ref<any[]>([])
const users = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)
const dialog = ref(false)
const errors = ref<string[]>([])

const filters = ref({
  status: null as string | null,
  priority: null as string | null,
  equipment_id: null as number | null,
  q: '',
})

const form = ref({
  equipment_id: null as number | null,
  instrument_id: null as number | null,
  title: '',
  description: '',
  priority: 'medium',
  reported_at: new Date().toISOString().slice(0, 16),
})

const instruments = ref<any[]>([])

const headers = [
  { title: '報告日', key: 'reported_at', width: '130px' },
  { title: '優先度', key: 'priority', width: '80px' },
  { title: 'タイトル', key: 'title' },
  { title: '設備', key: 'equipment.name', width: '150px' },
  { title: '計器', key: 'instrument.tag_number', width: '120px' },
  { title: '担当者', key: 'assigned_to.name', width: '100px' },
  { title: 'ステータス', key: 'status', width: '110px' },
]

const statusLabel: Record<string, string> = {
  open: '未対応', in_progress: '対応中', resolved: '解決済', closed: '完了'
}
const statusColor: Record<string, string> = {
  open: 'error', in_progress: 'warning', resolved: 'info', closed: 'success'
}
const priorityLabel: Record<string, string> = {
  low: '低', medium: '中', high: '高', critical: '緊急'
}
const priorityColor: Record<string, string> = {
  low: 'success', medium: 'info', high: 'warning', critical: 'error'
}

const statusOptions = [
  { title: '未対応', value: 'open' },
  { title: '対応中', value: 'in_progress' },
  { title: '解決済', value: 'resolved' },
  { title: '完了', value: 'closed' },
]
const priorityOptions = [
  { title: '低', value: 'low' },
  { title: '中', value: 'medium' },
  { title: '高', value: 'high' },
  { title: '緊急', value: 'critical' },
]

async function fetchTroubles() {
  loading.value = true
  try {
    const params: any = { page: page.value, per_page: 25 }
    if (filters.value.status) params.status = filters.value.status
    if (filters.value.priority) params.priority = filters.value.priority
    if (filters.value.equipment_id) params.equipment_id = filters.value.equipment_id
    if (filters.value.q) params.q = filters.value.q
    const res = await api.get('/troubles', { params })
    troubles.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

async function fetchEquipments() {
  const res = await api.get('/equipments', { params: { per_page: 100 } })
  equipments.value = res.data.data
}

async function fetchInstruments() {
  if (!form.value.equipment_id) { instruments.value = []; return }
  const res = await api.get('/instruments', { params: { equipment_id: form.value.equipment_id, per_page: 100 } })
  instruments.value = res.data.data
}

function openCreate() {
  form.value = {
    equipment_id: null,
    instrument_id: null,
    title: '',
    description: '',
    priority: 'medium',
    reported_at: new Date().toISOString().slice(0, 16),
  }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    await api.post('/troubles', { trouble: form.value })
    dialog.value = false
    await fetchTroubles()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleDateString('ja-JP')
}

function goToDetail(row: any) {
  router.push(`/troubles/${row.id}`)
}

onMounted(() => {
  fetchEquipments()
  fetchTroubles()
})
watch([filters, page], fetchTroubles, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">トラブル管理</h1>
      <v-spacer />
      <v-btn color="primary" prepend-icon="mdi-plus" @click="openCreate">新規報告</v-btn>
    </div>

    <div class="d-flex ga-4 mb-4 flex-wrap">
      <v-text-field
        v-model="filters.q"
        label="タイトル検索"
        prepend-inner-icon="mdi-magnify"
        clearable
        density="compact"
        hide-details
        style="max-width: 220px"
      />
      <v-select
        v-model="filters.equipment_id"
        :items="equipments"
        item-title="name"
        item-value="id"
        label="設備"
        clearable
        density="compact"
        hide-details
        style="max-width: 200px"
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
        style="max-width: 140px"
      />
      <v-select
        v-model="filters.priority"
        :items="priorityOptions"
        item-title="title"
        item-value="value"
        label="優先度"
        clearable
        density="compact"
        hide-details
        style="max-width: 120px"
      />
    </div>

    <v-data-table
      :headers="headers"
      :items="troubles"
      :loading="loading"
      hover
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
      class="cursor-pointer"
    >
      <template #item.reported_at="{ item }">
        {{ formatDate(item.reported_at) }}
      </template>
      <template #item.priority="{ item }">
        <v-chip :color="priorityColor[item.priority]" size="x-small">
          {{ priorityLabel[item.priority] }}
        </v-chip>
      </template>
      <template #item.status="{ item }">
        <v-chip :color="statusColor[item.status]" size="small">
          {{ statusLabel[item.status] }}
        </v-chip>
      </template>
      <template #item.instrument.tag_number="{ item }">
        {{ item.instrument?.tag_number || '—' }}
      </template>
      <template #item.assigned_to.name="{ item }">
        {{ item.assigned_to?.name || '未割当' }}
      </template>
    </v-data-table>

    <div class="d-flex justify-center mt-4" v-if="totalCount > 25">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / 25)" />
    </div>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>トラブル報告</v-card-title>
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
            @update:model-value="fetchInstruments"
          />
          <v-select
            v-model="form.instrument_id"
            :items="instruments"
            item-title="tag_number"
            item-value="id"
            label="計器"
            clearable
            class="mb-2"
          />
          <v-select
            v-model="form.priority"
            :items="priorityOptions"
            item-title="title"
            item-value="value"
            label="優先度"
            class="mb-2"
          />
          <v-text-field v-model="form.reported_at" label="報告日時" type="datetime-local" class="mb-2" />
          <v-textarea v-model="form.description" label="詳細説明" rows="3" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="save">報告</v-btn>
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
