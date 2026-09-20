<script setup lang="ts">
// 法規区分のラベル。区分ごとに色を分ける（色の対応は utils/regulation.ts）
import { regulationColor } from '@/utils/regulation'

defineProps<{ regulation: { code: string; name: string } }>()
</script>

<template>
  <v-chip :color="regulationColor(regulation.code)" variant="tonal" label size="small">
    <slot>{{ regulation.name }}</slot>
  </v-chip>
</template>
