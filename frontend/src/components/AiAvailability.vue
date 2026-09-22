<script setup lang="ts">
import type { AiStatus } from '@/types/models'
defineProps<{ status: AiStatus | null; loading: boolean; failed: boolean }>()
defineEmits<{ retry: [] }>()
</script>

<template>
  <p v-if="loading" role="status" class="text-body-2 mb-3">AIの利用状況を確認しています。記録は直接入力できます。</p>
  <v-alert v-else-if="failed" type="info" variant="tonal" class="mb-3" role="status">
    AIの利用状況を取得できませんでした。記録の入力は続けられます。
    <v-btn variant="text" size="small" @click="$emit('retry')">再確認</v-btn>
  </v-alert>
  <v-alert v-else-if="status && !status.enabled" type="info" variant="tonal" class="mb-3" role="status">
    この環境ではAI機能は無効です。記録の入力と過去のトラブルの参照は利用できます。
  </v-alert>
  <v-alert v-else-if="status && status.remaining_today <= 0" type="info" variant="tonal" class="mb-3" role="status">
    今日のAI利用回数の上限に達しました。入力中のメモはそのまま、記録を直接入力できます。
  </v-alert>
</template>
