<script setup lang="ts">
// 点検計画の追加。まとまり（必須）・設備・計器・チェックリスト・周期・次回期限。
// まとまりの中から開くとき（groupId）は、そのまとまりを選んだ状態で、設備もそのまとまりの拠点の分だけにする
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import type { InspectionPlanGroup, RegulationInspection } from '@/types/models'
import { todayForInput } from '@/utils/datetime'
import { intervalLabel } from '@/utils/interval'
import { latestGuard } from '@/utils/latestGuard'
import { groupLabel } from '@/utils/inspectionPlanGroup'
import { regulationColor } from '@/utils/regulation'

const props = defineProps<{
  equipments: { id: number; name: string; site_id: number }[]
  groups: InspectionPlanGroup[]
  groupId?: number | null
}>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

const inspectionTypeOptions = [
  { title: '日常点検', value: 'routine' },
  { title: '定期点検', value: 'periodic' },
  { title: 'テレメトリ', value: 'telemetry' },
  { title: '運転チェック', value: 'operation_check' },
]

const templates = ref<any[]>([])
const instruments = ref<any[]>([])
const saving = ref(false)
const errors = ref<string[]>([])

function emptyForm() {
  return {
    name: '',
    // 点検のまとまり（必須。選んだ設備と同じ拠点のもの）
    inspection_plan_group_id: null as number | null,
    // 対象の設備。複数の設備をまとめた計画（巡回など）を作れる。先頭が代表の設備（equipment_id）
    equipment_ids: [] as number[],
    equipment_id: null as number | null,
    instrument_id: null as number | null,
    checklist_template_id: null as number | null,
    inspection_type: 'periodic',
    interval_days: 30,
    next_due_on: todayForInput(),
  }
}
const form = ref(emptyForm())

const selectedGroup = computed(() => props.groups.find((g) => g.id === form.value.inspection_plan_group_id))
// 複数の拠点のまとまりが並ぶときは、名前に拠点名を付けて区別する（どの拠点にも「伝送器 月次点検」がある）
const multiSite = computed(() => new Set(props.groups.map((g) => g.site_id)).size > 1)

// まとまりの選択肢。設備を選んだら、その設備の拠点のまとまりだけ（計画と同じ拠点のまとまりにしか入れられない）
const formGroups = computed(() => {
  const siteId = props.equipments.find((e) => e.id === form.value.equipment_ids[0])?.site_id
  return props.groups.filter((g) => !siteId || g.site_id === siteId)
})
// 設備の選択肢。まとまりを選んだら、その拠点の設備だけ
const formEquipments = computed(() => props.equipments.filter((e) => !selectedGroup.value || e.site_id === selectedGroup.value.site_id))

// まとまりを選んだら、既定の周期を初期値として入れる（計画ごとに変えられる）
function onGroupChange(groupId: number | null) {
  const group = props.groups.find((g) => g.id === groupId)
  if (group?.default_interval_days) form.value.interval_days = group.default_interval_days
}

// 選んだ設備に適用される法規の、法定検査（周期の目安として表示する）
const legalInspections = ref<(RegulationInspection & { regulation_code: string; regulation_name: string })[]>([])

const equipmentChangeGuard = latestGuard()

async function onEquipmentChange() {
  const isLatest = equipmentChangeGuard()
  form.value.instrument_id = null
  form.value.equipment_id = form.value.equipment_ids[0] ?? null
  // 設備の拠点と違うまとまりは外す
  if (!formGroups.value.some((g) => g.id === form.value.inspection_plan_group_id)) form.value.inspection_plan_group_id = null
  legalInspections.value = []
  // 計器の指定と、法定検査の周期の目安は、設備が1つのときだけ
  if (form.value.equipment_ids.length !== 1) {
    instruments.value = []
    return
  }
  const [instrumentRes, equipmentRes] = await Promise.all([
    api.get('/instruments', { params: { equipment_id: form.value.equipment_id, per_page: 100 } }),
    api.get(`/equipments/${form.value.equipment_id}`),
  ])
  if (!isLatest()) return
  instruments.value = instrumentRes.data.data
  legalInspections.value = (equipmentRes.data.data.regulations || []).flatMap((regulation: any) =>
    (regulation.regulation_inspections || []).map((inspection: RegulationInspection) => ({ ...inspection, regulation_code: regulation.code, regulation_name: regulation.name })),
  )
}

// 法定検査の周期を計画に反映する（計画名が空なら「設備名 検査名」を入れる）
function applyLegalInspection(inspection: RegulationInspection) {
  form.value.interval_days = inspection.interval_days
  if (!form.value.name) {
    const equipmentName = props.equipments.find((e) => e.id === form.value.equipment_id)?.name ?? ''
    form.value.name = `${equipmentName} ${inspection.name}`.trim()
  }
}

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  instruments.value = []
  legalInspections.value = []
  form.value = emptyForm()
  if (props.groupId) {
    form.value.inspection_plan_group_id = props.groupId
    onGroupChange(props.groupId)
  }
  if (!templates.value.length) {
    const res = await api.get('/checklist_templates')
    // 定修のチェックリストは、点検計画ではなく、定期整備の作業で使う
    templates.value = res.data.data.filter((t: any) => t.cycle !== 'turnaround')
  }
})

async function save() {
  errors.value = []
  saving.value = true
  try {
    await api.post('/inspection_plans', { inspection_plan: form.value })
    open.value = false
    emit('saved')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="560">
    <v-card>
      <v-card-title>点検計画を追加</v-card-title>
      <v-card-text>
        <v-alert v-if="errors.length" type="error" variant="tonal" class="mb-3">{{ errors.join('、') }}</v-alert>
        <v-text-field v-model="form.name" label="計画名" class="mb-2" />
        <v-select
          v-model="form.inspection_plan_group_id"
          :items="formGroups"
          :item-title="(g: InspectionPlanGroup) => groupLabel(g, multiSite)"
          item-value="id"
          label="まとまり"
          hint="「伝送器 月次点検」のような、計画をまとめる単位です。担当部署・法規区分はまとまりで決まります"
          persistent-hint
          class="mb-2"
          data-testid="plan-group-select"
          @update:model-value="onGroupChange"
        />
        <v-select
          v-model="form.equipment_ids"
          :items="formEquipments"
          item-title="name"
          item-value="id"
          label="設備"
          multiple
          chips
          closable-chips
          hint="複数の設備をまとめた計画（巡回など）を作れます。選べるのは同じ拠点の設備で、最初に選んだ設備が代表になります"
          persistent-hint
          class="mb-2"
          @update:model-value="onEquipmentChange"
        />
        <div v-if="legalInspections.length" class="mb-3">
          <div class="text-caption text-medium-emphasis mb-1">この設備に適用される法定検査（押すと周期を入れます）</div>
          <v-chip
            v-for="inspection in legalInspections"
            :key="`${inspection.regulation_name}-${inspection.id}`"
            size="small"
            label
            variant="tonal"
            :color="regulationColor(inspection.regulation_code)"
            class="mr-1 mb-1"
            @click="applyLegalInspection(inspection)"
          >
            {{ inspection.name }}（{{ intervalLabel(inspection.interval_days) }}）
          </v-chip>
        </div>
        <v-select
          v-if="form.equipment_ids.length <= 1"
          v-model="form.instrument_id"
          :items="instruments"
          item-title="tag_number"
          item-value="id"
          label="計器（任意）"
          clearable
          class="mb-2"
        />
        <v-select
          v-model="form.checklist_template_id"
          :items="templates"
          item-title="name"
          item-value="id"
          label="チェックリスト（任意）"
          clearable
          class="mb-2"
        />
        <v-select v-model="form.inspection_type" :items="inspectionTypeOptions" item-title="title" item-value="value" label="種別" class="mb-2" />
        <v-text-field v-model.number="form.interval_days" label="周期（日）" type="number" min="1" class="mb-2" />
        <v-text-field v-model="form.next_due_on" label="次回期限" type="date" />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" :loading="saving" :disabled="!form.inspection_plan_group_id" @click="save">保存</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
