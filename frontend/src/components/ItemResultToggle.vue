<script setup lang="ts">
// 点検の項目の判定（良好／不具合あり／－）。もう一度押すと未判定に戻る。
// 選択式・自由記述（judged=false）は、不具合あり・該当なしだけを出す
import { computed } from 'vue'
import { RESULT_LABEL, type ItemResult } from '@/utils/checklistCriteria'

const props = defineProps<{
  modelValue: ItemResult | null
  judged: boolean
  // 良好を選べない（範囲外の測定値）
  goodDisabled?: boolean
}>()
const emit = defineEmits<{ 'update:modelValue': [value: ItemResult | null] }>()

const choices = computed(() => (props.judged ? (['good', 'defect', 'na'] as ItemResult[]) : (['defect', 'na'] as ItemResult[])))
const COLORS: Record<ItemResult, string> = { good: 'success', defect: 'error', na: 'grey-darken-1' }

function select(value: ItemResult) {
  emit('update:modelValue', props.modelValue === value ? null : value)
}
</script>

<template>
  <div class="item-result" role="group" aria-label="判定">
    <v-btn
      v-for="choice in choices"
      :key="choice"
      :aria-label="choice === 'na' ? '該当なし' : RESULT_LABEL[choice]"
      :aria-pressed="modelValue === choice"
      :color="modelValue === choice ? COLORS[choice] : undefined"
      :variant="modelValue === choice ? 'flat' : 'outlined'"
      :disabled="choice === 'good' && goodDisabled && modelValue !== 'good'"
      size="small"
      class="item-result__btn"
      @click="select(choice)"
    >
      {{ RESULT_LABEL[choice] }}
    </v-btn>
  </div>
</template>

<style scoped>
.item-result { display: inline-flex; gap: 6px; flex-wrap: wrap; }
.item-result__btn { min-width: 44px; letter-spacing: 0; }
</style>
