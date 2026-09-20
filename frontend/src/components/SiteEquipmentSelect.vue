<script setup lang="ts">
// 拠点の設備の複数選択（定期整備の対象設備）。拠点が変わったら、その拠点の設備を取り直し、拠点にない設備は外す
import { ref, watch } from 'vue'
import api from '@/api/axios'

const props = defineProps<{ siteId: number | null; label?: string }>()
const model = defineModel<number[]>({ default: () => [] })

const options = ref<{ id: number; name: string; site_id: number }[]>([])

async function load(siteId: number | null) {
  if (!siteId) {
    options.value = []
    return
  }
  const res = await api.get('/equipments', { params: { site_ids: [siteId], per_page: 1000 } })
  options.value = res.data.data
  model.value = model.value.filter((id) => options.value.some((e) => e.id === id))
}

watch(() => props.siteId, load, { immediate: true })
</script>

<template>
  <v-autocomplete
    v-model="model"
    :items="options"
    item-title="name"
    item-value="id"
    :label="label ?? '対象設備 *'"
    multiple
    chips
    closable-chips
    :disabled="!siteId"
    hint="関連設備をまとめて停止して整備するときは、複数選びます"
    persistent-hint
  />
</template>
