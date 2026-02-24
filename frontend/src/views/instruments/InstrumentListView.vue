<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'

const router = useRouter()
const { canManageEquipment } = usePermissions()

const instruments = ref<any[]>([])
const sites = ref<any[]>([])
const equipments = ref<any[]>([])
const services = ref<any[]>([])
const lineClasses = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)
const perPage = 50

// フィルタ（すべて複数選択）
const search = ref('')
const selectedSiteIds = ref<number[]>([])
const selectedEquipmentIds = ref<number[]>([])
const selectedServiceIds = ref<number[]>([])
const selectedLineClassIds = ref<number[]>([])

// 拠点で絞り込んだ設備リスト
const filteredEquipments = computed(() => {
  if (!selectedSiteIds.value.length) return equipments.value
  return equipments.value.filter((e: any) => selectedSiteIds.value.includes(e.site_id))
})

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
})
const errors = ref<string[]>([])

const headers = [
  { title: 'タグナンバー', key: 'tag_number' },
  { title: '種別', key: 'instrument_type' },
  { title: '設備', key: 'equipment.name' },
  { title: 'サービス', key: 'service.name' },
  { title: 'ラインクラス', key: 'line_class.code' },
  { title: '設置場所', key: 'location' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
]

// アクティブフィルタチップ
const activeFilterChips = computed(() => {
  const chips: { key: string; label: string }[] = []
  if (selectedSiteIds.value.length) {
    const names = selectedSiteIds.value.map(id => sites.value.find(s => s.id === id)?.name).filter(Boolean)
    chips.push({ key: 'site', label: `拠点: ${names.join('、')}` })
  }
  if (selectedEquipmentIds.value.length) {
    const names = selectedEquipmentIds.value.map(id => equipments.value.find(e => e.id === id)?.name).filter(Boolean)
    chips.push({ key: 'equipment', label: `設備: ${names.join('、')}` })
  }
  if (selectedServiceIds.value.length) {
    const names = selectedServiceIds.value.map(id => services.value.find(s => s.id === id)?.name).filter(Boolean)
    chips.push({ key: 'service', label: `サービス: ${names.join('、')}` })
  }
  if (selectedLineClassIds.value.length) {
    const codes = selectedLineClassIds.value.map(id => lineClasses.value.find(l => l.id === id)?.code).filter(Boolean)
    chips.push({ key: 'lineClass', label: `ラインクラス: ${codes.join('、')}` })
  }
  return chips
})

const hasActiveFilters = computed(
  () => !!search.value || selectedSiteIds.value.length > 0 || selectedEquipmentIds.value.length > 0
    || selectedServiceIds.value.length > 0 || selectedLineClassIds.value.length > 0
)

function clearFilters() {
  search.value = ''
  selectedSiteIds.value = []
  selectedEquipmentIds.value = []
  selectedServiceIds.value = []
  selectedLineClassIds.value = []
  page.value = 1
}

function removeChip(key: string) {
  if (key === 'site') { selectedSiteIds.value = []; selectedEquipmentIds.value = [] }
  if (key === 'equipment') selectedEquipmentIds.value = []
  if (key === 'service') selectedServiceIds.value = []
  if (key === 'lineClass') selectedLineClassIds.value = []
}

async function fetchInstruments() {
  loading.value = true
  try {
    const params: any = { page: page.value, per_page: perPage }
    if (search.value) params.q = search.value
    if (selectedSiteIds.value.length) params['site_ids[]'] = selectedSiteIds.value
    if (selectedEquipmentIds.value.length) params['equipment_ids[]'] = selectedEquipmentIds.value
    if (selectedServiceIds.value.length) params['service_ids[]'] = selectedServiceIds.value
    if (selectedLineClassIds.value.length) params['line_class_ids[]'] = selectedLineClassIds.value
    const res = await api.get('/instruments', { params })
    instruments.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

async function fetchMasters() {
  const [siteRes, eqRes, svcRes, lcRes] = await Promise.all([
    api.get('/sites', { params: { per_page: 100, is_active: true } }),
    api.get('/equipments', { params: { per_page: 200 } }),
    api.get('/services'),
    api.get('/line_classes'),
  ])
  sites.value = siteRes.data.data
  equipments.value = eqRes.data.data
  services.value = svcRes.data.data
  lineClasses.value = lcRes.data.data
}

function openCreate() {
  editingId.value = null
  form.value = {
    equipment_id: selectedEquipmentIds.value.length === 1 ? (selectedEquipmentIds.value[0] ?? null) : null,
    tag_number: '', instrument_type: '',
    service_id: selectedServiceIds.value.length === 1 ? (selectedServiceIds.value[0] ?? null) : null,
    line_class_id: selectedLineClassIds.value.length === 1 ? (selectedLineClassIds.value[0] ?? null) : null,
    location: '', notes: '',
  }
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
  }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    if (editingId.value) {
      await api.patch(`/instruments/${editingId.value}`, { instrument: form.value })
    } else {
      await api.post('/instruments', { instrument: form.value })
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

let searchTimeout: ReturnType<typeof setTimeout>
watch(search, () => {
  clearTimeout(searchTimeout)
  page.value = 1
  searchTimeout = setTimeout(fetchInstruments, 300)
})
// 拠点変更時: その拠点に属さない設備選択を解除
watch(selectedSiteIds, (newIds) => {
  if (newIds.length) {
    selectedEquipmentIds.value = selectedEquipmentIds.value.filter(
      id => newIds.includes(equipments.value.find((e: any) => e.id === id)?.site_id)
    )
  }
  page.value = 1
  fetchInstruments()
}, { deep: true })
watch([selectedEquipmentIds, selectedServiceIds, selectedLineClassIds], () => {
  page.value = 1
  fetchInstruments()
}, { deep: true })
watch(page, fetchInstruments)

onMounted(() => {
  fetchMasters()
  fetchInstruments()
})
</script>

<template>
  <MainLayout>
    <!-- ヘッダー -->
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">装置・計器</h1>
      <v-spacer />
      <v-btn v-if="canManageEquipment" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規作成</v-btn>
    </div>

    <!-- フィルタパネル -->
    <v-card variant="tonal" class="mb-3 pa-3">
      <div class="d-flex ga-3 flex-wrap align-center">
        <v-text-field
          v-model="search"
          label="タグ番号・種別・設置場所"
          prepend-inner-icon="mdi-magnify"
          clearable
          density="compact"
          hide-details
          style="min-width: 200px; max-width: 260px"
        />
        <v-autocomplete
          v-model="selectedSiteIds"
          :items="sites"
          item-title="name"
          item-value="id"
          label="拠点"
          multiple
          chips
          closable-chips
          clearable
          density="compact"
          hide-details
          style="min-width: 160px; max-width: 260px"
        />
        <v-autocomplete
          v-model="selectedEquipmentIds"
          :items="filteredEquipments"
          item-title="name"
          item-value="id"
          label="設備"
          multiple
          chips
          closable-chips
          clearable
          density="compact"
          hide-details
          style="min-width: 200px; max-width: 320px"
        />
        <v-autocomplete
          v-model="selectedServiceIds"
          :items="services"
          item-title="name"
          item-value="id"
          label="サービス・流体"
          multiple
          chips
          closable-chips
          clearable
          density="compact"
          hide-details
          style="min-width: 160px; max-width: 260px"
        />
        <v-autocomplete
          v-model="selectedLineClassIds"
          :items="lineClasses"
          item-title="code"
          item-value="id"
          label="ラインクラス"
          multiple
          chips
          closable-chips
          clearable
          density="compact"
          hide-details
          style="min-width: 160px; max-width: 260px"
        />
        <v-btn
          v-if="hasActiveFilters"
          variant="text"
          size="small"
          color="grey"
          prepend-icon="mdi-filter-off"
          @click="clearFilters"
        >
          クリア
        </v-btn>
      </div>

      <!-- アクティブフィルタチップ -->
      <div v-if="activeFilterChips.length" class="d-flex ga-2 mt-2 flex-wrap">
        <v-chip
          v-for="chip in activeFilterChips"
          :key="chip.key"
          size="small"
          closable
          color="primary"
          variant="tonal"
          @click:close="removeChip(chip.key)"
        >
          {{ chip.label }}
        </v-chip>
      </div>
    </v-card>

    <!-- 件数表示 -->
    <div class="text-caption text-grey mb-2">{{ totalCount }}件</div>

    <!-- テーブル -->
    <v-data-table
      :headers="headers"
      :items="instruments"
      :loading="loading"
      hover
      hide-default-footer
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.actions="{ item }">
        <v-btn v-if="canManageEquipment" icon="mdi-pencil" size="x-small" variant="text" @click.stop="openEdit(item)" />
      </template>
    </v-data-table>

    <!-- ページネーション -->
    <div v-if="totalCount > perPage" class="d-flex justify-center mt-4">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / perPage)" />
    </div>

    <!-- 作成・編集ダイアログ -->
    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editingId ? '計器編集' : '計器作成' }}</v-card-title>
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
          <v-textarea v-model="form.notes" label="備考" rows="2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="save">保存</v-btn>
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
