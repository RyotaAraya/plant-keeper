<script setup lang="ts">
// 設備・計器に関係するインターロックを、バイパスの状態つきのチップで並べる（詳細へ移れる）。無ければ何も出さない
import { ref, watch } from 'vue'
import api from '@/api/axios'
import type { Interlock } from '@/types/models'
import { bypassColor, bypassLabel } from '@/utils/interlock'

const props = defineProps<{ equipmentId?: number; instrumentId?: number }>()
const interlocks = ref<Interlock[]>([])

async function load() {
  const params: Record<string, number> = { per_page: 100 }
  if (props.equipmentId) params.equipment_id = props.equipmentId
  if (props.instrumentId) params.instrument_id = props.instrumentId
  interlocks.value = (await api.get('/interlocks', { params })).data.data
}

watch(() => [props.equipmentId, props.instrumentId], load, { immediate: true })
</script>

<template>
  <div v-if="interlocks.length" class="d-flex align-center flex-wrap ga-2" data-testid="interlock-chips">
    <strong>インターロック:</strong>
    <v-chip
      v-for="il in interlocks"
      :key="il.id"
      :to="`/interlocks/${il.id}`"
      :color="il.open_bypass ? bypassColor(il.open_bypass) : undefined"
      :variant="il.open_bypass ? 'flat' : 'tonal'"
      size="small"
      label
    >
      {{ il.tag_number }} {{ il.name }}<template v-if="il.open_bypass">（{{ bypassLabel(il.open_bypass) }}）</template>
    </v-chip>
  </div>
</template>
