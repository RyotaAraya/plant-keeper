<script setup lang="ts">
import { ref, onMounted, computed, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import AiAvailability from '@/components/AiAvailability.vue'
import { useAiAvailability } from '@/composables/useAiAvailability'
import { useSiteScope } from '@/composables/useSiteScope'
import { useUnsavedWork } from '@/composables/useUnsavedWork'
import CalibrationTable from '@/components/CalibrationTable.vue'
import DefectAiAssist from '@/components/DefectAiAssist.vue'
import InspectionReferenceStandards from '@/components/InspectionReferenceStandards.vue'
import ItemResultToggle from '@/components/ItemResultToggle.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { useAuthStore } from '@/stores/auth'
import type { AiDefectDraft, InspectionReferenceStandardUse, ReferenceStandard } from '@/types/models'
import { calibrationInputFrom, emptyCalibrationInput, evaluateCalibration, snapshotFromInstrument } from '@/utils/calibration'
import { ITEM_TYPE_OPTIONS, criteriaOf, isFilled, isJudgedType, limitStatus, limitsText, startsSection, type ItemResult } from '@/utils/checklistCriteria'
import { nowForInput } from '@/utils/datetime'
import { revealApplied } from '@/utils/revealApplied'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { ownSiteIds } = useSiteScope()
const editId = computed(() => route.params.id as string | undefined)
const isEdit = computed(() => !!editId.value && route.name === 'InspectionEdit')

// 設備・部署の選択肢は拠点ごと。通常は自分の所属拠点の分だけを出す
const { equipments, departments, load: loadSiteOptions } = useSiteScopeOptions()
const instruments = ref<any[]>([])
const templates = ref<any[]>([])
const referenceStandards = ref<ReferenceStandard[]>([])
const errors = ref<string[]>([])
const saving = ref(false)
const initializing = ref(true)
// AI支援の状況。AIが使えない環境（null・無効）では、AIのボタンを出さない
const { status: aiStatus, loading: aiLoading, failed: aiFailed, refresh: fetchAiStatus } = useAiAvailability()

const form = ref({
  // 点検で見た設備。複数の設備をまとめて点検（巡回など）できる。先頭が代表の設備（equipment_id）
  equipment_ids: [] as number[],
  equipment_id: null as number | null,
  instrument_id: null as number | null,
  department_id: null as number | null,
  checklist_template_id: null as number | null,
  inspection_plan_id: null as number | null,
  maintenance_task_id: null as number | null,
  inspection_type: 'routine',
  inspected_at: nowForInput(),
  notes: '',
  items: [] as any[],
  reference_standards: [] as InspectionReferenceStandardUse[],
})

// 項目の位置ではなくオブジェクトを識別し、削除時に他項目へメモを移さない。
const itemKeys = new WeakMap<object, number>()
let nextItemKey = 0
function itemKey(item: object) {
  if (!itemKeys.has(item)) itemKeys.set(item, ++nextItemKey)
  return itemKeys.get(item)!
}
const memoItems = ref(new Set<object>())
const openedDefects = ref(new Set<object>())
function markMemo(item: object, dirty: boolean) {
  if (dirty) memoItems.value.add(item)
  else memoItems.value.delete(item)
}
const initialForm = ref('')
const saved = ref(false)
const dirty = computed(() => !saved.value && !!initialForm.value && (
  JSON.stringify(form.value) !== initialForm.value || form.value.items.some((item) => memoItems.value.has(item))
))
useUnsavedWork(dirty)

// 点検で見た設備（選択肢のうち、選ばれているもの）
const selectedEquipments = computed(() => equipments.value.filter((e) => form.value.equipment_ids.includes(e.id)))
const multipleEquipments = computed(() => form.value.equipment_ids.length > 1)

// 項目の計器の選択肢: 項目の設備が決まっていればその設備の計器、なければ点検で見た設備すべての計器
function instrumentsFor(item: any) {
  return item.equipment_id ? instruments.value.filter((i: any) => i.equipment_id === item.equipment_id) : instruments.value
}

// 選択肢は有効なテンプレートだけ（廃止したものは、この点検が参照している場合だけ残す）
const templateOptions = computed(() => templates.value.filter((t: any) => t.is_active || t.id === form.value.checklist_template_id))

// 取引用の計器（点検の計器、または項目の計器）の点検には、トレーサビリティのある校正の基準器が必要
const requireTraceable = computed(() => {
  const ids = [form.value.instrument_id, ...form.value.items.map((item) => item.instrument_id)]
  return ids.some((id) => id && instruments.value.find((i: any) => i.id === id)?.custody_transfer)
})

const inspectionTypeOptions = [
  { title: '日常点検', value: 'routine' },
  { title: '定期点検', value: 'periodic' },
  { title: 'テレメトリ', value: 'telemetry' },
  { title: '運転チェック', value: 'operation_check' },
]

const itemTypeOptions = ITEM_TYPE_OPTIONS

// 不具合ありの判定の項目は、トラブルの入力欄を開く
const isDefect = (item: any) => item.result === 'defect'

// 提出の前に、未記入の必須の項目の数を示す（提出時にサーバーでも確認する）。
// 判定のない5点校正は、合格ならサーバーが良好にするため、記入ありとみなす
function calibrationPassed(item: any) {
  const snapshot = snapshotFor(item)
  return item.item_type === 'calibration' && !!snapshot && !!item.calibration && evaluateCalibration(snapshot, item.calibration).result === 'pass'
}
const missingRequired = computed(() => form.value.items.filter((item) => item.required && !isFilled(item) && !calibrationPassed(item)).length)

// 測定値の許容範囲の外・数値でないときの案内
function measurementMessage(item: any) {
  const status = limitStatus(item, item.measured_value)
  if (status === 'invalid') return '数値で入力してください'
  if (status === 'below' || status === 'above') return `許容範囲外（${limitsText(item)}）`
  return ''
}

const outOfRange = (item: any) => ['below', 'above'].includes(limitStatus(item, item.measured_value) ?? '')

// 測定値から判定を自動で選ぶ（範囲内 → 良好、範囲外 → 不具合あり）。人が選んだ判定は、良好が範囲外になったときだけ変える
function onMeasuredInput(item: any) {
  const status = limitStatus(item, item.measured_value)
  const auto = status === 'within' ? 'good' : status === 'below' || status === 'above' ? 'defect' : null
  const replaceable = item.autoResult || !item.result || (item.result === 'good' && auto === 'defect')
  if (auto && replaceable) {
    setResult(item, auto)
    item.autoResult = true
  } else if (!auto && item.autoResult) {
    setResult(item, null)
  }
}

function onResultInput(item: any, value: ItemResult | null) {
  item.autoResult = false
  setResult(item, value)
}

// 5点校正の項目の入力欄。項目の種別を5点校正にしたときに用意する
function ensureCalibration(item: any) {
  if (item.item_type === 'calibration' && !item.calibration) item.calibration = emptyCalibrationInput()
}

// 校正の条件: 記録済みなら凍結された条件、なければ計器（項目の計器、なければ点検の計器）の現在の設定
function snapshotFor(item: any) {
  if (item.calibration_snapshot) return item.calibration_snapshot
  const id = item.instrument_id ?? form.value.instrument_id
  return snapshotFromInstrument(instruments.value.find((i: any) => i.id === id))
}

// 不具合欄に出す、選んだ計器（項目の計器、なければ複数設備でなければ点検の計器）の一次点検の定型項目・シール液
function defectInstrumentFor(item: any) {
  const id = item.instrument_id ?? (multipleEquipments.value ? null : form.value.instrument_id)
  return id ? instruments.value.find((i: any) => i.id === id) : null
}

async function fetchMasters() {
  const [, tmplRes, standardRes] = await Promise.all([
    loadSiteOptions(ownSiteIds()),
    api.get('/checklist_templates', { params: { include_inactive: true } }),
    api.get('/reference_standards', { params: { per_page: 1000 } }),
  ])
  templates.value = tmplRes.data.data
  // 自分の所属拠点の基準器を先頭に並べる（基準器は拠点間で持ち運ぶこともあるため、他拠点のものも選べる）
  const own = authStore.user?.site_id
  referenceStandards.value = [...standardRes.data.data].sort((a: ReferenceStandard, b: ReferenceStandard) => Number(b.site_id === own) - Number(a.site_id === own))
}

// 別拠点の設備の点検（編集や、点検計画からの実施）を開いたときは、その設備の拠点の選択肢に切り替える
async function ensureOptionsCoverEquipment() {
  const id = form.value.equipment_id
  if (!id || equipments.value.some((e) => e.id === id)) return
  const res = await api.get(`/equipments/${id}`)
  await loadSiteOptions([res.data.data.site_id])
}

// 選ばれている部署が、表示中の拠点の選択肢にないとき（別拠点の設備の点検を、自分の部署のまま開いたときなど）は、
// その部署を選択肢に足す。点検の部署は入力時に選ぶ値で、設備の拠点とは限らないため
async function ensureDepartmentInOptions() {
  const id = form.value.department_id
  if (!id || departments.value.some((d) => d.id === id)) return
  // 部署の詳細は管理者しか読めないため、誰でも読める一覧から探す
  const res = await api.get('/departments')
  const dept = res.data.data.find((d: any) => d.id === id)
  if (dept) departments.value = [...departments.value, { ...dept, display_name: `${dept.site?.name ?? ''} ${dept.full_path}` }]
}

// 点検で見た設備すべての計器
async function fetchInstruments() {
  if (!form.value.equipment_ids.length) {
    instruments.value = []
    return
  }
  const res = await api.get('/instruments', { params: { equipment_ids: form.value.equipment_ids, per_page: 1000 } })
  instruments.value = res.data.data
}

// AIの下書きを、項目の不具合の入力欄に入れる（タイトル・説明・優先度だけ。保存は点検を保存したとき）。
// どの提案をもとにしたかを、保存時に送る（監査ログに残り、AIの案と人が確定した内容を突き合わせられる）。
// 反映したら「報告する内容」を見える位置に出し、タイトルへフォーカスを移す（スマホでは提案の下にあるため）
async function applyAiDraft(item: any, draft: AiDefectDraft, idx: number) {
  item.defect_title = draft.title
  item.defect_description = draft.description
  if (draft.priority) item.defect_priority = draft.priority
  item.ai_suggestion_id = draft.suggestion_id
  await nextTick()
  revealApplied(document.getElementById(`defect-record-${idx}`), 'input')
}

async function onEquipmentChange() {
  const ids = form.value.equipment_ids
  const primary = ids[0] ?? null
  // 点検の計器は代表の設備のもの。代表の設備が変わったとき、または複数の設備をまとめたときは、選び直す（未選択にする）
  if (primary !== form.value.equipment_id || ids.length > 1) form.value.instrument_id = null
  form.value.equipment_id = primary
  form.value.items.forEach((item) => {
    // 別の設備についての提案は、この点検のトラブルには結びつけない
    item.ai_suggestion_id = null
    if (item.equipment_id && !ids.includes(item.equipment_id)) item.equipment_id = null
  })
  await fetchInstruments()
}

// 判定を変える。不具合ありにしたら、トラブルの入力欄を開き、複数の設備をまとめた点検では、どの設備の不具合かを決める（初期値は代表の設備）
function setResult(item: any, value: ItemResult | null) {
  item.result = value
  if (value !== 'defect') return
  openedDefects.value.add(item)
  if (multipleEquipments.value && !item.equipment_id) item.equipment_id = form.value.equipment_ids[0]
}

function loadTemplate() {
  const tmpl = templates.value.find((t: any) => t.id === form.value.checklist_template_id)
  if (!tmpl) return
  if (form.value.items.length > 0 && !confirm('現在入力済みの点検項目は上書きされます。テンプレートから読み込みますか？')) return
  form.value.inspection_type = tmpl.inspection_type
  form.value.items = (tmpl.checklist_template_items || []).map((item: any) => ({
    checklist_template_item_id: item.id,
    content: item.content,
    item_type: item.item_type,
    ...criteriaOf(item),
    result: null,
    autoResult: false,
    measured_value: '',
    text_value: '',
    defect_title: '',
    defect_description: '',
    defect_priority: 'medium',
    ai_suggestion_id: null,
    equipment_id: null,
    instrument_id: null,
    calibration: item.item_type === 'calibration' ? emptyCalibrationInput() : null,
    calibration_snapshot: null,
  }))
}

function addItem() {
  form.value.items.push({
    content: '',
    item_type: 'check',
    ...criteriaOf({ item_type: 'check' }),
    result: null,
    autoResult: false,
    measured_value: '',
    text_value: '',
    defect_title: '',
    defect_description: '',
    defect_priority: 'medium',
    ai_suggestion_id: null,
    equipment_id: null,
    instrument_id: null,
    calibration: null,
    calibration_snapshot: null,
  })
}

function removeItem(idx: number) {
  if (!confirm('この点検項目と入力中のメモを削除しますか？')) return
  form.value.items.splice(idx, 1)
}

async function save(status?: string) {
  errors.value = []
  saving.value = true
  try {
    const payload = {
      inspection: {
        ...form.value,
        status: status || 'draft',
      }
    }
    if (isEdit.value) {
      await api.patch(`/inspections/${editId.value}`, payload)
    } else {
      await api.post('/inspections', payload)
    }
    saved.value = true
    router.push('/inspections')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  } finally {
    saving.value = false
  }
}

async function loadExisting() {
  if (!isEdit.value) return
  const res = await api.get(`/inspections/${editId.value}`)
  const data = res.data.data
  form.value = {
    equipment_ids: [data.equipment_id, ...(data.equipments || []).map((e: any) => e.id).filter((id: number) => id !== data.equipment_id)],
    equipment_id: data.equipment_id,
    instrument_id: data.instrument_id,
    department_id: data.department_id,
    checklist_template_id: data.checklist_template_id,
    inspection_plan_id: data.inspection_plan_id ?? null,
    maintenance_task_id: data.maintenance_task_id ?? null,
    inspection_type: data.inspection_type,
    inspected_at: data.inspected_at?.slice(0, 16) || '',
    notes: data.notes || '',
    reference_standards: (data.inspection_reference_standards || []).map((link: any) => ({
      reference_standard_id: link.reference_standard_id,
      pre_check_passed: link.pre_check_passed,
      pre_check_note: link.pre_check_note || '',
    })),
    items: (data.inspection_items || []).map((item: any) => ({
      id: item.id,
      checklist_template_item_id: item.checklist_template_item_id,
      content: item.content,
      item_type: item.item_type,
      ...criteriaOf(item),
      result: item.result ?? null,
      autoResult: false,
      measured_value: item.measured_value || '',
      text_value: item.text_value || '',
      defect_title: '',
      defect_description: '',
      defect_priority: 'medium',
      ai_suggestion_id: null,
      equipment_id: item.equipment_id ?? null,
      instrument_id: item.instrument_id,
      calibration: item.item_type === 'calibration' ? calibrationInputFrom(item.calibration_data) : null,
      calibration_snapshot: item.calibration_data?.snapshot ?? null,
    })),
  }
  await fetchInstruments()
}

// 点検計画の一覧（または定期整備の作業）から「点検を実施」で来たとき、設備・計器・テンプレートを引き継ぐ
async function prefillFromPlan() {
  if (isEdit.value || (!route.query.inspection_plan_id && !route.query.maintenance_task_id)) return
  const q = route.query
  if (q.inspection_plan_id) form.value.inspection_plan_id = Number(q.inspection_plan_id)
  if (q.maintenance_task_id) form.value.maintenance_task_id = Number(q.maintenance_task_id)
  form.value.equipment_id = q.equipment_id ? Number(q.equipment_id) : null
  // 複数の設備をまとめた計画（巡回など）は、その設備すべてを引き継ぐ（先頭が代表の設備）
  const planEquipmentIds = String(q.equipment_ids ?? '').split(',').map(Number).filter((id) => id > 0)
  form.value.equipment_ids = planEquipmentIds.length ? planEquipmentIds : form.value.equipment_id ? [form.value.equipment_id] : []
  form.value.equipment_id = form.value.equipment_ids[0] ?? null
  form.value.instrument_id = q.instrument_id ? Number(q.instrument_id) : null
  form.value.checklist_template_id = q.checklist_template_id ? Number(q.checklist_template_id) : null
  if (q.inspection_type) form.value.inspection_type = String(q.inspection_type)
  form.value.department_id = authStore.user?.department_id ?? null
  await fetchInstruments()
  form.value.instrument_id = q.instrument_id ? Number(q.instrument_id) : null
  if (form.value.checklist_template_id) loadTemplate()
}

// プラナからは計画IDを作らず、選んだ設備・計器と不具合の入力欄だけを用意する。
async function prefillFromPlana() {
  if (isEdit.value || route.query.plana !== 'defect-draft' || route.query.inspection_plan_id || route.query.maintenance_task_id) return
  const id = Number(route.query.equipment_id)
  if (!Number.isSafeInteger(id) || id <= 0) {
    errors.value = ['対象の設備を選んでください。']
    return
  }
  // 協力会社は所属拠点の選択肢だけを使う。URLの equipment_id を書き換えても
  // 他拠点の設備を読み込まず、API側の保存時検証と同じ境界にそろえる。
  if (authStore.user?.company?.company_type === 'contractor' && !equipments.value.some((equipment) => equipment.id === id)) {
    errors.value = ['所属拠点の設備を選んでください。']
    return
  }
  try {
    const res = await api.get(`/equipments/${id}`)
    await loadSiteOptions([res.data.data.site_id])
    form.value.equipment_id = id
    form.value.equipment_ids = [id]
    await fetchInstruments()
    const instrumentId = Number(route.query.instrument_id)
    form.value.instrument_id = instruments.value.some((instrument) => instrument.id === instrumentId) ? instrumentId : null
    addItem()
    form.value.items[0].content = '不具合の確認'
    setResult(form.value.items[0], 'defect')
  } catch {
    errors.value = ['プラナで選んだ設備を読み込めませんでした。設備を選び直して入力できます。']
  }
}

// 新規の点検記録の部署は、自分の所属部署を初期値にする（編集は記録の部署のまま。所属のない協力会社は未選択）
function defaultDepartment() {
  if (isEdit.value || form.value.department_id) return
  form.value.department_id = authStore.user?.department_id ?? null
}

onMounted(async () => {
  void fetchAiStatus()
  try {
    await fetchMasters()
    await loadExisting()
    await prefillFromPlan()
    await prefillFromPlana()
    defaultDepartment()
    await ensureOptionsCoverEquipment()
    await ensureDepartmentInOptions()
  } finally {
    initialForm.value = JSON.stringify(form.value)
    initializing.value = false
  }
})
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <v-btn icon="mdi-arrow-left" variant="text" aria-label="前の画面に戻る" @click="router.back()" />
      <h1 class="text-h5 ml-2">{{ isEdit ? '点検記録編集' : '新規点検記録' }}</h1>
    </div>

    <div v-if="initializing" role="status" aria-live="polite">
      <v-progress-linear indeterminate class="mb-3" />
      <p class="text-body-2 text-medium-emphasis">点検入力を準備しています。</p>
    </div>

    <template v-else>
      <v-alert v-if="form.maintenance_task_id" type="info" variant="tonal" density="compact" class="mb-4" data-testid="from-maintenance-task">
        定期整備の作業として実施する点検です。提出すると、その作業が完了になります。
      </v-alert>

      <v-alert v-if="route.query.plana === 'defect-draft'" type="info" variant="tonal" class="mb-4" data-testid="from-plana">
        対象を確認して、不具合欄に現場メモを入力してください。内容を確認・反映したあと、点検を保存するとトラブルが登録されます。
      </v-alert>

      <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
        <div v-for="err in errors" :key="err">{{ err }}</div>
      </v-alert>

      <v-card class="mb-4">
        <v-card-text>
          <v-row>
            <v-col cols="12" md="6">
              <v-select
                v-model="form.equipment_ids"
                :items="equipments"
                item-title="name"
                item-value="id"
                label="設備 *"
                multiple
                chips
                closable-chips
                hint="複数の設備をまとめて点検できます（同じ拠点の設備。最初に選んだ設備が代表になります）"
                persistent-hint
                @update:model-value="onEquipmentChange"
              />
            </v-col>
            <v-col v-if="!multipleEquipments" cols="12" md="6">
              <v-select
                v-model="form.instrument_id"
                :items="instruments"
                item-title="tag_number"
                item-value="id"
                label="計器（任意）"
                clearable
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-select
                v-model="form.department_id"
                :items="departments"
                item-title="display_name"
                item-value="id"
                label="部署 *"
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model="form.inspected_at"
                label="点検日時 *"
                type="datetime-local"
              />
            </v-col>
            <v-col cols="12" md="6">
              <div class="d-flex ga-2 align-center">
                <v-select
                  v-model="form.checklist_template_id"
                  :items="templateOptions"
                  item-title="name"
                  item-value="id"
                  label="テンプレート（任意）"
                  clearable
                  @update:model-value="loadTemplate"
                />
                <v-btn
                  v-if="form.checklist_template_id"
                  variant="outlined"
                  size="small"
                  prepend-icon="mdi-refresh"
                  @click="loadTemplate"
                >
                  項目を読込
                </v-btn>
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <v-select
                v-model="form.inspection_type"
                :items="inspectionTypeOptions"
                item-title="title"
                item-value="value"
                label="点検種別"
              />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.notes" label="備考" rows="2" />
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <InspectionReferenceStandards
        v-model="form.reference_standards"
        :standards="referenceStandards"
        :inspection-date="form.inspected_at.slice(0, 10)"
        :require-traceable="requireTraceable"
      />

      <div class="d-flex align-center mb-3">
        <h2 class="text-h6">点検項目</h2>
        <v-spacer />
        <v-btn size="small" variant="outlined" prepend-icon="mdi-plus" @click="addItem">項目追加</v-btn>
      </div>

      <template v-for="(item, idx) in form.items" :key="itemKey(item)">
        <h3 v-if="startsSection(form.items, idx)" class="pk-item-section">{{ item.section }}</h3>
        <v-card class="mb-3 pk-item" :class="{ 'pk-item--defect': isDefect(item) }" variant="outlined" :data-testid="`inspection-item-${idx + 1}`">
          <v-card-text>
            <div class="d-flex align-start ga-3 mb-2">
              <span class="text-subtitle-2 text-no-wrap pk-item-number">項目 {{ idx + 1 }}</span>
              <!-- テンプレートの項目は、内容と基準をそのまま示す（基準は現場で変えない） -->
              <div v-if="item.checklist_template_item_id" class="flex-grow-1">
                <div class="pk-item-content">
                  <span>{{ item.content }}</span><span v-if="item.required" class="pk-item-required" title="必須">必須</span>
                </div>
                <div v-if="item.criterion || limitsText(item)" class="pk-item-criterion">
                  <span class="pk-item-criterion__label">基準</span>{{ item.criterion }}
                  <span v-if="limitsText(item)" class="pk-item-criterion__range">許容範囲 {{ limitsText(item) }}</span>
                </div>
              </div>
              <v-spacer v-else />
              <v-btn icon="mdi-close" size="x-small" variant="text" :aria-label="`項目 ${idx + 1} を削除`" @click="removeItem(idx)" />
            </div>
            <v-row v-if="!item.checklist_template_item_id" dense>
              <v-col cols="12" md="6">
                <v-text-field v-model="item.content" label="内容" density="compact" />
              </v-col>
              <v-col cols="6" md="3">
                <v-select v-model="item.item_type" :items="itemTypeOptions.filter((o) => o.value !== 'choice')" item-title="title" item-value="value" label="種別" density="compact" @update:model-value="ensureCalibration(item)" />
              </v-col>
              <v-col v-if="item.item_type === 'measurement'" cols="6" md="3">
                <v-text-field v-model="item.unit" label="単位（任意）" density="compact" />
              </v-col>
            </v-row>
            <v-row dense align="center">
              <v-col v-if="item.item_type === 'measurement'" cols="12" md="4">
                <v-text-field
                  v-model="item.measured_value"
                  label="測定値"
                  :suffix="item.unit || undefined"
                  inputmode="decimal"
                  density="compact"
                  :error-messages="measurementMessage(item)"
                  @update:model-value="onMeasuredInput(item)"
                />
              </v-col>
              <v-col v-else-if="item.item_type === 'choice'" cols="12" md="4">
                <v-select v-model="item.text_value" :items="item.options || []" label="選択" density="compact" clearable />
              </v-col>
              <v-col v-else-if="item.item_type === 'text'" cols="12" md="4">
                <v-text-field v-model="item.text_value" label="記入" density="compact" />
              </v-col>
              <v-col cols="12" md class="pb-3">
                <ItemResultToggle
                  :model-value="item.result"
                  :judged="isJudgedType(item.item_type)"
                  :good-disabled="outOfRange(item)"
                  @update:model-value="onResultInput(item, $event)"
                />
              </v-col>
              <v-col cols="12" md="3">
                <v-select v-model="item.instrument_id" :items="instrumentsFor(item)" item-title="tag_number" item-value="id" label="計器" density="compact" clearable />
              </v-col>
            </v-row>
            <v-row v-if="item.item_type === 'calibration' && item.calibration" dense class="mt-1">
              <v-col cols="12">
                <CalibrationTable v-model="item.calibration" :snapshot="snapshotFor(item)" />
              </v-col>
            </v-row>
            <v-expand-transition>
              <div v-if="isDefect(item) || openedDefects.has(item)" v-show="isDefect(item)" class="mt-1">
                <AiAvailability :status="aiStatus" :loading="aiLoading" :failed="aiFailed" @retry="fetchAiStatus" />
                <div v-if="defectInstrumentFor(item)?.troubleshooting_checks?.length" class="pk-reference" data-testid="routine-checks">
                  <h4><v-icon size="16" aria-hidden="true">mdi-clipboard-text-outline</v-icon>この計器の一次点検の定型項目</h4>
                  <p class="pk-reference-meta">参考。手順書・保全基準の代わりではありません<template v-if="defectInstrumentFor(item)?.seal_fluid">／シール液: {{ defectInstrumentFor(item)?.seal_fluid }}</template></p>
                  <ul><li v-for="c in defectInstrumentFor(item)?.troubleshooting_checks" :key="c">{{ c }}</li></ul>
                </div>
                <v-row v-if="multipleEquipments" dense>
                  <v-col cols="12" md="5">
                    <v-select
                      v-model="item.equipment_id"
                      :items="selectedEquipments"
                      item-title="name"
                      item-value="id"
                      label="不具合の設備 *"
                      density="compact"
                      color="error"
                    />
                  </v-col>
                </v-row>
                <div class="defect-workspace" :class="{ 'defect-workspace--assisted': aiStatus?.enabled }">
                  <section v-if="aiStatus?.enabled" class="defect-workspace__draft" :aria-labelledby="`defect-draft-heading-${idx}`">
                    <h3 :id="`defect-draft-heading-${idx}`">メモをプラナに整理してもらう</h3>
                    <p class="defect-workspace__hint">現場で見たことを入力してください。整理した内容と過去の事例を確認できます。</p>
                    <DefectAiAssist
                      :status="aiStatus"
                      :equipment-id="item.equipment_id ?? form.equipment_id"
                      :instrument-id="item.instrument_id ?? (multipleEquipments ? null : form.instrument_id)"
                      :item-label="item.content"
                      :has-existing="!!item.defect_title"
                      @dirty="markMemo(item, $event)"
                      @apply="applyAiDraft(item, $event, idx)"
                      @remaining="aiStatus.remaining_today = $event"
                    />
                  </section>
                  <section :id="`defect-record-${idx}`" class="defect-workspace__record" :aria-labelledby="`defect-record-heading-${idx}`">
                    <h3 :id="`defect-record-heading-${idx}`">報告する内容</h3>
                    <p class="defect-workspace__hint">直接入力・編集できます。点検の保存時にトラブルとして登録されます。</p>
                    <v-row dense>
                      <v-col cols="12">
                        <v-text-field v-model="item.defect_title" label="トラブルタイトル" density="compact" color="error" />
                      </v-col>
                      <v-col cols="12">
                        <v-textarea v-model="item.defect_description" label="説明" rows="3" auto-grow density="compact" />
                      </v-col>
                      <v-col cols="12">
                        <v-select
                          v-model="item.defect_priority"
                          :items="[{ title: '低', value: 'low' }, { title: '中', value: 'medium' }, { title: '高', value: 'high' }, { title: '緊急', value: 'critical' }]"
                          item-title="title"
                          item-value="value"
                          label="優先度"
                          density="compact"
                        />
                      </v-col>
                    </v-row>
                  </section>
                </div>
              </div>
            </v-expand-transition>
          </v-card-text>
        </v-card>
      </template>

      <p v-if="missingRequired" class="text-body-2 text-medium-emphasis text-right mt-4 mb-0" data-testid="missing-required">
        未記入の必須項目が {{ missingRequired }}件あります（下書きは保存できます）
      </p>
      <div class="d-flex ga-3 mt-4">
        <v-btn @click="router.back()">キャンセル</v-btn>
        <v-spacer />
        <v-btn variant="outlined" :loading="saving" @click="save('draft')">下書き保存</v-btn>
        <v-btn color="primary" :loading="saving" @click="save('submitted')">提出</v-btn>
      </div>
    </template>
  </MainLayout>
</template>

<style scoped>
/* 参考知識（計器種別ごとの一次点検の定型項目）。AIの有効・無効に関わらず表示するため、
   defect-workspace（AIが有効なときだけの区画）の外に置く */
.pk-reference { border-left: 3px solid var(--pk-steel); background: var(--pk-mist); border-radius: 0 10px 10px 0; padding: 12px 16px; margin: 12px 0; }
.pk-reference h4 { display: flex; align-items: center; gap: 8px; font-size: .8125rem; font-weight: 700; color: var(--pk-ink); margin: 0; }
.pk-reference-meta { font-size: .6875rem; color: var(--pk-muted); margin: 4px 0 10px 24px; }
.pk-reference ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
.pk-reference li { position: relative; padding-left: 15px; font-size: .8125rem; line-height: 1.7; color: var(--pk-muted); }
.pk-reference li::before { content: ''; position: absolute; left: 1px; top: .6em; width: 5px; height: 5px; background: var(--pk-steel); transform: rotate(45deg); }
.pk-item-section { font-size: .875rem; font-weight: 700; color: var(--pk-ink); margin: 20px 0 8px; padding-left: 10px; border-left: 3px solid var(--pk-steel); }
.pk-item--defect { border-color: rgb(var(--v-theme-error)) !important; }
.pk-item-number { color: var(--pk-muted); padding-top: 2px; }
.pk-item-content { font-weight: 600; line-height: 1.6; }
.pk-item-required { white-space: nowrap; margin-left: 8px; font-size: .6875rem; font-weight: 700; color: var(--pk-amber); border: 1px solid currentColor; border-radius: 4px; padding: 0 4px; vertical-align: 1px; }
.pk-item-criterion { font-size: .8125rem; line-height: 1.7; color: var(--pk-muted); margin-top: 2px; }
.pk-item-criterion__label { font-size: .6875rem; font-weight: 700; color: var(--pk-steel); background: var(--pk-soft-blue); border-radius: 4px; padding: 1px 6px; margin-right: 6px; }
.pk-item-criterion__range { margin-left: 8px; font-family: var(--pk-font-mono); font-size: .75rem; color: var(--pk-ink); white-space: nowrap; }
.defect-workspace { display: grid; gap: 24px; margin-top: 16px; }
.defect-workspace h3 { font-size: 1rem; margin-bottom: 8px; color: var(--pk-plana-navy); }
.defect-workspace__hint { font-size: 0.8125rem; line-height: 1.7; color: var(--pk-muted); margin-bottom: 20px; }
.defect-workspace__draft { min-width: 0; padding: 20px; background: var(--pk-mist); border: 1px solid var(--pk-line); border-radius: 12px; }
.defect-workspace__record { min-width: 0; padding-top: 20px; scroll-margin-top: 64px; }
@media (min-width: 960px) {
  .defect-workspace--assisted { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: start; }
}
</style>
