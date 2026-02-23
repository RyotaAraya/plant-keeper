<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const logs = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)
const apiError = ref<string | null>(null)

const filters = ref({
  action: null as string | null,
  auditable_type: null as string | null,
})

const headers = [
  { title: '日時', key: 'performed_at', width: '160px' },
  { title: 'ユーザ', key: 'user.name', width: '130px' },
  { title: '操作', key: 'action', width: '90px' },
  { title: '対象', key: 'auditable_type', width: '120px' },
  { title: '対象ID', key: 'auditable_id', width: '80px' },
  { title: '変更内容', key: 'changes_json' },
  { title: 'IP', key: 'ip_address', width: '130px' },
]

const actionLabel: Record<string, string> = {
  create: '作成', update: '更新', delete: '削除', login: 'ログイン', logout: 'ログアウト', approval_request: '承認依頼'
}
const actionColor: Record<string, string> = {
  create: 'success', update: 'info', delete: 'error', login: 'grey', logout: 'grey', approval_request: 'warning'
}
const actionOptions = [
  { title: '作成', value: 'create' },
  { title: '更新', value: 'update' },
  { title: '削除', value: 'delete' },
  { title: 'ログイン', value: 'login' },
  { title: 'ログアウト', value: 'logout' },
  { title: '承認依頼', value: 'approval_request' },
]

const typeLabel: Record<string, string> = {
  Site: '拠点', Equipment: '設備', Instrument: '計器', Inspection: '点検',
  Trouble: 'トラブル', Material: '資材', Order: '発注', User: 'ユーザ',
  ScheduledMaintenance: '定期整備', Repair: '修理',
}
const typeOptions = [
  { title: '拠点 (Site)', value: 'Site' },
  { title: '設備 (Equipment)', value: 'Equipment' },
  { title: '計器 (Instrument)', value: 'Instrument' },
  { title: '点検 (Inspection)', value: 'Inspection' },
  { title: 'トラブル (Trouble)', value: 'Trouble' },
  { title: '定期整備 (ScheduledMaintenance)', value: 'ScheduledMaintenance' },
  { title: '資材 (Material)', value: 'Material' },
  { title: '発注 (Order)', value: 'Order' },
  { title: 'ユーザ (User)', value: 'User' },
]

async function fetchLogs() {
  loading.value = true
  apiError.value = null
  try {
    const params: any = { page: page.value, per_page: 50 }
    if (filters.value.action) params.log_action = filters.value.action
    if (filters.value.auditable_type) params.auditable_type = filters.value.auditable_type
    const res = await api.get('/audit_logs', { params })
    logs.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } catch (e: any) {
    apiError.value = e.response?.data?.error || 'ログの取得に失敗しました'
    logs.value = []
  } finally {
    loading.value = false
  }
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

// changes_json の各エントリを "フィールド: 旧 → 新" 形式に整形
function parseChanges(changes: any): { key: string; from: string; to: string }[] {
  if (!changes || typeof changes !== 'object') return []
  return Object.entries(changes)
    .filter(([k]) => !['id', 'created_at', 'updated_at'].includes(k))
    .map(([k, v]) => {
      const arr = Array.isArray(v) ? v : [null, v]
      return { key: k, from: arr[0] != null ? String(arr[0]) : '—', to: arr[1] != null ? String(arr[1]) : '—' }
    })
}

function hasChanges(changes: any): boolean {
  return parseChanges(changes).length > 0
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
        style="max-width: 200px"
      />
    </div>

    <v-alert v-if="apiError" type="error" density="compact" class="mb-4">{{ apiError }}</v-alert>

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
        <v-chip :color="actionColor[item.action] || 'grey'" size="x-small">
          {{ actionLabel[item.action] || item.action }}
        </v-chip>
      </template>
      <template #item.auditable_type="{ item }">
        {{ typeLabel[item.auditable_type] || item.auditable_type }}
      </template>
      <template #item.changes_json="{ item }">
        <template v-if="hasChanges(item.changes_json)">
          <div v-for="c in parseChanges(item.changes_json)" :key="c.key" class="text-caption">
            <span class="text-grey">{{ c.key }}:</span>
            <span class="text-error mx-1">{{ c.from }}</span>
            <v-icon size="x-small">mdi-arrow-right</v-icon>
            <span class="text-success ml-1">{{ c.to }}</span>
          </div>
        </template>
        <span v-else class="text-caption text-grey">—</span>
      </template>
    </v-data-table>

    <div v-if="totalCount > 50" class="d-flex justify-center mt-4">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / 50)" />
    </div>
  </MainLayout>
</template>
