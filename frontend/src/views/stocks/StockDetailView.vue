<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const route = useRoute()
const router = useRouter()
const stock = ref<any>(null)
const loading = ref(true)

// Transaction dialog
const txDialog = ref(false)
const txForm = ref({
  transaction_type: 'outgoing',
  quantity: 1,
  reason: '',
  transacted_at: new Date().toISOString().slice(0, 16),
})
const txErrors = ref<string[]>([])

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

function openTx() {
  txForm.value = {
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

onMounted(fetchStock)
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="stock">
      <div class="d-flex align-center mb-4">
        <v-btn icon="mdi-arrow-left" variant="text" @click="router.push('/stocks')" />
        <h1 class="text-h5 ml-2">在庫詳細</h1>
        <v-spacer />
        <v-btn color="primary" prepend-icon="mdi-swap-horizontal" @click="openTx">入出庫</v-btn>
      </div>

      <v-card class="mb-4">
        <v-card-text>
          <v-row>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">資材名</div>
              <a class="text-primary" style="cursor:pointer" @click="router.push(`/materials/${stock.material?.id}`)">
                {{ stock.material?.name }}
              </a>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">型番</div>
              <div>{{ stock.material?.part_number }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">倉庫</div>
              <div>{{ stock.warehouse?.name }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">数量</div>
              <div class="text-h5">{{ stock.quantity }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">ステータス</div>
              <v-chip :color="statusColor[stock.status]" size="small">
                {{ statusLabel[stock.status] || stock.status }}
              </v-chip>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">購入日</div>
              <div>{{ stock.purchased_on || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">シリアル番号</div>
              <div>{{ stock.serial_number || '—' }}</div>
            </v-col>
            <v-col v-if="stock.notes" cols="6" md="3">
              <div class="text-caption text-grey">備考</div>
              <div>{{ stock.notes }}</div>
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <!-- 入出庫履歴 -->
      <h2 class="text-h6 mb-3">入出庫履歴</h2>
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

      <!-- 修理履歴 -->
      <template v-if="stock.repairs?.length">
        <h2 class="text-h6 mt-6 mb-3">修理履歴</h2>
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
      </template>

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
    </template>
  </MainLayout>
</template>
