<script setup lang="ts">
import { computed, ref, watch, onMounted } from 'vue'
import api from '@/api/axios'
import { formatAuditChanges } from '@/utils/auditChanges'

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

// 各ログの変更内容を、画面に出す形（日本語のラベル・値）にする。テンプレートで何度も使うので、ログごとに1回だけ求める
const logsWithChanges = computed(() =>
  logs.value.map((log) => ({ ...log, changes: formatAuditChanges(log.changes_json, props.auditableType, log.action) })),
)

// 連携からの記録の、どの連携からか（changes_json.integration_token）
function connectionName(changes: unknown) {
  const name = (changes as Record<string, unknown> | null)?.integration_token
  return typeof name === 'string' ? `連携: ${name}` : ''
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
  <div data-testid="resource-history">
    <v-progress-linear v-if="loading" indeterminate />
    <v-timeline v-else-if="logs.length" density="compact" side="end">
      <v-timeline-item
        v-for="log in logsWithChanges"
        :key="log.id"
        :dot-color="actionColor[log.action] || 'grey'"
        size="x-small"
      >
        <div class="d-flex align-center mb-1 flex-wrap ga-1">
          <v-chip size="x-small" :color="actionColor[log.action] || 'grey'">
            {{ actionLabel[log.action] || log.action }}
          </v-chip>
          <!-- ユーザのない記録は、機器管理システムなどの連携から（機器の診断から作ったトラブル） -->
          <span class="text-body-2">{{ log.user?.name ?? connectionName(log.changes_json) }}</span>
          <span class="text-caption text-grey ml-auto">{{ formatDate(log.performed_at) }}</span>
        </div>
        <div v-if="log.changes.length" class="text-caption">
          <div v-for="c in log.changes" :key="c.key">
            <span class="text-grey mr-1">{{ c.label }}:</span>
            <span v-if="c.opaque" class="text-medium-emphasis">変更あり</span>
            <template v-else>
              <span class="text-error">{{ c.from }}</span>
              <v-icon size="x-small" class="mx-1">mdi-arrow-right</v-icon>
              <span class="text-success">{{ c.to }}</span>
            </template>
          </div>
        </div>
      </v-timeline-item>
    </v-timeline>
    <div v-else class="text-center text-grey py-4">変更履歴なし</div>
  </div>
</template>
