<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import DiagnosticChip from '@/components/DiagnosticChip.vue'
import FilterResetButton from '@/components/FilterResetButton.vue'
import FilterSelect from '@/components/FilterSelect.vue'
import InstrumentCalibrationFields from '@/components/InstrumentCalibrationFields.vue'
import ListCount from '@/components/ListCount.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { hasQueryConditions, useSavedFilters } from '@/composables/useSavedFilters'
import { usePermissions } from '@/composables/usePermissions'
import { inSites, keepInSites, useSiteScope } from '@/composables/useSiteScope'
import { calibrationFieldsFrom, calibrationFieldsPayload, emptyCalibrationFields, type CalibrationFields } from '@/utils/calibration'
import { latestGuard } from '@/utils/latestGuard'
import { listFromQuery } from '@/utils/listQuery'
import { DIAGNOSTIC_FILTER_OPTIONS } from '@/constants/diagnostics'

const router = useRouter()
const route = useRoute()
const { canManageEquipment } = usePermissions()
const { initialSiteIds, savedSiteIds, ownSiteIds } = useSiteScope()

const instruments = ref<any[]>([])
const equipments = ref<any[]>([])
const services = ref<any[]>([])
const lineClasses = ref<any[]>([])
const loading = ref(false)
const loadError = ref(false)
const totalCount = ref<number | null>(null)

// フィルタ（すべて複数選択）。条件は保存して、開き直したときに戻す
type Filters = { site_ids: number[]; q: string; equipment_ids: number[]; service_ids: number[]; line_class_ids: number[]; diagnostic_statuses: string[] }
const saved = useSavedFilters<Filters>('instruments', {
  site_ids: 'ids',
  q: { type: 'string' },
  equipment_ids: 'ids',
  service_ids: 'ids',
  line_class_ids: 'ids',
  diagnostic_statuses: { type: 'strings', values: DIAGNOSTIC_FILTER_OPTIONS.map((o) => o.value) },
})

// 通常業務では自拠点だけ意識すればよいため、自分の所属拠点をデフォルト選択（＋保存した条件）。
// ほかの画面のリンクで拠点・機器の診断の状態（?diagnostic_status=failure,out_of_specification）を指定されたときは、保存した条件を混ぜない
function initialFilters(): Filters {
  if (hasQueryConditions(route.query)) {
    return {
      site_ids: initialSiteIds(route.query.site_ids), q: '', equipment_ids: [], service_ids: [], line_class_ids: [],
      diagnostic_statuses: listFromQuery(route.query.diagnostic_status),
    }
  }
  const stored = saved.load()
  return { q: '', equipment_ids: [], service_ids: [], line_class_ids: [], diagnostic_statuses: [], ...stored, site_ids: savedSiteIds(stored.site_ids) }
}
const initial = initialFilters()
const search = ref(initial.q)
const selectedSiteIds = ref<number[]>(initial.site_ids)
const selectedEquipmentIds = ref<number[]>(initial.equipment_ids)
const selectedServiceIds = ref<number[]>(initial.service_ids)
const selectedLineClassIds = ref<number[]>(initial.line_class_ids)
const selectedDiagnosticStatuses = ref<string[]>(initial.diagnostic_statuses)
saved.hold(initial)

const currentFilters = computed<Filters>(() => ({
  site_ids: selectedSiteIds.value,
  q: search.value ?? '',
  equipment_ids: selectedEquipmentIds.value,
  service_ids: selectedServiceIds.value,
  line_class_ids: selectedLineClassIds.value,
  diagnostic_statuses: selectedDiagnosticStatuses.value,
}))

// 保存した条件とURLの検索条件を消し、既定（自拠点・絞り込みなし）に戻す
// 表のページ（リセットで先頭に戻す）
const tablePage = ref(1)

function reset() {
  tablePage.value = 1
  saved.clear()
  saved.clearQuery()
  const next: Filters = { site_ids: ownSiteIds(), q: '', equipment_ids: [], service_ids: [], line_class_ids: [], diagnostic_statuses: [] }
  saved.hold(next)
  selectedSiteIds.value = next.site_ids
  search.value = ''
  selectedEquipmentIds.value = []
  selectedServiceIds.value = []
  selectedLineClassIds.value = []
  selectedDiagnosticStatuses.value = []
}

// 拠点で絞り込んだ設備リスト
const filteredEquipments = computed(() => equipments.value.filter((e: any) => inSites(selectedSiteIds.value, e.site_id)))

// 作成/編集ダイアログ
const dialog = ref(false)
const editingId = ref<number | null>(null)
const form = ref({
  equipment_id: null as number | null,
  tag_number: '',
  instrument_type: '',
  service_id: null as number | null,
  line_class_id: null as number | null,
  location: '',
  notes: '',
  seal_fluid: '',
})
const calibrationForm = ref<CalibrationFields>(emptyCalibrationFields())
const errors = ref<string[]>([])

const headers = [
  { title: 'タグナンバー', key: 'tag_number', minWidth: '120px' },
  { title: '診断', key: 'diagnostic_status', sortable: false },
  { title: '設備', key: 'equipment.name', minWidth: '160px' },
  { title: 'サービス', key: 'service.name' },
  { title: '種別', key: 'instrument_type' },
  { title: '区分', key: 'flags', sortable: false },
  { title: '設置場所', key: 'location' },
  { title: 'ラインクラス', key: 'line_class.code' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
]

const fetchInstrumentsGuard = latestGuard()

async function fetchInstruments() {
  const isLatest = fetchInstrumentsGuard()
  loading.value = true
  loadError.value = false
  try {
    const params: any = { per_page: 1000 }
    if (search.value) params.q = search.value
    if (selectedSiteIds.value.length) params.site_ids = selectedSiteIds.value
    if (selectedEquipmentIds.value.length) params.equipment_ids = selectedEquipmentIds.value
    if (selectedServiceIds.value.length) params.service_ids = selectedServiceIds.value
    if (selectedLineClassIds.value.length) params.line_class_ids = selectedLineClassIds.value
    if (selectedDiagnosticStatuses.value.length) params.diagnostic_statuses = selectedDiagnosticStatuses.value
    const res = await api.get('/instruments', { params })
    if (!isLatest()) return
    instruments.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } catch {
    if (isLatest()) loadError.value = true
  } finally {
    if (isLatest()) loading.value = false
  }
}

async function fetchMasters() {
  const [eqRes, svcRes, lcRes] = await Promise.all([
    api.get('/equipments', { params: { per_page: 1000 } }),
    api.get('/services'),
    api.get('/line_classes'),
  ])
  equipments.value = eqRes.data.data
  services.value = svcRes.data.data
  lineClasses.value = lcRes.data.data
  // 保存した条件のうち、選択肢にないもの（削除・無効になったもの、表示する拠点にない設備）は外す
  const known = (ids: number[], options: { id: number }[]) => ids.filter((id) => options.some((o) => o.id === id))
  const prune = (selected: { value: number[] }, kept: number[]) => { if (kept.length !== selected.value.length) selected.value = kept }
  prune(selectedEquipmentIds, keepInSites(selectedEquipmentIds.value, equipments.value, selectedSiteIds.value))
  prune(selectedServiceIds, known(selectedServiceIds.value, services.value))
  prune(selectedLineClassIds, known(selectedLineClassIds.value, lineClasses.value))
}

function openCreate() {
  editingId.value = null
  form.value = {
    equipment_id: selectedEquipmentIds.value.length === 1 ? (selectedEquipmentIds.value[0] ?? null) : null,
    tag_number: '', instrument_type: '',
    service_id: selectedServiceIds.value.length === 1 ? (selectedServiceIds.value[0] ?? null) : null,
    line_class_id: selectedLineClassIds.value.length === 1 ? (selectedLineClassIds.value[0] ?? null) : null,
    location: '', notes: '', seal_fluid: '',
  }
  calibrationForm.value = emptyCalibrationFields()
  errors.value = []
  dialog.value = true
}

function openEdit(item: any) {
  editingId.value = item.id
  form.value = {
    equipment_id: item.equipment_id,
    tag_number: item.tag_number,
    instrument_type: item.instrument_type || '',
    service_id: item.service_id ?? null,
    line_class_id: item.line_class_id ?? null,
    location: item.location || '',
    notes: item.notes || '',
    seal_fluid: item.seal_fluid || '',
  }
  calibrationForm.value = calibrationFieldsFrom(item)
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  const payload = { ...form.value, ...calibrationFieldsPayload(calibrationForm.value) }
  try {
    if (editingId.value) {
      await api.patch(`/instruments/${editingId.value}`, { instrument: payload })
    } else {
      await api.post('/instruments', { instrument: payload })
    }
    dialog.value = false
    await fetchInstruments()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function goToDetail(row: any) {
  router.push(`/instruments/${row.id}`)
}

watch(currentFilters, (value) => saved.save(value))
let searchTimeout: ReturnType<typeof setTimeout>
watch(search, () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(fetchInstruments, 300)
})
// 拠点変更時: その拠点に属さない設備選択を解除
watch(selectedSiteIds, (newIds) => {
  selectedEquipmentIds.value = keepInSites(selectedEquipmentIds.value, equipments.value, newIds)
  fetchInstruments()
}, { deep: true })
watch([selectedEquipmentIds, selectedServiceIds, selectedLineClassIds, selectedDiagnosticStatuses], () => {
  fetchInstruments()
}, { deep: true })

onMounted(() => {
  fetchMasters()
  fetchInstruments()
})
</script>

<template>
  <MainLayout>
    <!-- ヘッダー -->
    <PageHeader title="装置・計器" description="設備に付いている計器をタグ番号で探します。サービス（流体）やラインクラスなどの仕様を確認できます。">
      <v-btn v-if="canManageEquipment" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規登録</v-btn>
    </PageHeader>

    <!-- フィルタパネル -->
    <div class="pk-filters">
      <SiteScopeTag v-model="selectedSiteIds" />
      <v-divider vertical class="pk-scope-divider" />
      <v-text-field
        v-model="search"
        label="タグ番号・種別・設置場所"
        prepend-inner-icon="mdi-magnify"
        clearable
        density="compact"
        hide-details
        class="pk-filter-search"
      />
      <FilterSelect v-model="selectedEquipmentIds" :items="filteredEquipments" item-title="name" item-value="id" label="設備" searchable />
      <FilterSelect v-model="selectedServiceIds" :items="services" item-title="name" item-value="id" label="サービス・流体" searchable wide />
      <FilterSelect v-model="selectedLineClassIds" :items="lineClasses" item-title="code" item-value="id" label="ラインクラス" searchable />
      <FilterSelect v-model="selectedDiagnosticStatuses" :items="DIAGNOSTIC_FILTER_OPTIONS" label="機器の診断" data-testid="diagnostic-filter" />
      <FilterResetButton @reset="reset" />
    </div>

    <ListCount :total="totalCount" :shown="instruments.length" :loading="loading" :error="loadError" />

    <!-- テーブル -->
    <v-data-table
      v-model:page="tablePage"
      :headers="headers"
      :items="instruments"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.tag_number="{ item }"><span class="text-no-wrap">{{ item.tag_number }}</span></template>
      <template #item.service.name="{ item }">{{ item.service?.name || '—' }}</template>
      <template #item.instrument_type="{ item }">{{ item.instrument_type || '—' }}</template>
      <template #item.location="{ item }">{{ item.location || '—' }}</template>
      <template #item.line_class.code="{ item }">{{ item.line_class?.code || '—' }}</template>
      <template #item.flags="{ item }">
        <v-chip v-if="item.telemetry" size="x-small" label color="indigo" variant="tonal" class="mr-1">テレメータ</v-chip>
        <v-chip v-if="item.custody_transfer" size="x-small" label color="brown" variant="tonal" class="mr-1">取引用</v-chip>
      </template>
      <template #item.diagnostic_status="{ item }">
        <DiagnosticChip :status="item.diagnostic_status" size="x-small" />
      </template>
      <template #item.actions="{ item }">
        <v-btn v-if="canManageEquipment" icon="mdi-pencil" size="x-small" variant="text" :aria-label="`${item.tag_number}を編集`" @click.stop="openEdit(item)" />
      </template>
    </v-data-table>

    <!-- 作成・編集ダイアログ -->
    <v-dialog v-model="dialog" max-width="720" scrollable>
      <v-card>
        <v-card-title>{{ editingId ? '計器の編集' : '計器の登録' }}</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select v-model="form.equipment_id" :items="equipments" item-title="name" item-value="id" label="設備" class="mb-2" />
          <v-text-field v-model="form.tag_number" label="タグナンバー" class="mb-2" />
          <v-text-field v-model="form.instrument_type" label="種別" class="mb-2" />
          <v-select v-model="form.service_id" :items="services" item-title="name" item-value="id" label="サービス・流体" clearable class="mb-2" />
          <v-select v-model="form.line_class_id" :items="lineClasses" item-title="code" item-value="id" label="ラインクラス" clearable class="mb-2" />
          <v-text-field v-model="form.location" label="設置場所" class="mb-2" />
          <v-text-field v-model="form.seal_fluid" label="シール液（任意。ダイアフラムシール式などで使用）" class="mb-2" />
          <v-textarea v-model="form.notes" label="備考" rows="2" />
          <InstrumentCalibrationFields v-model="calibrationForm" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" variant="flat" @click="save">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
