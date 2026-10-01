<script setup lang="ts">
// 運転中に直せないトラブルを、定期整備の作業（整備）に回す。既存の定期整備（計画中・準備中）を選ぶか、新しく作る。
// トラブルの設備が回し先の対象設備になければ追加する。回すと、トラブルは「定修待ち」になる
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import { MAINTENANCE_STATUS_LABEL, periodLabel } from '@/constants/maintenanceStatus'

const props = defineProps<{ trouble: any }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ done: [maintenanceId: number] }>()

const mode = ref<'existing' | 'new'>('existing')
const maintenances = ref<any[]>([])
const selectedId = ref<number | null>(null)
const departments = ref<any[]>([])
const departmentId = ref<number | null>(null)
const newForm = ref({ title: '', planned_start_on: '', planned_end_on: '' })
const errors = ref<string[]>([])
const loading = ref(false)

const selected = computed(() => maintenances.value.find((m) => m.id === selectedId.value))
// 選んだ定期整備の対象設備に、トラブルの設備がなければ、追加される
const willAddEquipment = computed(() => !!selected.value && !selected.value.equipments.some((e: any) => e.id === props.trouble.equipment?.id))

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  loading.value = true
  const siteId = props.trouble.equipment?.site_id
  try {
    const [mRes, dRes] = await Promise.all([
      api.get('/scheduled_maintenances', { params: { site_ids: [siteId], statuses: ['planned', 'preparing'], per_page: 200 } }),
      api.get('/departments'),
    ])
    // 予定の近い順
    maintenances.value = [...mRes.data.data].sort((a: any, b: any) => a.planned_start_on.localeCompare(b.planned_start_on))
    departments.value = dRes.data.data.filter((d: any) => d.site_id === siteId)
  } finally {
    loading.value = false
  }
  mode.value = maintenances.value.length ? 'existing' : 'new'
  selectedId.value = maintenances.value[0]?.id ?? null
  departmentId.value = null
  newForm.value = { title: `${new Date().getFullYear()}年 ${props.trouble.equipment?.name ?? ''} 整備`, planned_start_on: '', planned_end_on: '' }
})

async function submit() {
  errors.value = []
  const payload: any = { department_id: departmentId.value }
  if (mode.value === 'existing') payload.scheduled_maintenance_id = selectedId.value
  else payload.new_maintenance = newForm.value
  try {
    const res = await api.post(`/troubles/${props.trouble.id}/defer_to_maintenance`, payload)
    open.value = false
    emit('done', res.data.data.maintenance.id)
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['定期整備に回せませんでした']
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="640" scrollable>
    <v-card>
      <v-card-title>定期整備に回す</v-card-title>
      <v-card-text>
        <div class="text-caption text-medium-emphasis mb-3">
          運転中に直せないトラブルを、定期整備の作業（種類は整備）として登録します。トラブルは「定修待ち」になり、作業が完了すると解決済、見送り・削除すると未対応に戻ります。
        </div>
        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-progress-linear v-if="loading" indeterminate />
        <template v-else>
          <v-radio-group v-model="mode" density="compact" hide-details class="mb-2">
            <v-radio label="既存の定期整備に追加する" value="existing" :disabled="!maintenances.length" />
            <v-radio label="新しい定期整備を作る" value="new" />
          </v-radio-group>

          <template v-if="mode === 'existing'">
            <v-select
              v-model="selectedId"
              :items="maintenances"
              item-title="title"
              item-value="id"
              :item-props="(m: any) => ({ subtitle: `${periodLabel(m.planned_start_on, m.planned_end_on)} ／ ${MAINTENANCE_STATUS_LABEL[m.status]} ／ ${(m.equipments || []).map((e: any) => e.name).join('・')}` })"
              label="定期整備 *"
              class="mb-2"
              data-testid="defer-maintenance-select"
            />
            <v-alert v-if="willAddEquipment" type="info" variant="tonal" density="compact" class="mb-2" data-testid="defer-equipment-added">
              「{{ trouble.equipment?.name }}」は、この定期整備の対象設備にないため、対象設備に追加します。
            </v-alert>
          </template>
          <template v-else>
            <v-text-field v-model="newForm.title" label="名称 *" class="mb-2" />
            <v-row dense>
              <v-col cols="6"><v-text-field v-model="newForm.planned_start_on" label="予定 開始日 *" type="date" /></v-col>
              <v-col cols="6"><v-text-field v-model="newForm.planned_end_on" label="予定 終了日" type="date" /></v-col>
            </v-row>
            <div class="text-caption text-medium-emphasis mb-2">対象設備は「{{ trouble.equipment?.name }}」のみで作ります（あとから追加できます）。</div>
          </template>

          <v-select v-model="departmentId" :items="departments" item-title="full_path" item-value="id" label="担当する部署" clearable />
        </template>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" :disabled="loading" @click="submit">回す</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
