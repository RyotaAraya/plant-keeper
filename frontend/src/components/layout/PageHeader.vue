<script setup lang="ts">
// 一覧・管理画面の見出し行。
// 今どの画面かはサイドバーの選択表示で分かるため、タイトルは画面上には出さず（読み上げ・文書構造用の h1 として残す）、
// 代わりに「この画面で何をするか」を1行で示す。右端は操作ボタン（スロット）
defineProps<{
  title: string
  description: string
}>()
</script>

<template>
  <header class="pk-page-header">
    <h1 class="pk-sr-only">{{ title }}</h1>
    <p class="pk-page-header__desc">{{ description }}</p>
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
  margin-bottom: 1rem;
}

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
