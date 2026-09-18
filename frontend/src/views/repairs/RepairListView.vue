<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'

const router = useRouter()
const { canManageCore } = usePermissions()

const repairs = ref<any[]>([])
const stocks = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)
const dialog = ref(false)
const errors = ref<string[]>([])

const filters = ref({
  status: null as string | null,
})

const form = ref({
  stock_id: null as number | null,
  disposition: 'repair',
  repair_vendor: '',
  notes: '',
})

const headers = [
  { title: '資材名', key: 'stock.material.name' },
  { title: '型番', key: 'stock.material.part_number', width: '130px' },
  { title: 'シリアル番号', key: 'stock.serial_number', width: '140px' },
  { title: 'ステータス', key: 'status', width: '110px' },
  { title: '修理業者', key: 'repair_vendor', width: '130px' },
  { title: '発送日', key: 'shipped_on', width: '110px' },
  { title: '依頼者', key: 'requested_by.name', width: '100px' },
]

const statusLabel: Record<string, string> = {
  pending: '依頼中', shipped: '発送済', in_repair: '修理中', completed: '完了', disposed: '廃棄'
}
const statusColor: Record<string, string> = {
  pending: 'warning', shipped: 'info', in_repair: 'orange', completed: 'success', disposed: 'grey'
}
const statusOptions = [
  { title: '依頼中', value: 'pending' },
  { title: '発送済', value: 'shipped' },
  { title: '修理中', value: 'in_repair' },
  { title: '完了', value: 'completed' },
  { title: '廃棄', value: 'disposed' },
]
const dispositionOptions = [
  { title: '修理', value: 'repair' },
  { title: '廃棄', value: 'dispose' },
]

async function fetchRepairs() {
  loading.value = true
  try {
    const params: any = { page: page.value, per_page: 25 }
    if (filters.value.status) params.status = filters.value.status
    const res = await api.get('/repairs', { params })
    repairs.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

async function fetchStocks() {
  const res = await api.get('/stocks', { params: { per_page: 200 } })
  stocks.value = res.data.data.filter((s: any) => !['under_repair', 'disposed'].includes(s.status))
}

function openDialog() {
  form.value = { stock_id: null, disposition: 'repair', repair_vendor: '', notes: '' }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    await api.post('/repairs', { repair: form.value })
    dialog.value = false
    await fetchRepairs()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function stockLabel(s: any) {
  const mat = s.material?.name || ''
  const serial = s.serial_number ? ` [${s.serial_number}]` : ''
  return `${mat}${serial}`
}

onMounted(() => {
  fetchRepairs()
  fetchStocks()
})
watch([filters, page], fetchRepairs, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">修理管理</h1>
      <v-spacer />
      <v-btn v-if="canManageCore" color="primary" prepend-icon="mdi-plus" @click="openDialog()">修理依頼</v-btn>
    </div>

    <div class="d-flex ga-4 mb-4 flex-wrap align-center">
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
      :items="repairs"
      :loading="loading"
      hover
      @click:row="(_: any, { item }: any) => router.push(`/repairs/${item.id}`)"
    >
      <template #item.stock.serial_number="{ item }">
        {{ item.stock?.serial_number || '—' }}
      </template>
      <template #item.status="{ item }">
        <v-chip :color="statusColor[item.status]" size="small">
          {{ statusLabel[item.status] }}
        </v-chip>
      </template>
      <template #item.repair_vendor="{ item }">
        {{ item.repair_vendor || '—' }}
      </template>
      <template #item.shipped_on="{ item }">
        {{ item.shipped_on || '—' }}
      </template>
    </v-data-table>

    <div v-if="totalCount > 25" class="d-flex justify-center mt-4">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / 25)" />
    </div>

    <v-dialog v-model="dialog" max-width="540">
      <v-card>
        <v-card-title>修理依頼</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select
            v-model="form.stock_id"
            :items="stocks"
            :item-title="stockLabel"
            item-value="id"
            label="在庫品 *"
            class="mb-2"
          >
            <template #item="{ item, props }">
              <v-list-item v-bind="props" :subtitle="item.raw.material?.part_number" />
            </template>
          </v-select>
          <v-select
            v-model="form.disposition"
            :items="dispositionOptions"
            item-title="title"
            item-value="value"
            label="処置方針 *"
            class="mb-2"
          />
          <v-text-field v-model="form.repair_vendor" label="修理業者" class="mb-2" />
          <v-textarea v-model="form.notes" label="備考" rows="2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="save">依頼登録</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>
