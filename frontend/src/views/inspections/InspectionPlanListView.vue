<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import FilterSelect from '@/components/FilterSelect.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { InspectionPlan } from '@/types/models'
import { todayForInput } from '@/utils/datetime'
import { siteIdsFromQuery } from '@/utils/listQuery'
import { latestGuard } from '@/utils/latestGuard'

const route = useRoute()
const router = useRouter()
const { canManageInspectionPlan } = usePermissions()
const authStore = useAuthStore()

const plans = ref<InspectionPlan[]>([])
const { equipments, load: loadSiteOptions } = useSiteScopeOptions({ withDepartments: false })
const templates = ref<any[]>([])
const instruments = ref<any[]>([])
const loading = ref(false)

// 通常業務では自拠点の計画だけ見ればよいため、自分の所属拠点を初期値にする
const filters = ref({
  site_ids: siteIdsFromQuery(route.query.site_ids, (authStore.user?.site_id ? [authStore.user.site_id] : []) as number[]),
  equipment_ids: [] as number[],
  overdue: route.query.overdue === 'true',
})

const headers = [
  { title: '期限', key: 'next_due_on', width: '190px' },
  { title: '点検計画', key: 'name' },
  { title: '設備', key: 'equipment.name', width: '160px' },
  { title: '計器', key: 'instrument.tag_number', width: '110px' },
  { title: '周期', key: 'interval_days', width: '90px' },
  { title: '前回実施', key: 'last_inspected_on', width: '120px' },
  { title: '', key: 'actions', sortable: false, width: '130px' },
]

const inspectionTypeOptions = [
  { title: '日常点検', value: 'routine' },
  { title: '定期点検', value: 'periodic' },
  { title: 'テレメトリ', value: 'telemetry' },
  { title: '運転チェック', value: 'operation_check' },
]

// 期限までの日数で色分け（超過=赤、7日以内=橙）
function dueColor(plan: InspectionPlan) {
  if (plan.overdue) return 'error'
  if (plan.days_until_due <= 7) return 'warning'
  return 'success'
}

function dueLabel(plan: InspectionPlan) {
  if (plan.overdue) return `${plan.next_due_on}（${-plan.days_until_due}日超過）`
  if (plan.days_until_due === 0) return `${plan.next_due_on}（本日）`
  return `${plan.next_due_on}（あと${plan.days_until_due}日）`
}

const fetchPlansGuard = latestGuard()

async function fetchPlans() {
  const isLatest = fetchPlansGuard()
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.equipment_ids.length) params.equipment_ids = filters.value.equipment_ids
    if (filters.value.overdue) params.overdue = 'true'
    const res = await api.get('/inspection_plans', { params })
    if (!isLatest()) return
    plans.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

async function fetchMasters() {
  const [, tmplRes] = await Promise.all([
    loadSiteOptions(filters.value.site_ids),
    api.get('/checklist_templates'),
  ])
  templates.value = tmplRes.data.data
}

// 拠点を変えたら、表示する拠点にない設備の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
function changeSite(siteIds: number[]) {
  const shown = (id: number) => siteIds.length === 0 || siteIds.includes(id)
  const keepEquipment = filters.value.equipment_ids.filter((id) => equipments.value.find((e) => e.id === id && shown(e.site_id)))
  filters.value = { ...filters.value, site_ids: siteIds, equipment_ids: keepEquipment }
  loadSiteOptions(siteIds)
}

function startInspection(plan: InspectionPlan) {
  const query: Record<string, string> = {
    inspection_plan_id: String(plan.id),
    equipment_id: String(plan.equipment_id),
    inspection_type: plan.inspection_type,
  }
  if (plan.instrument_id) query.instrument_id = String(plan.instrument_id)
  if (plan.checklist_template_id) query.checklist_template_id = String(plan.checklist_template_id)
  router.push({ path: '/inspections/new', query })
}

// 計画の登録ダイアログ
const dialog = ref(false)
const saving = ref(false)
const errors = ref<string[]>([])
const form = ref({
  name: '',
  equipment_id: null as number | null,
  instrument_id: null as number | null,
  checklist_template_id: null as number | null,
  inspection_type: 'periodic',
  interval_days: 30,
  next_due_on: todayForInput(),
})

async function onEquipmentChange() {
  form.value.instrument_id = null
  if (!form.value.equipment_id) {
    instruments.value = []
    return
  }
  const res = await api.get('/instruments', { params: { equipment_id: form.value.equipment_id, per_page: 100 } })
  instruments.value = res.data.data
}

function openDialog() {
  errors.value = []
  instruments.value = []
  form.value = {
    name: '',
    equipment_id: null,
    instrument_id: null,
    checklist_template_id: null,
    inspection_type: 'periodic',
    interval_days: 30,
    next_due_on: todayForInput(),
  }
  dialog.value = true
}

async function save() {
  errors.value = []
  saving.value = true
  try {
    await api.post('/inspection_plans', { inspection_plan: form.value })
    dialog.value = false
    await fetchPlans()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  fetchMasters()
  fetchPlans()
})
watch(filters, fetchPlans, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">点検計画</h1>
      <v-spacer />
      <v-btn v-if="canManageInspectionPlan" color="primary" prepend-icon="mdi-plus" @click="openDialog">計画を追加</v-btn>
    </div>

    <div class="d-flex ga-4 mb-4 flex-wrap align-center">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <FilterSelect v-model="filters.equipment_ids" :items="equipments" item-title="name" item-value="id" label="設備" searchable style="max-width: 240px" />
      <v-switch v-model="filters.overdue" label="期限超過のみ" color="error" density="compact" hide-details />
    </div>

    <v-data-table
      :headers="headers"
      :items="plans"
      :loading="loading"
      :sort-by="[{ key: 'next_due_on', order: 'asc' }]"
      hover
    >
      <template #item.next_due_on="{ item }">
        <v-chip :color="dueColor(item)" size="small">{{ dueLabel(item) }}</v-chip>
      </template>
      <template #item.interval_days="{ item }">{{ item.interval_days }}日ごと</template>
      <template #item.last_inspected_on="{ item }">{{ item.last_inspected_on ?? '未実施' }}</template>
      <template #item.actions="{ item }">
        <v-btn size="small" variant="outlined" @click="startInspection(item)">点検を実施</v-btn>
      </template>
    </v-data-table>

    <v-dialog v-model="dialog" max-width="560">
      <v-card>
        <v-card-title>点検計画を追加</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" variant="tonal" class="mb-3">{{ errors.join('、') }}</v-alert>
          <v-text-field v-model="form.name" label="計画名" class="mb-2" />
          <v-select
            v-model="form.equipment_id"
            :items="equipments"
            item-title="name"
            item-value="id"
            label="設備"
            class="mb-2"
            @update:model-value="onEquipmentChange"
          />
          <v-select
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
          <v-select
            v-model="form.inspection_type"
            :items="inspectionTypeOptions"
            item-title="title"
            item-value="value"
            label="種別"
            class="mb-2"
          />
          <v-text-field v-model.number="form.interval_days" label="周期（日）" type="number" min="1" class="mb-2" />
          <v-text-field v-model="form.next_due_on" label="次回期限" type="date" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" :loading="saving" @click="save">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>
