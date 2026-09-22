<script setup lang="ts">
// トラブルへの対応の現場メモから、対応記録の下書きをAIアシスタント「プラナ」に作ってもらう（要求仕様書 2.5.2）。
// プラナは提案までで、入力欄に入れるのは「反映」を押したときだけ（保存は対応記録を記録したとき）。
// AIが使えない・失敗したときも、下の入力欄はそのまま使える
import { ref, watch } from 'vue'
import api from '@/api/axios'
import PlanaNote from '@/components/plana/PlanaNote.vue'
import type { AiResponseDraft, AiStatus } from '@/types/models'
import { latestGuard } from '@/utils/latestGuard'

const props = defineProps<{
  status: AiStatus
  troubleId: number
  // 入力欄にすでに対応内容があるとき（反映で置き換わるため、確認する）
  hasExisting: boolean
}>()
const emit = defineEmits<{
  apply: [draft: AiResponseDraft]
  remaining: [count: number]
}>()

const RESPONSE_TYPE_LABEL: Record<string, string> = { investigation: '調査', repair: '修理', replacement: '交換', observation: '経過観察' }

const memo = ref('')
const loading = ref(false)
const draft = ref<AiResponseDraft | null>(null)
const error = ref('')

// 下書きを作っている間に、別のトラブルの詳細に変わる（同じ画面が使い回される）ことがある。
// 古い呼び出しの応答は、あとから返っても反映しない
const guard = latestGuard()

// 下書きは、そのトラブルについてのもの。トラブルが変わったら消す
watch(() => props.troubleId, () => {
  guard()
  draft.value = null
  error.value = ''
  loading.value = false
})

async function generate() {
  const isLatest = guard()
  loading.value = true
  error.value = ''
  draft.value = null
  try {
    const res = await api.post('/ai/response_drafts', { trouble_id: props.troubleId, memo: memo.value })
    // 残り回数は、古い呼び出しでも合わせる（回数は使っているため）
    emit('remaining', res.data.data.remaining_today)
    if (!isLatest()) return
    draft.value = res.data.data
  } catch (e: any) {
    // 失敗・上限も回数に数えるため、画面の残り回数を実際に合わせる
    const left = e.response?.data?.remaining_today
    if (typeof left === 'number') emit('remaining', left)
    if (!isLatest()) return
    error.value = e.response?.data?.errors?.[0] || '下書きを取得できませんでした。対応記録は直接入力できます'
  } finally {
    if (isLatest()) loading.value = false
  }
}

function apply() {
  if (!draft.value) return
  // 断ったときは、下書きを残す（押し直せるように）
  if (props.hasExisting && !confirm('入力済みの対応内容を、下書きで置き換えます。よろしいですか？')) return
  emit('apply', draft.value)
  draft.value = null
}
</script>

<template>
  <div class="mb-3" data-testid="ai-response-assist">
    <v-textarea
      v-model="memo"
      label="対応メモ"
      placeholder="例: 導圧管のつまりを除去。伝送器を交換した。"
      rows="2"
      auto-grow
      density="compact"
      :counter="status.max_memo_length"
      :maxlength="status.max_memo_length"
      hide-details="auto"
      data-testid="ai-response-memo"
    />
    <div class="d-flex align-center ga-3 mt-1">
      <v-btn
        size="small"
        variant="tonal"
        color="primary"
        :loading="loading"
        :disabled="!memo.trim() || status.remaining_today <= 0"
        data-testid="ai-response-button"
        @click="generate"
      >
        下書きを作る
      </v-btn>
      <span class="text-caption text-medium-emphasis">今日の残り {{ status.remaining_today }} / {{ status.daily_limit }} 回</span>
    </div>

    <v-alert v-if="error" type="warning" variant="tonal" density="compact" class="mt-2" data-testid="ai-response-error">{{ error }}</v-alert>

    <v-card v-if="draft" variant="outlined" color="primary" class="mt-2" data-testid="ai-response-draft">
      <v-card-text class="text-body-2">
        <PlanaNote>プラナの下書きです。内容を確認して、必要なら直してください（反映するまで入力欄は変わりません）。</PlanaNote>
        <div>
          <span class="text-medium-emphasis">対応種別:</span>
          <template v-if="draft.response_type">{{ RESPONSE_TYPE_LABEL[draft.response_type] }}</template>
          <template v-else>提案なし（入力欄の値のまま）</template>
        </div>
        <div style="white-space: pre-wrap"><span class="text-medium-emphasis">対応内容:</span> {{ draft.description }}</div>
        <div v-if="draft.used_materials"><span class="text-medium-emphasis">使用資材:</span> {{ draft.used_materials }}</div>
        <div v-if="draft.check_points.length" class="mt-2">
          <div class="text-medium-emphasis">記録に足すと役立つかもしれない点（反映されません）</div>
          <ul class="ml-5"><li v-for="c in draft.check_points" :key="c">{{ c }}</li></ul>
        </div>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn size="small" variant="text" @click="draft = null">破棄</v-btn>
        <v-btn size="small" color="primary" variant="flat" data-testid="ai-response-apply" @click="apply">入力欄に反映</v-btn>
      </v-card-actions>
    </v-card>
  </div>
</template>
