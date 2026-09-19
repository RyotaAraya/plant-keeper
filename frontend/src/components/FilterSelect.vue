<script setup lang="ts">
// 一覧の絞り込み用の複数選択。未選択は「絞り込まない」。
// 選んだ項目は先頭の1つだけ表示し、残りは「ほか N」にまとめる（狭い絞り込みの行でも折り返さないため）。
// 選択肢が多いもの（設備など）は searchable で入力して探せる
const props = withDefaults(defineProps<{
  items: any[]
  label: string
  itemTitle?: string
  itemValue?: string
  searchable?: boolean
}>(), {
  itemTitle: 'title',
  itemValue: 'value',
  searchable: false,
})

const model = defineModel<any[]>({ default: () => [] })
</script>

<template>
  <component
    :is="props.searchable ? 'v-autocomplete' : 'v-select'"
    v-model="model"
    :items="props.items"
    :item-title="props.itemTitle"
    :item-value="props.itemValue"
    :label="props.label"
    multiple
    clearable
    density="compact"
    hide-details
    class="pk-filter-select"
  >
    <template #selection="{ item, index }">
      <span v-if="index === 0" class="pk-filter-select__value">
        <span class="pk-filter-select__title">{{ item.title }}</span>
        <span v-if="model.length > 1" class="pk-filter-select__more">ほか{{ model.length - 1 }}</span>
      </span>
    </template>
  </component>
</template>

<style scoped>
.pk-filter-select {
  min-width: 150px;
}

.pk-filter-select__value {
  display: inline-flex;
  align-items: baseline;
  gap: 0.35rem;
  min-width: 0;
}

.pk-filter-select__title {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pk-filter-select__more {
  flex: none;
  color: var(--pk-steel);
  font-size: 0.75rem;
  font-weight: 700;
}
</style>
