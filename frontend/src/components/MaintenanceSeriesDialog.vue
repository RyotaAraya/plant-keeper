<script setup lang="ts">
// 定期整備の系列（繰り返しのまとまり）の登録・編集と、設備ごとの周期（月数）。
// 定期整備から登録するとき（series が null）は、その整備の対象設備を初期の設備にして、作った系列にその整備を所属させる
import { ref, watch } from 'vue'
import api from '@/api/axios'

const props = defineProps<{ series: any | null; maintenance: any }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

type Row = { equipment_id: number; name: string; interval_months: string }
const name = ref('')
const rows = ref<Row[]>([])
const errors = ref<string[]>([])
const siteEquipments = ref<{ id: number; name: string }[]>([])
const addId = ref<number | null>(null)

const DEFAULT_INTERVAL = '24'

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  if (props.series) {
    name.value = props.series.name
    rows.value = (props.series.maintenance_series_equipments || []).map((m: any) => ({ equipment_id: m.equipment_id, name: m.equipment?.name ?? '', interval_months: String(m.interval_months) }))
  } else {
    // 名称の先頭の年は外す（各回の名称は年つき。系列の名前は年なし）
    name.value = props.maintenance.title.replace(/^\d{4}年\s*/, '')
    rows.value = (props.maintenance.equipments || []).map((e: any) => ({ equipment_id: e.id, name: e.name, interval_months: DEFAULT_INTERVAL }))
  }
  const res = await api.get('/equipments', { params: { site_ids: [props.maintenance.site_id], per_page: 1000 } })
  siteEquipments.value = res.data.data
})

const addable = () => siteEquipments.value.filter((e) => !rows.value.some((r) => r.equipment_id === e.id))

function addRow(id: number | null) {
  const equipment = siteEquipments.value.find((e) => e.id === id)
  if (equipment) rows.value.push({ equipment_id: equipment.id, name: equipment.name, interval_months: DEFAULT_INTERVAL })
  addId.value = null
}

async function save() {
  errors.value = []
  const equipmentIntervals = rows.value.map((r) => ({ equipment_id: r.equipment_id, interval_months: Number(r.interval_months) }))
  try {
    if (props.series) {
      await api.patch(`/maintenance_series/${props.series.id}`, { maintenance_series: { name: name.value, equipment_intervals: equipmentIntervals } })
    } else {
      const res = await api.post('/maintenance_series', {
        maintenance_series: { site_id: props.maintenance.site_id, name: name.value, equipment_intervals: equipmentIntervals },
      })
      await api.patch(`/scheduled_maintenances/${props.maintenance.id}`, { scheduled_maintenance: { maintenance_series_id: res.data.data.id } })
    }
    open.value = false
    emit('saved')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="600" scrollable>
    <v-card>
      <v-card-title>{{ series ? '系列の編集' : '系列に登録' }}</v-card-title>
      <v-card-text>
        <div class="text-caption text-medium-emphasis mb-3">
          繰り返し行う整備のまとまりです。設備ごとの周期を登録すると、「次回を作る」で、周期が来た設備が自動で対象に入ります（例: ボイラー24か月、発電機48か月）。
        </div>
        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-text-field v-model="name" label="系列の名前 *（例: A号ボイラー整備）" class="mb-2" />
        <div class="text-subtitle-2 mb-1">設備ごとの周期</div>
        <div v-for="(row, i) in rows" :key="row.equipment_id" class="d-flex align-center ga-2 mb-1" :data-testid="`series-row-${row.name}`">
          <span class="flex-grow-1">{{ row.name }}</span>
          <v-text-field v-model="row.interval_months" type="number" min="1" suffix="か月ごと" density="compact" hide-details style="max-width: 170px" :aria-label="`${row.name}の周期（月）`" />
          <v-btn icon="mdi-close" size="x-small" variant="text" :aria-label="`${row.name}を外す`" @click="rows.splice(i, 1)" />
        </div>
        <v-select
          v-model="addId"
          :items="addable()"
          item-title="name"
          item-value="id"
          label="設備を追加"
          density="compact"
          hide-details
          class="mt-2"
          @update:model-value="addRow"
        />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" @click="save">保存</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
