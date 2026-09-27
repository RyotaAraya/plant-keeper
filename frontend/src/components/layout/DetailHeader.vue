<script setup lang="ts">
// 詳細画面の頭（デザインガイド「詳細画面」）。どの詳細でも、戻る → 種類 → 名前と状態 → 補足、右端に操作を同じ位置に置く。
// 一覧の見出し（PageHeader）と同じ大きさ・余白にそろえる
defineProps<{
  // 戻る先の一覧（ヘッダーの現在地と同じ）
  backTo: string
  backLabel: string
  // 何の詳細か（例: トラブル・設備・定期整備）
  kind: string
  title: string
  subtitle?: string
}>()
</script>

<template>
  <header class="pk-detail-header">
    <router-link :to="backTo" class="pk-detail-header__back" :aria-label="`${backLabel}に戻る`">
      <v-icon size="16" aria-hidden="true">mdi-arrow-left</v-icon>{{ backLabel }}
    </router-link>
    <div class="pk-detail-header__row">
      <div class="pk-detail-header__main">
        <p class="pk-detail-header__kind">{{ kind }}</p>
        <div class="pk-detail-header__title">
          <h1>{{ title }}</h1>
          <slot name="status" />
        </div>
        <p v-if="subtitle || $slots.meta" class="pk-detail-header__meta">
          <slot name="meta">{{ subtitle }}</slot>
        </p>
      </div>
      <div v-if="$slots.actions" class="pk-detail-header__actions">
        <slot name="actions" />
      </div>
    </div>
  </header>
</template>

<style scoped>
.pk-detail-header { margin-bottom: 20px; }
.pk-detail-header__back { display: inline-flex; align-items: center; gap: 4px; margin-bottom: 8px; color: var(--pk-muted); font-size: 0.8125rem; text-decoration: none; }
.pk-detail-header__back:hover { color: var(--pk-steel); text-decoration: underline; }
.pk-detail-header__row { display: flex; flex-wrap: wrap; align-items: flex-end; justify-content: space-between; gap: 12px 24px; }
.pk-detail-header__main { min-width: 0; }
.pk-detail-header__kind { color: var(--pk-steel); font-size: 0.75rem; font-weight: 700; letter-spacing: 0.04em; }
.pk-detail-header__title { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 12px; }
.pk-detail-header__title h1 { font-size: 1.55rem; font-weight: 700; line-height: 1.4; overflow-wrap: anywhere; }
.pk-detail-header__meta { margin-top: 4px; color: var(--pk-muted); font-size: 0.8125rem; }
.pk-detail-header__actions { display: flex; flex-wrap: wrap; gap: 8px; }
@media (max-width: 600px) {
  .pk-detail-header__title h1 { font-size: 1.25rem; }
  .pk-detail-header__actions { width: 100%; }
}
</style>
