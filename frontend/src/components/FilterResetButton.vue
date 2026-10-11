<script setup lang="ts">
// 一覧の絞り込みの行の右端に置く「リセット」。そのページの検索条件と保存済みの条件を既定に戻す（確認なし）
defineEmits<{ reset: [] }>()
</script>

<template>
  <v-btn variant="text" color="primary" prepend-icon="mdi-filter-remove-outline" class="pk-filters__reset" data-testid="filter-reset" @click="$emit('reset')">リセット</v-btn>
</template>

<style scoped>
.pk-filters__reset { margin-inline-start: auto; }
</style>
