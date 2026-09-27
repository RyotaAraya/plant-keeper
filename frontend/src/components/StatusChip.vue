<script setup lang="ts">
// 状態・優先度のチップ。種類と値から呼び方と色を決め、規則（constants/statusChip.ts）どおりに塗り分ける。
// 種類の表にないもの（バイパス・期限など）は label・color・alert を直接渡す
import { computed } from 'vue'
import { chipFor, type StatusKind } from '@/constants/statusChip'

// alert は省略時に undefined のまま（Vue は真偽値の props を省略すると false にするため、規則の塗りを上書きしないよう既定を明示する）
const props = withDefaults(defineProps<{ kind?: StatusKind; value?: string; label?: string; color?: string; alert?: boolean }>(), { kind: undefined, value: undefined, label: undefined, color: undefined, alert: undefined })

const spec = computed(() => {
  const base = props.kind && props.value ? chipFor(props.kind, props.value) : { label: '', color: 'grey', alert: false }
  return { label: props.label ?? base.label, color: props.color ?? base.color, alert: props.alert ?? base.alert }
})
</script>

<template>
  <v-chip :color="spec.color" :variant="spec.alert ? 'flat' : 'tonal'" size="small" label class="pk-status-chip">{{ spec.label }}</v-chip>
</template>

<style scoped>
.pk-status-chip { font-weight: 600; }
</style>
