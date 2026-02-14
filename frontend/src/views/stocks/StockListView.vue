<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const router = useRouter()
const stocks = ref<any[]>([])
const warehouses = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)

const filters = ref({
  warehouse_id: null as number | null,
  status: null as string | null,
})

// Transaction dialog
const txDialog = ref(false)
const txForm = ref({
  stock_id: null as number | null,
  transaction_type: 'outgoing',
  quantity: 1,
  reason: '',
  transacted_at: new Date().toISOString().slice(0, 16),
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

async function fetchStocks() {
  loading.value = true
  try {
    const params: any = { page: page.value, per_page: 25 }
    if (filters.value.warehouse_id) params.warehouse_id = filters.value.warehouse_id
    if (filters.value.status) params.status = filters.value.status
    const res = await api.get('/stocks', { params })
    stocks.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

async function fetchWarehouses() {
  const res = await api.get('/warehouses')
  warehouses.value = res.data.data
}

function openTx(stock: any) {
  txForm.value = {
    stock_id: stock.id,
    transaction_type: 'outgoing',
    quantity: 1,
    reason: '',
    transacted_at: new Date().toISOString().slice(0, 16),
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
  fetchWarehouses()
  fetchStocks()
})
watch([filters, page], fetchStocks, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">在庫管理</h1>
    </div>

    <div class="d-flex ga-4 mb-4">
      <v-select
        v-model="filters.warehouse_id"
        :items="warehouses"
        item-title="name"
        item-value="id"
        label="倉庫"
        clearable
        density="compact"
        hide-details
        style="max-width: 200px"
      />
      <v-select
        v-model="filters.status"
        :items="statusOptions"
        item-title="title"
        item-value="value"
        label="ステータス"
        clearable
        density="compact"
        hide-details
        style="max-width: 160px"
      />
    </div>

    <v-data-table
      :headers="headers"
      :items="stocks"
      :loading="loading"
      hover
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
      class="cursor-pointer"
    >
      <template #item.status="{ item }">
        <v-chip :color="statusColor[item.status]" size="small">
          {{ statusLabel[item.status] || item.status }}
        </v-chip>
      </template>
      <template #item.actions="{ item }">
        <v-btn size="x-small" variant="outlined" @click.stop="openTx(item)">入出庫</v-btn>
      </template>
    </v-data-table>

    <div class="d-flex justify-center mt-4" v-if="totalCount > 25">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / 25)" />
    </div>

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
