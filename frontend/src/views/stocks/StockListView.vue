<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import StatusChip from '@/components/StatusChip.vue'
import FilterResetButton from '@/components/FilterResetButton.vue'
import FilterSelect from '@/components/FilterSelect.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { hasQueryConditions, useSavedFilters } from '@/composables/useSavedFilters'
import { usePermissions } from '@/composables/usePermissions'
import { keepInSites, useSiteScope } from '@/composables/useSiteScope'
import { canTransactStock } from '@/constants/stock'
import { nowForInput } from '@/utils/datetime'
import { latestGuard } from '@/utils/latestGuard'

const route = useRoute()
const router = useRouter()
const { canManageStockTransaction } = usePermissions()
const { initialSiteIds, savedSiteIds, ownSiteIds } = useSiteScope()
const stocks = ref<any[]>([])
const warehouses = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)

// 通常業務では自拠点の在庫だけ見ればよいため、自分の所属拠点を初期値にする。
// 拠点をまたいで探すときは、拠点で「全拠点」を選ぶ
type Filters = { site_ids: number[]; warehouse_ids: number[]; statuses: string[] }
// 条件は保存して、開き直したときに戻す（ほかの画面のリンクで拠点を指定されたときは、保存した条件を混ぜない）
const saved = useSavedFilters<Filters>('stocks', {
  site_ids: 'ids',
  warehouse_ids: 'ids',
  statuses: { type: 'strings', values: ['available', 'in_use', 'awaiting_repair', 'under_repair', 'disposed'] },
})
function initialFilters(): Filters {
  if (hasQueryConditions(route.query)) return { site_ids: initialSiteIds(route.query.site_ids), warehouse_ids: [], statuses: [] }
  const stored = saved.load()
  return { warehouse_ids: [], statuses: [], ...stored, site_ids: savedSiteIds(stored.site_ids) }
}
const filters = ref<Filters>(initialFilters())
saved.hold(filters.value)

// 保存した条件とURLの検索条件を消し、既定（自拠点・絞り込みなし）に戻す
// 表のページ（リセットで先頭に戻す）
const tablePage = ref(1)

function reset() {
  tablePage.value = 1
  saved.clear()
  saved.clearQuery()
  filters.value = { site_ids: ownSiteIds(), warehouse_ids: [], statuses: [] }
  saved.hold(filters.value)
  void fetchWarehouses(filters.value.site_ids)
}

// Transaction dialog
const txDialog = ref(false)
const txForm = ref({
  stock_id: null as number | null,
  transaction_type: 'outgoing',
  quantity: 1,
  reason: '',
  transacted_at: nowForInput(),
})
const txErrors = ref<string[]>([])

const headers = [
  { title: '資材名', key: 'material.name' },
  { title: 'ステータス', key: 'status', width: '110px' },
  { title: '数量', key: 'quantity', width: '80px' },
  { title: '倉庫', key: 'warehouse.name', minWidth: '170px' },
  { title: '型番', key: 'material.part_number', width: '130px' },
  { title: '購入日', key: 'purchased_on', width: '110px' },
  { title: '', key: 'actions', width: '100px', sortable: false },
]

const statusLabel: Record<string, string> = {
  available: '利用可', in_use: '使用中', awaiting_repair: '修理待ち', under_repair: '修理中', disposed: '廃棄済'
}
const statusColor: Record<string, string> = {
  available: 'success', in_use: 'info', awaiting_repair: 'warning', under_repair: 'warning', disposed: 'grey'
}
const statusOptions = [
  { title: '利用可', value: 'available' },
  { title: '使用中', value: 'in_use' },
  { title: '修理待ち', value: 'awaiting_repair' },
  { title: '修理中', value: 'under_repair' },
  { title: '廃棄済', value: 'disposed' },
]
const txTypeOptions = [
  { title: '出庫', value: 'outgoing' },
  { title: '入庫', value: 'incoming' },
  { title: '廃棄', value: 'disposal' },
]

const fetchStocksGuard = latestGuard()

async function fetchStocks() {
  const isLatest = fetchStocksGuard()
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.warehouse_ids.length) params.warehouse_ids = filters.value.warehouse_ids
    if (filters.value.statuses.length) params.statuses = filters.value.statuses
    const res = await api.get('/stocks', { params })
    if (!isLatest()) return
    stocks.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    if (isLatest()) loading.value = false
  }
}

const warehousesGuard = latestGuard()

async function fetchWarehouses(siteIds: number[]) {
  const isLatest = warehousesGuard()
  const res = await api.get('/warehouses', { params: siteIds.length ? { site_ids: siteIds } : {} })
  if (!isLatest()) return
  // 倉庫名は拠点間で重複しうるため、拠点が1つに決まらないときは拠点名を付ける
  warehouses.value = res.data.data.map((w: any) => ({ ...w, display_name: siteIds.length === 1 ? w.name : `${w.site?.name ?? ''} ${w.name}` }))
  // 選択肢にない倉庫（保存したあとに無効になったもの、表示する拠点にないもの）の絞り込みは外す
  const kept = keepInSites(filters.value.warehouse_ids, warehouses.value, siteIds)
  if (kept.length !== filters.value.warehouse_ids.length) filters.value = { ...filters.value, warehouse_ids: kept }
}

// 拠点を変えたら、表示する拠点にない倉庫の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
function changeSite(siteIds: number[]) {
  filters.value = { ...filters.value, site_ids: siteIds, warehouse_ids: keepInSites(filters.value.warehouse_ids, warehouses.value, siteIds) }
  fetchWarehouses(siteIds)
}

function openTx(stock: any) {
  txForm.value = {
    stock_id: stock.id,
    transaction_type: 'outgoing',
    quantity: 1,
    reason: '',
    transacted_at: nowForInput(),
  }
  txErrors.value = []
  txDialog.value = true
}

async function saveTx() {
  txErrors.value = []
  try {
    await api.post('/stock_transactions', { stock_transaction: txForm.value })
    txDialog.value = false
    await fetchStocks()
  } catch (e: any) {
    txErrors.value = e.response?.data?.errors || ['処理に失敗しました']
  }
}

function goToDetail(row: any) {
  router.push(`/stocks/${row.id}`)
}

onMounted(() => {
  fetchWarehouses(filters.value.site_ids)
  fetchStocks()
})
watch(filters, (value) => {
  saved.save(value)
  void fetchStocks()
}, { deep: true })
</script>

<template>
  <MainLayout>
    <PageHeader title="在庫管理" description="倉庫にある資材の数量です。入庫・出庫・移動を記録し、古いロットから使えるよう購入日順に管理します。" />

    <div class="pk-filters">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <FilterSelect v-model="filters.warehouse_ids" :items="warehouses" item-title="display_name" item-value="id" label="倉庫" style="max-width: 260px" />
      <FilterSelect v-model="filters.statuses" :items="statusOptions" label="ステータス" style="max-width: 200px" />
      <FilterResetButton @reset="reset" />
    </div>

    <v-data-table
      v-model:page="tablePage"
      :headers="headers"
      :items="stocks"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.status="{ item }">
        <StatusChip :label="statusLabel[item.status] || item.status" :color="statusColor[item.status]" />
      </template>
      <template #item.actions="{ item }">
        <v-btn v-if="canManageStockTransaction && canTransactStock(item.status)" size="x-small" variant="outlined" @click.stop="openTx(item)">入出庫</v-btn>
      </template>
    </v-data-table>

    <!-- Transaction Dialog -->
    <v-dialog v-model="txDialog" max-width="500">
      <v-card>
        <v-card-title>入出庫処理</v-card-title>
        <v-card-text>
          <v-alert v-if="txErrors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in txErrors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select v-model="txForm.transaction_type" :items="txTypeOptions" item-title="title" item-value="value" label="種別" class="mb-2" />
          <v-text-field v-model.number="txForm.quantity" label="数量" type="number" min="1" class="mb-2" />
          <v-text-field v-model="txForm.reason" label="理由・用途" class="mb-2" />
          <v-text-field v-model="txForm.transacted_at" label="日時" type="datetime-local" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="txDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveTx">実行</v-btn>
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
