<script setup lang="ts">
import { ref, watch } from 'vue'
import api from '@/api/axios'
import type { Inspection } from '@/types/models'
import { equipmentNames } from '@/utils/equipment'
import { inspectionName } from '@/utils/inspectionWorkflow'
import { latestGuard } from '@/utils/latestGuard'

const props = defineProps<{
  siteIds?: number[]
  planId?: number | null
  taskId?: number | null
  returnTo: string
}>()
const emit = defineEmits<{ loaded: [count: number] }>()
const drafts = ref<Inspection[]>([])
const loading = ref(true)
const error = ref(false)
const total = ref(0)
const page = ref(1)
const guard = latestGuard()
async function load() {
  const isLatest = guard()
  loading.value = true
  error.value = false
  try {
    const response = await api.get('/inspections', { params: {
      mine: true, status: 'draft', site_ids: props.siteIds,
      inspection_plan_id: props.planId || undefined, maintenance_task_id: props.taskId || undefined,
      page: page.value, per_page: 5,
    } })
    if (!isLatest()) return
    drafts.value = response.data.data
    total.value = response.data.meta.total_count
    emit('loaded', total.value)
  } catch {
    if (isLatest()) error.value = true
  } finally {
    if (isLatest()) loading.value = false
  }
}
watch(() => [props.siteIds, props.planId, props.taskId], () => { page.value = 1; void load() }, { immediate: true, deep: true })
function changePage(value: number) { page.value = value; void load() }
function dateLabel(value: string) {
  return new Date(value).toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo', year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <section class="pk-drafts pk-no-print" aria-label="自分の下書き" data-testid="inspection-drafts" :aria-busy="loading">
    <h2>自分の下書き <small v-if="!loading && !error">{{ total }}件</small></h2>
    <p class="text-body-2 text-medium-emphasis">{{ planId || taskId ? 'この予定で途中まで記入した点検です。再開する記録を選んでください。' : '前日以前の記録も含め、途中から再開できます。' }}</p>
    <p v-if="loading" role="status" class="mt-2">下書きを確認しています…</p>
    <div v-else-if="error" class="mt-2">
      <p role="alert">下書きを読み込めませんでした。</p>
      <v-btn variant="outlined" class="mt-2" @click="load">下書きを再確認</v-btn>
    </div>
    <template v-else>
      <ul v-if="drafts.length" class="pk-drafts__list">
        <li v-for="draft in drafts" :key="draft.id" :data-testid="`inspection-draft-${draft.id}`">
          <div>
            <strong>{{ inspectionName(draft) }}</strong>
            <p>{{ equipmentNames(draft) }}<template v-if="draft.instrument"> ／ {{ draft.instrument.tag_number }}</template></p>
            <p>点検日時 {{ dateLabel(draft.inspected_at) }} ／ 記録 #{{ draft.id }}</p>
          </div>
          <v-btn variant="outlined" color="primary" :to="{ path: `/inspections/${draft.id}/edit`, query: { return_to: returnTo } }" :aria-label="`${inspectionName(draft)}（記録 #${draft.id}）の入力を再開`">入力を再開</v-btn>
        </li>
      </ul>
      <p v-else class="mt-2 text-body-2">自分の下書きはありません。</p>
      <v-pagination v-if="total > 5" :model-value="page" :length="Math.ceil(total / 5)" :total-visible="3" aria-label="下書きのページ" @update:model-value="changePage" />
    </template>
  </section>
</template>

<style scoped>
.pk-drafts { border: 1px solid var(--pk-line); border-radius: 12px; background: white; padding: 16px; margin-bottom: 16px; }
h2 { font-size: 1.0625rem; margin-bottom: 4px; }
small { font-weight: 400; color: var(--pk-muted); }
.pk-drafts__list { list-style: none; padding: 0; }
li { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 12px 0; border-bottom: 1px solid var(--pk-line); }
li > div { min-width: 0; overflow-wrap: anywhere; }
li p { font-size: .8125rem; color: var(--pk-muted); }
li .v-btn { flex-shrink: 0; }
@media (max-width: 600px) { li { flex-wrap: wrap; } }
</style>
