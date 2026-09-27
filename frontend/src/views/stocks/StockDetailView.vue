<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import api from '@/api/axios'
import DetailHeader from '@/components/layout/DetailHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import { useDetailTab } from '@/composables/useDetailTab'
import { usePermissions } from '@/composables/usePermissions'
import { canTransactStock } from '@/constants/stock'
import { nowForInput } from '@/utils/datetime'

const route = useRoute()
const { canManageStockTransaction } = usePermissions()
const stock = ref<any>(null)
// 詳細の中身は「概要 → タブ」（修理履歴は、あるときだけ）
const tab = useDetailTab(() => ['transactions', ...(stock.value?.repairs?.length ? ['repairs'] : [])])
const loading = ref(true)

// Transaction dialog
const txDialog = ref(false)
const txForm = ref({
  transaction_type: 'outgoing',
  quantity: 1,
  reason: '',
  transacted_at: nowForInput(),
  to_warehouse_id: null as number | null,
})
const txErrors = ref<string[]>([])
const warehouses = ref<any[]>([])

const statusLabel: Record<string, string> = {
  available: '利用可', in_use: '使用中', awaiting_repair: '修理待ち', under_repair: '修理中', disposed: '廃棄済'
}
const statusColor: Record<string, string> = {
  available: 'success', in_use: 'info', awaiting_repair: 'warning', under_repair: 'warning', disposed: 'grey'
}
const txTypeLabel: Record<string, string> = {
  incoming: '入庫', outgoing: '出庫', transfer: '移動', disposal: '廃棄'
}
const txTypeColor: Record<string, string> = {
  incoming: 'success', outgoing: 'info', transfer: 'warning', disposal: 'error'
}
const txTypeOptions = [
  { title: '出庫', value: 'outgoing' },
  { title: '入庫', value: 'incoming' },
  { title: '移動', value: 'transfer' },
  { title: '廃棄', value: 'disposal' },
]
const repairStatusLabel: Record<string, string> = {
  pending: '依頼中', shipped: '発送済', in_repair: '修理中', completed: '完了', disposed: '廃棄'
}

async function fetchStock() {
  loading.value = true
  try {
    const res = await api.get(`/stocks/${route.params.id}`)
    stock.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function fetchWarehouses() {
  const res = await api.get('/warehouses')
  warehouses.value = res.data.data
}

function openTx() {
  txForm.value = {
    transaction_type: 'outgoing',
    quantity: 1,
    reason: '',
    transacted_at: nowForInput(),
    to_warehouse_id: null,
  }
  txErrors.value = []
  txDialog.value = true
}

async function saveTx() {
  txErrors.value = []
  try {
    await api.post('/stock_transactions', {
      stock_transaction: {
        stock_id: stock.value.id,
        ...txForm.value,
      }
    })
    txDialog.value = false
    await fetchStock()
  } catch (e: any) {
    txErrors.value = e.response?.data?.errors || ['処理に失敗しました']
  }
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

onMounted(() => {
  fetchStock()
  fetchWarehouses()
})
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="stock">
      <DetailHeader back-to="/stocks" back-label="在庫管理" kind="在庫" :title="stock.material?.name ?? '在庫'" :subtitle="`${stock.material?.part_number ?? ''} ・ ${stock.warehouse?.name ?? ''}`">
        <template #status>
          <StatusChip :label="statusLabel[stock.status] || stock.status" :color="statusColor[stock.status]" />
        </template>
        <template #actions>
          <v-btn v-if="canManageStockTransaction && canTransactStock(stock.status)" color="primary" prepend-icon="mdi-swap-horizontal" @click="openTx">入出庫</v-btn>
        </template>
      </DetailHeader>

      <!-- 概要: 常に見える基本情報 -->
      <v-card class="mb-4 pk-summary" data-testid="detail-summary">
        <v-card-text>
          <dl class="pk-summary__grid">
            <div><dt>資材名</dt><dd><router-link class="text-primary" :to="`/materials/${stock.material?.id}`">{{ stock.material?.name }}</router-link></dd></div>
            <div><dt>型番</dt><dd>{{ stock.material?.part_number }}</dd></div>
            <div><dt>倉庫</dt><dd>{{ stock.warehouse?.name }}</dd></div>
            <div><dt>数量</dt><dd class="text-h6">{{ stock.quantity }}</dd></div>
            <div><dt>購入日</dt><dd>{{ stock.purchased_on || '—' }}</dd></div>
            <div><dt>シリアル番号</dt><dd>{{ stock.serial_number || '—' }}</dd></div>
            <div v-if="stock.notes" class="pk-summary__wide"><dt>備考</dt><dd style="white-space: pre-wrap">{{ stock.notes }}</dd></div>
          </dl>
        </v-card-text>
      </v-card>

      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="transactions">入出庫履歴（{{ stock.stock_transactions?.length ?? 0 }}）</v-tab>
        <v-tab v-if="stock.repairs?.length" value="repairs">修理履歴（{{ stock.repairs.length }}）</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item value="transactions">
          <v-table v-if="stock.stock_transactions?.length" density="compact">
            <thead>
              <tr>
                <th width="160">日時</th>
                <th width="80">種別</th>
                <th width="70">数量</th>
                <th>理由・用途</th>
                <th width="100">実施者</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="tx in stock.stock_transactions" :key="tx.id">
                <td>{{ formatDate(tx.transacted_at) }}</td>
                <td>
                  <v-chip :color="txTypeColor[tx.transaction_type]" size="x-small">
                    {{ txTypeLabel[tx.transaction_type] || tx.transaction_type }}
                  </v-chip>
                </td>
                <td>{{ tx.quantity }}</td>
                <td>{{ tx.reason || '—' }}</td>
                <td>{{ tx.user?.name }}</td>
              </tr>
            </tbody>
          </v-table>
          <div v-else class="text-grey text-center py-4">入出庫履歴なし</div>
        </v-window-item>

        <v-window-item v-if="stock.repairs?.length" value="repairs">
          <v-table density="compact">
            <thead>
              <tr>
                <th width="100">ステータス</th>
                <th>修理業者</th>
                <th width="110">発送日</th>
                <th width="110">完了日</th>
                <th width="100">費用</th>
                <th width="100">依頼者</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in stock.repairs" :key="r.id">
                <td>{{ repairStatusLabel[r.status] || r.status }}</td>
                <td>{{ r.repair_vendor || '—' }}</td>
                <td>{{ r.shipped_on || '—' }}</td>
                <td>{{ r.completed_on || '—' }}</td>
                <td>{{ r.repair_cost ? `¥${r.repair_cost.toLocaleString()}` : '—' }}</td>
                <td>{{ r.requested_by?.name }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-window-item>
      </v-window>

      <!-- Transaction Dialog -->
      <v-dialog v-model="txDialog" max-width="500">
        <v-card>
          <v-card-title>入出庫処理</v-card-title>
          <v-card-text>
            <v-alert v-if="txErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in txErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-select v-model="txForm.transaction_type" :items="txTypeOptions" item-title="title" item-value="value" label="種別" class="mb-2" />
            <v-select
              v-if="txForm.transaction_type === 'transfer'"
              v-model="txForm.to_warehouse_id"
              :items="warehouses.filter((w) => w.id !== stock.warehouse_id)"
              item-title="name"
              item-value="id"
              label="移動先倉庫"
              class="mb-2"
            />
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
    </template>
  </MainLayout>
</template>
