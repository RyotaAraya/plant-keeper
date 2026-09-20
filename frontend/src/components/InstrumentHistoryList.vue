<script setup lang="ts">
// 計器の履歴（トラブル・点検）。計器詳細と、トラブル詳細の「この計器の履歴」で使う。
// 新しい順に数件を出し、行から詳細へ、「すべて見る」から、その計器で絞り込んだ一覧へ移れる
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import { latestGuard } from '@/utils/latestGuard'
import { siteIdsToQuery } from '@/utils/listQuery'

const props = withDefaults(
  defineProps<{
    kind: 'troubles' | 'inspections'
    instrumentId: number
    // トラブルの詳細から開くとき、そのトラブル自身（履歴から外す。この計器のトラブルであること）
    excludeTroubleId?: number
    limit?: number
  }>(),
  { excludeTroubleId: undefined, limit: 5 },
)

const router = useRouter()

const troubleStatusLabel: Record<string, string> = { open: '未対応', in_progress: '対応中', deferred: '定修待ち', resolved: '解決済', closed: '完了' }
const troubleStatusColor: Record<string, string> = { open: 'error', in_progress: 'warning', deferred: 'deep-purple', resolved: 'info', closed: 'success' }
const priorityLabel: Record<string, string> = { low: '低', medium: '中', high: '高', critical: '緊急' }
const priorityColor: Record<string, string> = { low: 'success', medium: 'info', high: 'warning', critical: 'error' }
const inspectionTypeLabel: Record<string, string> = { routine: '日常点検', periodic: '定期点検', telemetry: 'テレメトリ', operation_check: '運転チェック' }
const inspectionStatusLabel: Record<string, string> = { draft: '下書き', submitted: '提出済', approval_requested: '承認待ち', approved: '承認済' }
const inspectionStatusColor: Record<string, string> = { draft: 'grey', submitted: 'info', approval_requested: 'warning', approved: 'success' }

const items = ref<any[]>([])
const total = ref(0)
const loading = ref(false)
const failed = ref(false)
const guard = latestGuard()

async function load() {
  const isLatest = guard()
  loading.value = true
  failed.value = false
  try {
    const exclude = props.kind === 'troubles' ? props.excludeTroubleId : undefined
    // 自分自身を外すため、1件多く取る
    const res = await api.get(`/${props.kind}`, { params: { instrument_id: props.instrumentId, per_page: props.limit + (exclude ? 1 : 0) } })
    if (!isLatest()) return
    items.value = res.data.data.filter((r: any) => r.id !== exclude).slice(0, props.limit)
    total.value = res.data.meta.total_count - (exclude ? 1 : 0)
  } catch {
    // 履歴が取れなくても、画面のほかの操作には影響しない
    if (isLatest()) failed.value = true
  } finally {
    if (isLatest()) loading.value = false
  }
}

const formatDate = (dt: string) => (dt ? new Date(dt).toLocaleDateString('ja-JP') : '')
const detailPath = (id: number) => `/${props.kind}/${id}`

// その計器で絞り込んだ一覧へ。ほかの拠点の計器でも見えるよう、全拠点にする
function openAll() {
  router.push({ path: `/${props.kind}`, query: { instrument_id: String(props.instrumentId), site_ids: siteIdsToQuery([]) } })
}

watch(() => [props.kind, props.instrumentId, props.excludeTroubleId], load, { immediate: true })
</script>

<template>
  <div :data-testid="`instrument-history-${kind}`">
    <v-progress-linear v-if="loading" indeterminate />
    <p v-else-if="failed" class="text-body-2 text-medium-emphasis">履歴を取得できませんでした。</p>
    <template v-else>
      <v-list v-if="items.length" density="compact" class="pa-0">
        <v-list-item v-for="r in items" :key="r.id" :to="detailPath(r.id)" data-testid="instrument-history-row">
          <template v-if="kind === 'troubles'">
            <v-list-item-title>{{ r.title }}</v-list-item-title>
            <v-list-item-subtitle>{{ formatDate(r.reported_at) }}</v-list-item-subtitle>
          </template>
          <template v-else>
            <v-list-item-title>{{ inspectionTypeLabel[r.inspection_type] ?? r.inspection_type }}</v-list-item-title>
            <v-list-item-subtitle>{{ formatDate(r.inspected_at) }}<template v-if="r.checklist_template"> / {{ r.checklist_template.name }}</template></v-list-item-subtitle>
          </template>
          <template #append>
            <template v-if="kind === 'troubles'">
              <v-chip :color="priorityColor[r.priority]" size="x-small" class="mr-1">{{ priorityLabel[r.priority] ?? r.priority }}</v-chip>
              <v-chip :color="troubleStatusColor[r.status]" size="x-small">{{ troubleStatusLabel[r.status] ?? r.status }}</v-chip>
            </template>
            <v-chip v-else :color="inspectionStatusColor[r.status]" size="x-small">{{ inspectionStatusLabel[r.status] ?? r.status }}</v-chip>
          </template>
        </v-list-item>
      </v-list>
      <p v-else class="text-body-2 text-medium-emphasis">{{ kind === 'troubles' ? 'トラブル履歴なし' : '点検履歴なし' }}</p>
      <v-btn v-if="total > 0" variant="text" size="small" color="primary" data-testid="instrument-history-all" @click="openAll">すべて見る（{{ total }}件）</v-btn>
    </template>
  </div>
</template>
