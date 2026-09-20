<script setup lang="ts">
// 一覧を、ある計器で絞り込んでいる印（「すべて見る」から開いたとき）。×で絞り込みを外す
import { ref, watch } from 'vue'
import api from '@/api/axios'

const props = defineProps<{ instrumentId: number }>()
defineEmits<{ clear: [] }>()

const tag = ref('')

async function load() {
  tag.value = ''
  try {
    tag.value = (await api.get(`/instruments/${props.instrumentId}`)).data.data.tag_number
  } catch {
    // タグ番号が取れなくても、絞り込み自体は効く
  }
}

watch(() => props.instrumentId, load, { immediate: true })
</script>

<template>
  <v-chip closable label prepend-icon="mdi-gauge" data-testid="instrument-filter-chip" @click:close="$emit('clear')">
    計器: {{ tag || `#${instrumentId}` }}
  </v-chip>
</template>
