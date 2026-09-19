<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import FilterSelect from '@/components/FilterSelect.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import { nowForInput } from '@/utils/datetime'
import { latestGuard } from '@/utils/latestGuard'

const router = useRouter()
const { canManageStockTransaction } = usePermissions()
const authStore = useAuthStore()
const stocks = ref<any[]>([])
const warehouses = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)

// 通常業務では自拠点の在庫だけ見ればよいため、自分の所属拠点を初期値にする。
// 拠点をまたいで探すときは、拠点で「全拠点」を選ぶ
const filters = ref({
  site_ids: (authStore.user?.site_id ? [authStore.user.site_id] : []) as number[],
  warehouse_ids: [] as number[],
  statuses: [] as string[],
})

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
  { title: '型番', key: 'material.part_number', width: '130px' },
  { title: '倉庫', key: 'warehouse.name', width: '130px' },
  { title: '数量', key: 'quantity', width: '80px' },
  { title: '購入日', key: 'purchased_on', width: '110px' },
  { title: 'ステータス', key: 'status', width: '110px' },
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
}

// 拠点を変えたら、表示する拠点にない倉庫の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
function changeSite(siteIds: number[]) {
  const shown = (id: number) => siteIds.length === 0 || siteIds.includes(id)
  const keepWarehouses = filters.value.warehouse_ids.filter((id) => warehouses.value.find((w) => w.id === id && shown(w.site_id)))
  filters.value = { ...filters.value, site_ids: siteIds, warehouse_ids: keepWarehouses }
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
watch(filters, fetchStocks, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">在庫管理</h1>
    </div>

    <div class="d-flex ga-4 mb-4 flex-wrap align-center">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <FilterSelect v-model="filters.warehouse_ids" :items="warehouses" item-title="display_name" item-value="id" label="倉庫" style="max-width: 260px" />
      <FilterSelect v-model="filters.statuses" :items="statusOptions" label="ステータス" style="max-width: 200px" />
    </div>

    <v-data-table
      :headers="headers"
      :items="stocks"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.status="{ item }">
        <v-chip :color="statusColor[item.status]" size="small">
          {{ statusLabel[item.status] || item.status }}
        </v-chip>
      </template>
      <template #item.actions="{ item }">
        <v-btn v-if="canManageStockTransaction" size="x-small" variant="outlined" @click.stop="openTx(item)">入出庫</v-btn>
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
