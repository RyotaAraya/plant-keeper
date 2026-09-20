<script setup lang="ts">
// AIが選んだ、過去の類似トラブル。タイトル・状態などはDBの値で、「似ている点」「対応」がAIの要約。
// 元の画面（入力中の点検など）を離れないよう、トラブルは別のタブで開く
import { useRouter } from 'vue-router'
import type { AiSimilarTroubles } from '@/types/models'

defineProps<{ result: AiSimilarTroubles }>()
defineEmits<{ close: [] }>()

const router = useRouter()

const statusLabel: Record<string, string> = { open: '未対応', in_progress: '対応中', deferred: '定修待ち', resolved: '解決済', closed: '完了' }
const priorityLabel: Record<string, string> = { low: '低', medium: '中', high: '高', critical: '緊急' }

const href = (id: number) => router.resolve(`/troubles/${id}`).href
const formatDate = (dt: string) => new Date(dt).toLocaleDateString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit' })
</script>

<template>
  <v-card variant="outlined" color="primary" class="mt-2" data-testid="ai-similar-result">
    <v-card-text class="text-body-2">
      <div class="text-caption text-medium-emphasis mb-2">
        AIが選んだ候補です（過去のトラブル {{ result.candidates_count }} 件と比べました）。似ているかどうかは、開いて記録を見て判断してください。
      </div>
      <div v-if="!result.cases.length" class="text-medium-emphasis" data-testid="ai-similar-empty">
        <template v-if="result.candidates_count === 0">比べられる過去のトラブル（同じ設備・同じ種類の計器）がありません。</template>
        <template v-else>似ているトラブルは見つかりませんでした。</template>
      </div>
      <div v-for="c in result.cases" :key="c.trouble_id" class="mb-3" data-testid="ai-similar-case">
        <div class="d-flex align-center ga-2 flex-wrap">
          <a :href="href(c.trouble_id)" target="_blank" rel="noopener" class="text-primary font-weight-bold">{{ c.title }}</a>
          <v-chip size="x-small" label variant="tonal">{{ statusLabel[c.status] ?? c.status }}</v-chip>
          <v-chip size="x-small" label variant="tonal">優先度 {{ priorityLabel[c.priority] ?? c.priority }}</v-chip>
        </div>
        <div class="text-caption text-medium-emphasis">
          {{ c.equipment_name }}<template v-if="c.instrument_tag"> / {{ c.instrument_tag }}</template> / {{ formatDate(c.reported_at) }}
        </div>
        <div><span class="text-medium-emphasis">似ている点:</span> {{ c.similarity }}</div>
        <div v-if="c.how_handled"><span class="text-medium-emphasis">過去の対応:</span> {{ c.how_handled }}</div>
      </div>
    </v-card-text>
    <v-card-actions>
      <v-spacer />
      <v-btn size="small" variant="text" @click="$emit('close')">閉じる</v-btn>
    </v-card-actions>
  </v-card>
</template>
