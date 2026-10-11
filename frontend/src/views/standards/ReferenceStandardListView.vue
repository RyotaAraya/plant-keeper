<script setup lang="ts">
import { computed, ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import StatusChip from '@/components/StatusChip.vue'
import CalibrationStateChip from '@/components/CalibrationStateChip.vue'
import FilterResetButton from '@/components/FilterResetButton.vue'
import FilterSelect from '@/components/FilterSelect.vue'
import ListCount from '@/components/ListCount.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import ReferenceStandardFormDialog from '@/components/ReferenceStandardFormDialog.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { hasQueryConditions, useSavedFilters } from '@/composables/useSavedFilters'
import { usePermissions } from '@/composables/usePermissions'
import { useSiteScope } from '@/composables/useSiteScope'
import type { ReferenceStandard } from '@/types/models'
import { formatDay } from '@/utils/datetime'
import { latestGuard } from '@/utils/latestGuard'
import { CATEGORY_LABEL, STATUS_COLOR, STATUS_LABEL } from '@/utils/referenceStandard'

const route = useRoute()
const router = useRouter()
const { canManageReferenceStandard } = usePermissions()
const { initialSiteIds, savedSiteIds, ownSiteIds } = useSiteScope()

const standards = ref<ReferenceStandard[]>([])
const loading = ref(false)
const loadError = ref(false)
const totalCount = ref<number | null>(null)
const statusOptions = Object.entries(STATUS_LABEL).map(([value, title]) => ({ title, value }))
const categoryOptions = Object.entries(CATEGORY_LABEL).map(([value, title]) => ({ title, value }))

// 条件は保存して、開き直したときに戻す（ほかの画面のリンクで拠点を指定されたときは、保存した条件を混ぜない）
type Filters = { site_ids: number[]; statuses: string[]; categories: string[]; q: string }
const saved = useSavedFilters<Filters>('reference-standards', {
  site_ids: 'ids',
  statuses: { type: 'strings', values: statusOptions.map((o) => o.value) },
  categories: { type: 'strings', values: categoryOptions.map((o) => o.value) },
  q: { type: 'string' },
})
const defaults = (siteIds: number[]): Filters => ({ site_ids: siteIds, statuses: [], categories: [], q: '' })
function initialFilters(): Filters {
  if (hasQueryConditions(route.query)) return defaults(initialSiteIds(route.query.site_ids))
  const stored = saved.load()
  return { ...defaults([]), ...stored, site_ids: savedSiteIds(stored.site_ids) }
}
const initial = initialFilters()
saved.hold(initial)
// 通常業務では自拠点の基準器だけ見ればよいため、自分の所属拠点を初期値にする（複数選択、空は全拠点）
const selectedSiteIds = ref<number[]>(initial.site_ids)
const statuses = ref<string[]>(initial.statuses)
const categories = ref<string[]>(initial.categories)
const search = ref(initial.q)
const currentFilters = computed<Filters>(() => ({ site_ids: selectedSiteIds.value, statuses: statuses.value, categories: categories.value, q: search.value ?? '' }))

// 保存した条件とURLの検索条件を消し、既定（自拠点・絞り込みなし）に戻す
// 表のページ（リセットで先頭に戻す）
const tablePage = ref(1)

function reset() {
  tablePage.value = 1
  saved.clear()
  saved.clearQuery()
  const next = defaults(ownSiteIds())
  saved.hold(next)
  selectedSiteIds.value = next.site_ids
  statuses.value = []
  categories.value = []
  search.value = ''
}

// 拠点の列は、1つの拠点だけを表示しているときは出さない（どの行も同じ拠点のため）
const headers = computed(() => [
  { title: '管理番号', key: 'management_number', minWidth: '120px' },
  { title: '名称', key: 'name', minWidth: '240px' },
  { title: '校正', key: 'calibration_state', minWidth: '210px' },
  { title: '状態', key: 'status', width: '100px' },
  { title: '種別', key: 'category', width: '110px' },
  ...(selectedSiteIds.value.length === 1 ? [] : [{ title: '拠点', key: 'site.name', minWidth: '120px' }]),
  { title: '最終校正', key: 'last_calibration', sortable: false, minWidth: '160px' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
])

const fetchGuard = latestGuard()

async function fetchStandards() {
  const isLatest = fetchGuard()
  loading.value = true
  loadError.value = false
  try {
    const params: any = { per_page: 1000 }
    if (selectedSiteIds.value.length) params.site_ids = selectedSiteIds.value
    if (statuses.value.length) params.statuses = statuses.value
    if (categories.value.length) params.categories = categories.value
    if (search.value) params.q = search.value
    const res = await api.get('/reference_standards', { params })
    if (!isLatest()) return
    standards.value = res.data.data
    totalCount.value = res.data.meta?.total_count ?? res.data.data.length
  } catch {
    if (isLatest()) loadError.value = true
  } finally {
    if (isLatest()) loading.value = false
  }
}

// --- 登録・編集（ダイアログは詳細画面と共通） ---
const dialog = ref(false)
const editing = ref<ReferenceStandard | null>(null)

function openCreate() {
  editing.value = null
  dialog.value = true
}

function openEdit(item: ReferenceStandard) {
  editing.value = item
  dialog.value = true
}

onMounted(fetchStandards)
watch(currentFilters, (value) => {
  saved.save(value)
  void fetchStandards()
})
</script>

<template>
  <MainLayout>
    <PageHeader title="基準器" description="校正に使う基準器（圧力校正器・マルチテスタ・温度校正器など）の台帳です。メーカー校正の履歴と期限を管理し、点検で使った基準器をたどれます。">
      <v-btn v-if="canManageReferenceStandard" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規登録</v-btn>
    </PageHeader>

    <div class="pk-filters">
      <SiteScopeTag v-model="selectedSiteIds" />
      <v-divider vertical class="pk-scope-divider" />
      <v-text-field v-model="search" label="管理番号・名称・型式・製造番号" density="compact" hide-details clearable prepend-inner-icon="mdi-magnify" class="pk-filter-search" />
      <FilterSelect v-model="statuses" :items="statusOptions" label="状態" />
      <FilterSelect v-model="categories" :items="categoryOptions" label="種別" />
      <FilterResetButton @reset="reset" />
    </div>

    <ListCount :total="totalCount" :shown="standards.length" :loading="loading" :error="loadError" />

    <v-data-table
      v-model:page="tablePage"
      :headers="headers"
      :items="standards"
      :loading="loading"
      :sort-by="[{ key: 'management_number', order: 'asc' }]"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => router.push(`/reference-standards/${item.id}`)"
    >
      <template #item.category="{ item }">{{ CATEGORY_LABEL[item.category] }}</template>
      <template #item.status="{ item }">
        <StatusChip :label="STATUS_LABEL[item.status]" :color="STATUS_COLOR[item.status]" />
      </template>
      <template #item.calibration_state="{ item }">
        <CalibrationStateChip :state="item.calibration_state" :next-due-on="item.next_due_on" />
      </template>
      <template #item.last_calibration="{ item }">
        <template v-if="item.calibrations[0]">
          <div class="text-no-wrap">{{ formatDay(item.calibrations[0].performed_on) }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.calibrations[0].performed_by }}</div>
        </template>
        <span v-else class="text-medium-emphasis">—</span>
      </template>
      <template #item.actions="{ item }">
        <v-btn v-if="canManageReferenceStandard" icon="mdi-pencil" size="x-small" variant="text" :aria-label="`${item.name}を編集`" @click.stop="openEdit(item)" />
      </template>
    </v-data-table>

    <ReferenceStandardFormDialog
      v-model="dialog"
      :standard="editing"
      :default-site-id="selectedSiteIds.length === 1 ? selectedSiteIds[0] : null"
      @saved="fetchStandards"
    />
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
