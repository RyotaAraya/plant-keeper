<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import api from '@/api/axios'
import DetailHeader from '@/components/layout/DetailHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'
import { todayForInput } from '@/utils/datetime'

const route = useRoute()
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
    <div v-if="loading" class="d-flex justify-center mt-8">
      <v-progress-circular indeterminate />
    </div>

    <template v-else-if="repair">
      <DetailHeader back-to="/repairs" back-label="修理管理" kind="修理" :title="repair.stock?.material?.name ?? '修理'" :subtitle="repair.repair_vendor ? `修理先 ${repair.repair_vendor}` : undefined">
        <template #status>
          <StatusChip :label="statusLabel[repair.status]" :color="statusColor[repair.status]" />
        </template>
        <template #actions>
          <v-btn v-if="canManageRepairs && !['completed','disposed'].includes(repair.status)" variant="outlined" prepend-icon="mdi-pencil" @click="openEdit">編集</v-btn>
        </template>
      </DetailHeader>
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

      <!-- 概要: 常に見える基本情報（関連の一覧はないため、タブは置かない） -->
      <v-card class="mb-4 pk-summary" data-testid="detail-summary">
        <v-card-text>
          <dl class="pk-summary__grid">
            <div><dt>処置方針</dt><dd>{{ dispositionLabel[repair.disposition] || '—' }}</dd></div>
            <div><dt>修理業者</dt><dd>{{ repair.repair_vendor || '—' }}</dd></div>
            <div><dt>依頼者</dt><dd>{{ repair.requested_by?.name || '—' }}</dd></div>
            <div><dt>発送日</dt><dd>{{ repair.shipped_on || '—' }}</dd></div>
            <div><dt>修理完了日</dt><dd>{{ repair.completed_on || '—' }}</dd></div>
            <div><dt>受領日</dt><dd>{{ repair.received_on || '—' }}</dd></div>
            <div><dt>修理費</dt><dd>{{ formatPrice(repair.repair_cost) }}</dd></div>
            <div><dt>送料</dt><dd>{{ formatPrice(repair.shipping_cost) }}</dd></div>
            <div v-if="repair.notes" class="pk-summary__wide"><dt>備考</dt><dd style="white-space: pre-wrap">{{ repair.notes }}</dd></div>
          </dl>
          <v-divider class="my-4" />
          <dl class="pk-summary__grid">
            <div>
              <dt>在庫品</dt>
              <dd><router-link class="text-primary" :to="`/stocks/${repair.stock_id}`">{{ repair.stock?.material?.name || '—' }}</router-link></dd>
            </div>
            <div><dt>型番</dt><dd>{{ repair.stock?.material?.part_number || '—' }}</dd></div>
            <div><dt>シリアル番号</dt><dd>{{ repair.stock?.serial_number || '—' }}</dd></div>
            <div><dt>保管場所</dt><dd>{{ repair.stock?.warehouse?.name || '—' }}</dd></div>
            <div v-if="repair.trouble" class="pk-summary__wide">
              <dt>関連トラブル</dt>
              <dd class="d-flex align-center ga-2">
                <router-link class="text-primary" :to="`/troubles/${repair.trouble_id}`">{{ repair.trouble.title }}</router-link>
                <StatusChip kind="trouble" :value="repair.trouble.status" />
              </dd>
            </div>
          </dl>
        </v-card-text>
      </v-card>
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
