<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'
import { todayForInput } from '@/utils/datetime'

const route = useRoute()
const router = useRouter()
const { canManageRepairs } = usePermissions()

const repair = ref<any>(null)
const loading = ref(true)

const editDialog = ref(false)
const editForm = ref({
  repair_vendor: '',
  shipped_on: '',
  completed_on: '',
  received_on: '',
  repair_cost: null as number | null,
  shipping_cost: null as number | null,
  disposition: '',
  notes: '',
})
const editErrors = ref<string[]>([])

const statusLabel: Record<string, string> = {
  pending: '依頼中', shipped: '発送済', in_repair: '修理中', completed: '完了', disposed: '廃棄'
}
const statusColor: Record<string, string> = {
  pending: 'warning', shipped: 'info', in_repair: 'orange', completed: 'success', disposed: 'grey'
}
const dispositionLabel: Record<string, string> = { repair: '修理', dispose: '廃棄' }

// ステータス遷移の定義
const nextStatusOptions: Record<string, { label: string; value: string; color: string }[]> = {
  pending: [
    { label: '発送', value: 'shipped', color: 'info' },
    { label: '廃棄処理', value: 'disposed', color: 'error' },
  ],
  shipped: [
    { label: '修理開始', value: 'in_repair', color: 'warning' },
  ],
  in_repair: [
    { label: '修理完了', value: 'completed', color: 'success' },
    { label: '廃棄処理', value: 'disposed', color: 'error' },
  ],
  completed: [],
  disposed: [],
}

async function fetchRepair() {
  loading.value = true
  try {
    const res = await api.get(`/repairs/${route.params.id}`)
    repair.value = res.data.data
  } finally {
    loading.value = false
  }
}

function openEdit() {
  editForm.value = {
    repair_vendor: repair.value.repair_vendor || '',
    shipped_on: repair.value.shipped_on || '',
    completed_on: repair.value.completed_on || '',
    received_on: repair.value.received_on || '',
    repair_cost: repair.value.repair_cost,
    shipping_cost: repair.value.shipping_cost,
    disposition: repair.value.disposition || 'repair',
    notes: repair.value.notes || '',
  }
  editErrors.value = []
  editDialog.value = true
}

async function saveEdit() {
  editErrors.value = []
  try {
    await api.patch(`/repairs/${route.params.id}`, { repair: editForm.value })
    editDialog.value = false
    await fetchRepair()
  } catch (e: any) {
    editErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

async function updateStatus(status: string) {
  const payload: any = { repair: { status } }
  if (status === 'shipped') payload.repair.shipped_on = todayForInput()
  if (status === 'completed') payload.repair.completed_on = todayForInput()
  await api.patch(`/repairs/${route.params.id}`, payload)
  await fetchRepair()
}

function formatPrice(val: number | null) {
  if (val == null) return '—'
  return `¥${Number(val).toLocaleString()}`
}

onMounted(fetchRepair)
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <v-btn icon variant="text" @click="router.push('/repairs')">
        <v-icon>mdi-arrow-left</v-icon>
      </v-btn>
      <h1 class="text-h5 ml-2">修理詳細</h1>
      <v-spacer />
      <v-btn v-if="canManageRepairs && repair && !['completed','disposed'].includes(repair.status)" variant="outlined" @click="openEdit">編集</v-btn>
    </div>

    <div v-if="loading" class="d-flex justify-center mt-8">
      <v-progress-circular indeterminate />
    </div>

    <template v-else-if="repair">
      <!-- ステータス遷移 -->
      <div v-if="canManageRepairs && nextStatusOptions[repair.status]?.length" class="d-flex ga-2 mb-4">
        <v-btn
          v-for="opt in nextStatusOptions[repair.status]"
          :key="opt.value"
          :color="opt.color"
          variant="tonal"
          @click="updateStatus(opt.value)"
        >
          {{ opt.label }}
        </v-btn>
      </div>

      <v-row>
        <v-col cols="12" md="6">
          <v-card class="mb-4">
            <v-card-title>修理情報</v-card-title>
            <v-card-text>
              <v-list density="compact">
                <v-list-item title="ステータス">
                  <template #append>
                    <v-chip :color="statusColor[repair.status]" size="small">
                      {{ statusLabel[repair.status] }}
                    </v-chip>
                  </template>
                </v-list-item>
                <v-list-item title="処置方針" :subtitle="dispositionLabel[repair.disposition] || '—'" />
                <v-list-item title="修理業者" :subtitle="repair.repair_vendor || '—'" />
                <v-list-item title="依頼者" :subtitle="repair.requested_by?.name || '—'" />
                <v-list-item title="発送日" :subtitle="repair.shipped_on || '—'" />
                <v-list-item title="修理完了日" :subtitle="repair.completed_on || '—'" />
                <v-list-item title="受領日" :subtitle="repair.received_on || '—'" />
                <v-list-item title="修理費" :subtitle="formatPrice(repair.repair_cost)" />
                <v-list-item title="送料" :subtitle="formatPrice(repair.shipping_cost)" />
                <v-list-item v-if="repair.notes" title="備考" :subtitle="repair.notes" />
              </v-list>
            </v-card-text>
          </v-card>
        </v-col>

        <v-col cols="12" md="6">
          <v-card class="mb-4">
            <v-card-title>在庫品</v-card-title>
            <v-card-text>
              <v-list density="compact">
                <v-list-item
                  title="資材名"
                  :subtitle="repair.stock?.material?.name || '—'"
                />
                <v-list-item
                  title="型番"
                  :subtitle="repair.stock?.material?.part_number || '—'"
                />
                <v-list-item
                  title="シリアル番号"
                  :subtitle="repair.stock?.serial_number || '—'"
                />
                <v-list-item
                  title="保管場所"
                  :subtitle="repair.stock?.warehouse?.name || '—'"
                />
              </v-list>
              <v-btn
                variant="text"
                size="small"
                class="mt-1"
                @click="router.push(`/stocks/${repair.stock_id}`)"
              >
                在庫詳細を見る
                <v-icon end size="small">mdi-open-in-new</v-icon>
              </v-btn>
            </v-card-text>
          </v-card>

          <v-card v-if="repair.trouble">
            <v-card-title>関連トラブル</v-card-title>
            <v-card-text>
              <v-list density="compact">
                <v-list-item title="タイトル" :subtitle="repair.trouble.title" />
                <v-list-item title="ステータス" :subtitle="repair.trouble.status" />
              </v-list>
              <v-btn
                variant="text"
                size="small"
                class="mt-1"
                @click="router.push(`/troubles/${repair.trouble_id}`)"
              >
                トラブル詳細を見る
                <v-icon end size="small">mdi-open-in-new</v-icon>
              </v-btn>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <!-- 編集ダイアログ -->
    <v-dialog v-model="editDialog" max-width="560">
      <v-card>
        <v-card-title>修理情報を編集</v-card-title>
        <v-card-text>
          <v-alert v-if="editErrors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in editErrors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="editForm.repair_vendor" label="修理業者" class="mb-2" />
          <v-select
            v-model="editForm.disposition"
            :items="[{ title: '修理', value: 'repair' }, { title: '廃棄', value: 'dispose' }]"
            item-title="title"
            item-value="value"
            label="処置方針"
            class="mb-2"
          />
          <v-row dense>
            <v-col cols="6">
              <v-text-field v-model="editForm.shipped_on" label="発送日" type="date" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model="editForm.completed_on" label="修理完了日" type="date" />
            </v-col>
          </v-row>
          <v-text-field v-model="editForm.received_on" label="受領日" type="date" class="mb-2" />
          <v-row dense>
            <v-col cols="6">
              <v-text-field v-model.number="editForm.repair_cost" label="修理費 (円)" type="number" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="editForm.shipping_cost" label="送料 (円)" type="number" />
            </v-col>
          </v-row>
          <v-textarea v-model="editForm.notes" label="備考" rows="3" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="editDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveEdit">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>
