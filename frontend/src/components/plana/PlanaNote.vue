<script setup lang="ts">
// プラナの提案カードの見出し行。「プラナからの提案です」と分かるようにする
// （提案は下書きまでで、反映するかは人が決める。その注意書きを、スロットに書く）
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
</script>

<template>
  <div class="pk-plana-note">
    <PlanaAvatar :size="24" />
    <div class="pk-plana-note__text"><slot /></div>
  </div>
</template>

<style scoped>
.pk-plana-note {
  display: flex;
  align-items: flex-start;
  gap: 0.6rem;
  margin-bottom: 0.6rem;
  font-size: 0.75rem;
  line-height: 1.6;
  color: rgba(var(--v-theme-on-surface), var(--v-medium-emphasis-opacity));
}

.pk-plana-note__text {
  min-width: 0;
  padding-top: 0.1rem;
}
</style>
