<script setup lang="ts">
// 基準器の校正の状態（校正済み・期限間近・期限切れ・不合格・記録なし）と、次の校正の期限
import type { CalibrationState } from '@/types/models'
import { STATE_COLOR, STATE_LABEL } from '@/utils/referenceStandard'

defineProps<{ state: CalibrationState; nextDueOn?: string | null; size?: string }>()
</script>

<template>
  <v-chip :color="STATE_COLOR[state]" :size="size ?? 'small'" label variant="tonal">
    {{ STATE_LABEL[state] }}<template v-if="nextDueOn && state !== 'never' && state !== 'failed'">（{{ nextDueOn }}まで）</template>
  </v-chip>
</template>
