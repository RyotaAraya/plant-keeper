<script setup lang="ts">
// 設備に適用する法規区分の複数選択。設備の新規作成・編集で共通に使う。
// 選択肢は設備に適用できる区分（計器単位の計量法は除く）。選んだ区分は色つきのラベルで表示する
import { onMounted, ref } from 'vue'
import api from '@/api/axios'
import RegulationChip from '@/components/RegulationChip.vue'
import type { Regulation } from '@/types/models'

const model = defineModel<number[]>({ default: () => [] })
const options = ref<Regulation[]>([])

onMounted(async () => {
  const res = await api.get('/regulations', { params: { target: 'equipment' } })
  options.value = res.data.data
})
</script>

<template>
  <v-select
    v-model="model"
    :items="options"
    item-title="name"
    item-value="id"
    :item-props="(regulation: Regulation) => ({ subtitle: regulation.law_name })"
    label="適用法規"
    multiple
    chips
    closable-chips
    hint="設備が対象になる法規。法定検査の周期や、付属機器の点検周期の起点になります"
    persistent-hint
  >
    <template #chip="{ item, props }">
      <RegulationChip v-bind="props" :regulation="item.raw" />
    </template>
  </v-select>
</template>
