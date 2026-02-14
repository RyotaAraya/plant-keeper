<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const logs = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)

const filters = ref({
  action: null as string | null,
  auditable_type: null as string | null,
})

const headers = [
  { title: '日時', key: 'performed_at', width: '160px' },
  { title: 'ユーザ', key: 'user.name', width: '120px' },
  { title: '操作', key: 'action', width: '120px' },
  { title: '対象', key: 'auditable_type', width: '140px' },
  { title: '対象ID', key: 'auditable_id', width: '80px' },
  { title: '変更内容', key: 'changes_json' },
  { title: 'IP', key: 'ip_address', width: '130px' },
]

const actionLabel: Record<string, string> = {
  create: '作成', update: '更新', delete: '削除', login: 'ログイン', logout: 'ログアウト', approval_request: '承認依頼'
}
const actionOptions = [
  { title: '作成', value: 'create' },
  { title: '更新', value: 'update' },
  { title: '削除', value: 'delete' },
  { title: 'ログイン', value: 'login' },
  { title: 'ログアウト', value: 'logout' },
  { title: '承認依頼', value: 'approval_request' },
]

const typeOptions = [
  { title: 'User', value: 'User' },
  { title: 'Equipment', value: 'Equipment' },
  { title: 'Instrument', value: 'Instrument' },
  { title: 'Inspection', value: 'Inspection' },
  { title: 'Trouble', value: 'Trouble' },
  { title: 'Material', value: 'Material' },
  { title: 'Order', value: 'Order' },
]

async function fetchLogs() {
  loading.value = true
  try {
    const params: any = { page: page.value, per_page: 50 }
    if (filters.value.action) params.action = filters.value.action
    if (filters.value.auditable_type) params.auditable_type = filters.value.auditable_type
    const res = await api.get('/audit_logs', { params })
    logs.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

function formatChanges(changes: any) {
  if (!changes || typeof changes !== 'object') return ''
  return JSON.stringify(changes, null, 0).slice(0, 100)
}

onMounted(fetchLogs)
watch([filters, page], fetchLogs, { deep: true })
</script>

<template>
  <MainLayout>
    <h1 class="text-h5 mb-4">監査ログ</h1>

    <div class="d-flex ga-4 mb-4">
      <v-select
        v-model="filters.action"
        :items="actionOptions"
        item-title="title"
        item-value="value"
        label="操作"
        clearable
        density="compact"
        hide-details
        style="max-width: 160px"
      />
      <v-select
        v-model="filters.auditable_type"
        :items="typeOptions"
        item-title="title"
        item-value="value"
        label="対象モデル"
        clearable
        density="compact"
        hide-details
        style="max-width: 180px"
      />
    </div>

    <v-data-table
      :headers="headers"
      :items="logs"
      :loading="loading"
      density="compact"
    >
      <template #item.performed_at="{ item }">
        {{ formatDate(item.performed_at) }}
      </template>
      <template #item.action="{ item }">
        {{ actionLabel[item.action] || item.action }}
      </template>
      <template #item.changes_json="{ item }">
        <span class="text-caption">{{ formatChanges(item.changes_json) }}</span>
      </template>
    </v-data-table>

    <div class="d-flex justify-center mt-4" v-if="totalCount > 50">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / 50)" />
    </div>
  </MainLayout>
</template>
