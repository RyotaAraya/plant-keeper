<script lang="ts">
export type PlanTab = 'all' | 'inspection' | 'maintenance' | 'due'
// URLは互換性を維持する。画面では仕事の種類と、点検の見方を分ける。
export const PLAN_TABS: { value: PlanTab; title: string }[] = [
  { value: 'all', title: 'すべて' },
  { value: 'inspection', title: '定期点検' },
  { value: 'maintenance', title: '定期整備' },
  { value: 'due', title: '点検の期限順' },
]
</script>
<script setup lang="ts">
const props = defineProps<{ modelValue: PlanTab }>()
const emit = defineEmits<{ 'update:modelValue': [value: PlanTab] }>()
function setKind(value: PlanTab) {
  emit('update:modelValue', value === 'inspection' && props.modelValue === 'due' ? 'due' : value)
}
</script>
<template>
  <div class="pk-plan-tabs">
    <div>
      <span class="pk-plan-tabs__label">計画の種類</span>
      <v-btn-toggle :model-value="modelValue === 'due' ? 'inspection' : modelValue" mandatory divided density="compact" variant="outlined" color="primary" aria-label="計画の種類" @update:model-value="setKind">
        <v-btn value="all">すべて</v-btn>
        <v-btn value="inspection">定期点検</v-btn>
        <v-btn value="maintenance">定期整備</v-btn>
      </v-btn-toggle>
    </div>
    <div v-if="modelValue !== 'maintenance'">
      <span class="pk-plan-tabs__label">点検の見方</span>
      <v-btn-toggle :model-value="modelValue === 'due' ? 'due' : 'inspection'" mandatory divided density="compact" variant="outlined" color="primary" aria-label="点検の見方" @update:model-value="emit('update:modelValue', $event === 'due' ? 'due' : 'inspection')">
        <v-btn value="inspection">まとまり別</v-btn>
        <v-btn value="due">点検の期限順</v-btn>
      </v-btn-toggle>
    </div>
  </div>
</template>
<style scoped>
.pk-plan-tabs { display: flex; flex-wrap: wrap; gap: 8px 16px; max-width: 100%; }
.pk-plan-tabs > div { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; }
.pk-plan-tabs__label { font-size: .75rem; color: var(--pk-muted); }
</style>
