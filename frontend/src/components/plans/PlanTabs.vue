<script lang="ts">
export type PlanTab = 'all' | 'inspection' | 'maintenance' | 'due'
export const PLAN_TABS: { value: PlanTab; title: string }[] = [
  { value: 'all', title: 'すべて' },
  { value: 'inspection', title: '定期点検' },
  { value: 'maintenance', title: '定期整備' },
  { value: 'due', title: '点検の期限順' },
]
</script>

<script setup lang="ts">
// 「計画」画面の表示の切り替え。絞り込みの行の、拠点のすぐ右に置く（ホームの朝会・夕会の切り替えと同じ位置）
defineProps<{ modelValue: PlanTab }>()
defineEmits<{ 'update:modelValue': [value: PlanTab] }>()
</script>

<template>
  <!-- 狭い画面では、切り替えだけを横にスクロールする（ボタンを潰さない） -->
  <div class="pk-plan-tabs">
    <v-btn-toggle
      :model-value="modelValue"
      mandatory
      divided
      density="compact"
      variant="outlined"
      color="primary"
      aria-label="表示する計画"
      @update:model-value="$emit('update:modelValue', $event)"
    >
      <v-btn v-for="t in PLAN_TABS" :key="t.value" :value="t.value">{{ t.title }}</v-btn>
    </v-btn-toggle>
  </div>
</template>

<style scoped>
.pk-plan-tabs { max-width: 100%; overflow-x: auto; }
</style>
