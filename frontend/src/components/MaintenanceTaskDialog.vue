<script setup lang="ts">
// 定期整備の作業の追加・編集。点検の作業は、対象の計器とチェックリスト（定修点検）を指定する（内容は空なら自動で入る）
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import { TASK_KIND_LABEL } from '@/constants/maintenanceStatus'
import { usePermissions } from '@/composables/usePermissions'

const props = defineProps<{ maintenance: any; task: any | null }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

const { canViewUsers } = usePermissions()
const form = ref({
  department_id: null as number | null, kind: 'inspection', equipment_id: null as number | null, instrument_id: null as number | null,
  checklist_template_id: null as number | null, title: '', assigned_to_id: null as number | null, notes: '',
})
const departments = ref<any[]>([])
const instruments = ref<any[]>([])
const templates = ref<any[]>([])
const users = ref<any[]>([])
const errors = ref<string[]>([])

const kindOptions = Object.entries(TASK_KIND_LABEL).map(([value, title]) => ({ title, value }))
const isInspection = computed(() => form.value.kind === 'inspection')

async function loadInstruments(equipmentId: number | null) {
  if (!equipmentId) {
    instruments.value = []
    return
  }
  const res = await api.get('/instruments', { params: { equipment_id: equipmentId, per_page: 1000 } })
  instruments.value = res.data.data
}

// 設備を変えたら、その設備の計器の選択肢に取り直し、選んでいた計器が別の設備のものなら外す
async function onEquipmentChange(equipmentId: number | null) {
  await loadInstruments(equipmentId)
  if (form.value.instrument_id && !instruments.value.some((i) => i.id === form.value.instrument_id)) form.value.instrument_id = null
}

// 計器を選んだら、その種類の定修点検のチェックリストを提案する（計器の種類とテンプレートの対応は、サーバーの一括追加と同じ考え方）
function suggestTemplate(instrumentId: number | null) {
  const instrument = instruments.value.find((i) => i.id === instrumentId)
  if (!instrument) return
  const key = instrument.instrument_type === 'safety_valve' ? '安全弁' : instrument.instrument_type === 'shutoff_valve' ? '遮断弁' : instrument.calibration_kind === 'positioner' ? '調節弁' : instrument.calibration_kind === 'transmitter' ? '伝送器' : null
  const template = key && templates.value.find((t) => t.name.startsWith(key))
  if (template) form.value.checklist_template_id = template.id
}

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  const t = props.task
  form.value = t
    ? {
        department_id: t.department?.id ?? null, kind: t.kind, equipment_id: t.equipment?.id ?? null, instrument_id: t.instrument?.id ?? null,
        checklist_template_id: t.checklist_template?.id ?? null, title: t.title, assigned_to_id: t.assigned_to?.id ?? null, notes: t.notes || '',
      }
    : { department_id: null, kind: 'inspection', equipment_id: props.maintenance.equipments?.[0]?.id ?? null, instrument_id: null, checklist_template_id: null, title: '', assigned_to_id: null, notes: '' }

  const [deptRes, templateRes] = await Promise.all([api.get('/departments'), api.get('/checklist_templates')])
  departments.value = deptRes.data.data.filter((d: any) => d.site_id === props.maintenance.site_id)
  // 定修のチェックリスト（定期整備の作業で使う）。周期が未設定の独自のテンプレートも選べる
  templates.value = templateRes.data.data.filter((tpl: any) => tpl.cycle === 'turnaround' || !tpl.cycle)
  if (canViewUsers.value && !users.value.length) users.value = (await api.get('/users', { params: { per_page: 200 } })).data.data
  await loadInstruments(form.value.equipment_id)
})

async function save() {
  errors.value = []
  const payload = { ...form.value, checklist_template_id: isInspection.value ? form.value.checklist_template_id : null }
  try {
    if (props.task) await api.patch(`/scheduled_maintenances/${props.maintenance.id}/tasks/${props.task.id}`, { maintenance_task: payload })
    else await api.post(`/scheduled_maintenances/${props.maintenance.id}/tasks`, { maintenance_task: payload })
    open.value = false
    emit('saved')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="640" scrollable>
    <v-card>
      <v-card-title>{{ task ? '作業の編集' : '作業の追加' }}</v-card-title>
      <v-card-text>
        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-row dense>
          <v-col cols="6"><v-select v-model="form.kind" :items="kindOptions" item-title="title" item-value="value" label="種類 *" /></v-col>
          <v-col cols="6">
            <v-select v-model="form.department_id" :items="departments" item-title="full_path" item-value="id" label="部署" clearable />
          </v-col>
          <v-col cols="6">
            <v-select
              v-model="form.equipment_id"
              :items="maintenance.equipments"
              item-title="name"
              item-value="id"
              label="対象設備 *"
              @update:model-value="onEquipmentChange"
            />
          </v-col>
          <v-col cols="6">
            <v-select v-model="form.instrument_id" :items="instruments" item-title="tag_number" item-value="id" label="対象計器" clearable @update:model-value="suggestTemplate" />
          </v-col>
        </v-row>
        <v-select
          v-if="isInspection"
          v-model="form.checklist_template_id"
          :items="templates"
          item-title="name"
          item-value="id"
          label="チェックリスト（定修点検）"
          clearable
          class="mb-2"
        />
        <v-text-field v-model="form.title" :label="isInspection ? '内容（空なら、計器とチェックリストから入ります）' : '内容 *'" class="mb-2" />
        <v-autocomplete v-if="canViewUsers" v-model="form.assigned_to_id" :items="users" item-title="name" item-value="id" label="担当者" clearable class="mb-2" />
        <v-textarea v-model="form.notes" label="備考" rows="2" />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" @click="save">保存</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
