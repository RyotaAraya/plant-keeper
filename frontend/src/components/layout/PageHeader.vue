<script setup lang="ts">
// 一覧・管理画面の見出し行。
// タイトルと説明は左、主要操作は右。狭い画面でも現在地が分かるようにする。
defineProps<{
  title: string
  description: string
}>()
</script>

<template>
  <header class="pk-page-header">
    <div>
      <h1 class="pk-page-header__title">{{ title }}</h1>
      <p class="pk-page-header__desc">{{ description }}</p>
    </div>
    <div v-if="$slots.default" class="pk-page-header__actions">
      <slot />
    </div>
  </header>
</template>

<style scoped>
.pk-page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  min-height: 40px;
  margin-bottom: 1.5rem;
}

.pk-page-header__title { font-size: 1.55rem; font-weight: 700; line-height: 1.4; margin-bottom: 0.35rem; }

.pk-page-header__desc {
  max-width: 56em;
  text-wrap: pretty;
  margin: 0;
  color: rgb(var(--v-theme-secondary));
  font-size: 0.875rem;
  line-height: 1.6;
}

.pk-page-header__actions {
  display: flex;
  flex: none;
  align-items: center;
  gap: 0.75rem;
}

@media (max-width: 600px) {
  .pk-page-header {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
