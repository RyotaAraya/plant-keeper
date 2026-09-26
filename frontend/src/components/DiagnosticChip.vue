<script setup lang="ts">
import { computed } from 'vue'
import { DIAGNOSTIC_STATUS, type DiagnosticStatus } from '@/constants/diagnostics'

// 機器の自己診断（NAMUR NE 107）の状態。記号（F/C/S/M/N）とアイコンと呼び方で示す（色だけに頼らない）
const props = defineProps<{ status: DiagnosticStatus | null | undefined; size?: 'x-small' | 'small' | 'default' }>()
const spec = computed(() => (props.status ? DIAGNOSTIC_STATUS[props.status] : null))
</script>

<template>
  <v-chip v-if="spec" :color="spec.color" :size="size ?? 'small'" label variant="flat" :prepend-icon="spec.icon" :title="spec.hint" data-testid="diagnostic-chip">
    {{ spec.letter }} {{ spec.label }}
  </v-chip>
  <span v-else class="text-medium-emphasis text-caption">未受信</span>
</template>
