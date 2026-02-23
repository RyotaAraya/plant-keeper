<script setup lang="ts">
import { ref, watch, onMounted } from 'vue'
import api from '@/api/axios'

const props = defineProps<{
  auditableType: string
  auditableId: number | string | null | undefined
}>()

const logs = ref<any[]>([])
const loading = ref(false)

const actionLabel: Record<string, string> = {
  create: '作成', update: '更新', delete: '削除',
}
const actionColor: Record<string, string> = {
  create: 'success', update: 'info', delete: 'error',
}

function parseChanges(changes: any): { key: string; from: string; to: string }[] {
  if (!changes || typeof changes !== 'object') return []
  return Object.entries(changes)
    .filter(([k]) => !['id', 'created_at', 'updated_at'].includes(k))
    .map(([k, v]) => {
      const arr = Array.isArray(v) ? v : [null, v]
      return { key: k, from: arr[0] != null ? String(arr[0]) : '—', to: arr[1] != null ? String(arr[1]) : '—' }
    })
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit',
  })
}

async function fetchHistory() {
  if (!props.auditableId) return
  loading.value = true
  try {
    const res = await api.get('/audit_logs', {
      params: { auditable_type: props.auditableType, auditable_id: props.auditableId, per_page: 30 },
    })
    logs.value = res.data.data
  } finally {
    loading.value = false
  }
}

onMounted(fetchHistory)
watch(() => props.auditableId, fetchHistory)
</script>

<template>
  <div>
    <v-progress-linear v-if="loading" indeterminate />
    <v-timeline v-else-if="logs.length" density="compact" side="end">
      <v-timeline-item
        v-for="log in logs"
        :key="log.id"
        :dot-color="actionColor[log.action] || 'grey'"
        size="x-small"
      >
        <div class="d-flex align-center mb-1 flex-wrap ga-1">
          <v-chip size="x-small" :color="actionColor[log.action] || 'grey'">
            {{ actionLabel[log.action] || log.action }}
          </v-chip>
          <span class="text-body-2">{{ log.user?.name }}</span>
          <span class="text-caption text-grey ml-auto">{{ formatDate(log.performed_at) }}</span>
        </div>
        <div v-if="parseChanges(log.changes_json).length" class="text-caption">
          <div v-for="c in parseChanges(log.changes_json)" :key="c.key">
            <span class="text-grey mr-1">{{ c.key }}:</span>
            <span class="text-error">{{ c.from }}</span>
            <v-icon size="x-small" class="mx-1">mdi-arrow-right</v-icon>
            <span class="text-success">{{ c.to }}</span>
          </div>
        </div>
      </v-timeline-item>
    </v-timeline>
    <div v-else class="text-center text-grey py-4">変更履歴なし</div>
  </div>
</template>
