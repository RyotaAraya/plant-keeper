<script setup lang="ts">
// 点検で見つけた不具合の現場メモから、トラブル報告の下書きをAIアシスタント「プラナ」に作ってもらう。
// プラナは提案までで、入力欄に入れるのは「反映」を押したときだけ（保存は点検を保存したとき）。
// 同じメモで、過去の類似トラブルも探せる（要求仕様書 2.5.1。こちらも表示するだけで、何も変えない）。
// AIが使えない・失敗したときも、下の入力欄はそのまま使える
import { ref, watch } from 'vue'
import api from '@/api/axios'
import SimilarTroubleList from '@/components/SimilarTroubleList.vue'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
import PlanaNote from '@/components/plana/PlanaNote.vue'
import { useSimilarTroubles } from '@/composables/useSimilarTroubles'
import type { AiDefectDraft, AiStatus } from '@/types/models'
import { latestGuard } from '@/utils/latestGuard'

const props = defineProps<{
  status: AiStatus
  equipmentId: number | null
  instrumentId: number | null
  itemLabel: string
  // 入力欄にすでにタイトルがあるとき（反映で置き換わるため、確認する）
  hasExisting: boolean
}>()
const emit = defineEmits<{
  apply: [draft: AiDefectDraft]
  remaining: [count: number]
  dirty: [value: boolean]
}>()

const PRIORITY_LABEL: Record<string, string> = { low: '低', medium: '中', high: '高', critical: '緊急' }

const similarButton = ref<{ $el: { focus(): void } } | null>(null)
function closeSimilar() {
  similar.clear()
  similarButton.value?.$el.focus()
}
const similar = useSimilarTroubles((count) => emit('remaining', count))

const memo = ref('')
const loading = ref(false)
const draft = ref<AiDefectDraft | null>(null)
const error = ref('')
watch([memo, draft, loading], () => emit('dirty', !!memo.value.trim() || !!draft.value || loading.value), { flush: 'sync' })

// 下書きを作っている間に設備・計器が変わる（clear）ことがある。古い呼び出しの応答は、あとから返っても反映しない
const guard = latestGuard()

// メモ・設備・計器が変わったら、前の入力に対する類似トラブルの結果は消す（今の入力への結果に見えないように）
watch([memo, () => props.equipmentId, () => props.instrumentId], () => similar.clear())

// 下書きは、設備・計器についてのもの。変わったら消す（別の設備の下書きを反映してしまわないように）。
// メモの手直しでは消さない（作った下書きを、回数を使ってまで作り直させないため。反映前に人が確認する）
watch([() => props.equipmentId, () => props.instrumentId], () => {
  guard()
  draft.value = null
  error.value = ''
  loading.value = false
})

function searchSimilar() {
  return similar.search({ equipmentId: props.equipmentId, instrumentId: props.instrumentId, memo: memo.value })
}

async function generate() {
  if (!props.equipmentId) {
    error.value = '先に設備を選んでください'
    return
  }
  const isLatest = guard()
  loading.value = true
  error.value = ''
  draft.value = null
  try {
    const res = await api.post('/ai/defect_drafts', {
      equipment_id: props.equipmentId,
      instrument_id: props.instrumentId,
      item_label: props.itemLabel,
      memo: memo.value,
    })
    // 残り回数は、古い呼び出しでも合わせる（回数は使っているため）
    emit('remaining', res.data.data.remaining_today)
    if (!isLatest()) return
    draft.value = res.data.data
  } catch (e: any) {
    // 失敗・上限も回数に数えるため、画面の残り回数を実際に合わせる
    const left = e.response?.data?.remaining_today
    if (typeof left === 'number') emit('remaining', left)
    if (!isLatest()) return
    error.value = e.response?.data?.errors?.[0] || 'プラナの提案を取得できませんでした。報告内容は直接入力できます'
  } finally {
    if (isLatest()) loading.value = false
  }
}

function apply() {
  if (!draft.value) return
  // 断ったときは、プラナの提案を残す（押し直せるように）
  if (props.hasExisting && !confirm('入力済みのタイトル・説明・優先度を、プラナが整理した内容で置き換えます。よろしいですか？')) return
  emit('apply', draft.value)
  draft.value = null
}
</script>

<template>
  <div class="pk-ai-assist mb-2" data-testid="ai-assist">
    <v-textarea
      v-model="memo"
      label="現場メモ"
      placeholder="例: PT-101の指示値が数秒おきに上下している。昨日から。"
      rows="2"
      auto-grow
      density="compact"
      :counter="status.max_memo_length"
      :maxlength="status.max_memo_length"
      hide-details="auto"
      data-testid="ai-memo"
    />
    <div class="d-flex align-center flex-wrap ga-3 mt-1">
      <v-btn
        size="small"
        variant="tonal"
        color="primary"
        :loading="loading"
        :disabled="!memo.trim() || status.remaining_today <= 0"
        data-testid="ai-draft-button"
        @click="generate"
      >
        <template #prepend><PlanaAvatar :size="20" /></template>
        プラナに整えてもらう
      </v-btn>
      <v-btn
        ref="similarButton"
        size="small"
        variant="tonal"
        color="primary"
        :loading="similar.loading.value"
        :disabled="!memo.trim() || status.remaining_today <= 0"
        data-testid="ai-similar-button"
        @click="searchSimilar"
      >
        <template #prepend><PlanaAvatar :size="20" /></template>
        過去の類似トラブルを探す
      </v-btn>
      <span class="text-caption text-medium-emphasis">今日の残り {{ status.remaining_today }} / {{ status.daily_limit }} 回</span>
    </div>

    <v-alert v-if="error" type="warning" variant="tonal" density="compact" class="mt-2" data-testid="ai-error">{{ error }}</v-alert>
    <v-alert v-if="similar.error.value" type="warning" variant="tonal" density="compact" class="mt-2" data-testid="ai-similar-error">{{ similar.error.value }}</v-alert>
    <SimilarTroubleList v-if="similar.result.value" :result="similar.result.value" @close="closeSimilar" />

    <v-card v-if="draft" variant="outlined" color="primary" class="mt-2 pk-ai-report" data-testid="ai-draft">
      <v-card-text class="text-body-2">
        <PlanaNote>プラナが整理しました。まだ保存されていません。内容を確認して、必要なら直してください（反映するまで入力欄は変わりません）。</PlanaNote>
        <h3 class="pk-ai-report-title" data-testid="ai-draft-title">{{ draft.title }}</h3>
        <p v-if="draft.description" class="pk-ai-report-desc">{{ draft.description }}</p>
        <div class="pk-ai-report-priority">
          優先度:
          <template v-if="draft.priority">{{ PRIORITY_LABEL[draft.priority] }}</template>
          <template v-else>提案なし（入力欄の値のまま）</template>
          <span v-if="draft.priority_reason" class="text-medium-emphasis">（{{ draft.priority_reason }}）</span>
        </div>
        <div v-if="draft.possible_causes.length || draft.check_points.length" class="pk-ai-report-grid">
          <div v-if="draft.possible_causes.length">
            <h5><v-icon size="15" aria-hidden="true">mdi-lightbulb-on-outline</v-icon>見立て</h5>
            <ul><li v-for="c in draft.possible_causes" :key="c">{{ c }}</li></ul>
          </div>
          <div v-if="draft.check_points.length">
            <h5><v-icon size="15" aria-hidden="true">mdi-help-circle-outline</v-icon>確認したい点</h5>
            <ul><li v-for="c in draft.check_points" :key="c">{{ c }}</li></ul>
          </div>
        </div>
        <p v-if="draft.possible_causes.length || draft.check_points.length" class="pk-ai-report-caption">
          <template v-if="draft.possible_causes.length">見立ては可能性であり断定ではありません。</template>
          タイトル・説明・優先度以外は反映されません。
        </p>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn size="small" variant="text" @click="draft = null">破棄</v-btn>
        <v-btn size="small" color="primary" variant="flat" data-testid="ai-apply" @click="apply">タイトル・説明・優先度を入力欄に反映</v-btn>
      </v-card-actions>
    </v-card>
  </div>
</template>

<style scoped>
/* プラナの提案：「プラナ」を名乗るのは PlanaNote の見出し1箇所だけにし、見立て・確認したい点は並べて見せる */
.pk-ai-report-title { font-size: 1.0625rem; color: var(--pk-ink); margin-bottom: 4px; }
.pk-ai-report-desc { color: var(--pk-muted); line-height: 1.8; margin-bottom: 8px; }
.pk-ai-report-priority { font-size: .875rem; color: var(--pk-muted); }
.pk-ai-report-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 14px; padding-top: 14px; border-top: 1px solid var(--pk-line); }
.pk-ai-report-grid h5 { display: flex; align-items: center; gap: 6px; font-size: .75rem; font-weight: 700; color: var(--pk-steel); margin-bottom: 6px; }
.pk-ai-report-grid ul { margin: 0; padding-left: 18px; }
.pk-ai-report-grid li { font-size: .8125rem; line-height: 1.7; color: var(--pk-muted); }
.pk-ai-report-caption { font-size: .6875rem; color: var(--pk-muted); margin-top: 12px; }
@media (max-width: 600px) {
  .pk-ai-report-grid { grid-template-columns: 1fr; gap: 12px; }
}
</style>
