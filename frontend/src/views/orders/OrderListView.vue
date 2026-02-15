<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const orders = ref<any[]>([])
const materials = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)
const dialog = ref(false)
const editingId = ref<number | null>(null)
const errors = ref<string[]>([])

const filters = ref({
  status: null as string | null,
})

const form = ref({
  material_id: null as number | null,
  quantity: 1,
  unit_price: null as number | null,
  supplier_name: '',
  supplier_link: '',
  ordered_on: new Date().toISOString().slice(0, 10),
  notes: '',
})

const headers = [
  { title: '発注日', key: 'ordered_on', width: '110px' },
  { title: '資材', key: 'material.name' },
  { title: '型番', key: 'material.part_number', width: '130px' },
  { title: '数量', key: 'quantity', width: '70px' },
  { title: '単価', key: 'unit_price', width: '100px' },
  { title: '仕入先', key: 'supplier_name', width: '130px' },
  { title: '発注者', key: 'user.name', width: '100px' },
  { title: 'ステータス', key: 'status', width: '100px' },
]

const statusLabel: Record<string, string> = {
  draft: '下書き', ordered: '発注済', received: '受領済', cancelled: 'キャンセル'
}
const statusColor: Record<string, string> = {
  draft: 'grey', ordered: 'info', received: 'success', cancelled: 'error'
}
const statusOptions = [
  { title: '下書き', value: 'draft' },
  { title: '発注済', value: 'ordered' },
  { title: '受領済', value: 'received' },
  { title: 'キャンセル', value: 'cancelled' },
]

async function fetchOrders() {
  loading.value = true
  try {
    const params: any = { page: page.value, per_page: 25 }
    if (filters.value.status) params.status = filters.value.status
    const res = await api.get('/orders', { params })
    orders.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

async function fetchMaterials() {
  const res = await api.get('/materials', { params: { per_page: 100 } })
  materials.value = res.data.data
}

function openDialog(item?: any) {
  if (item) {
    editingId.value = item.id
    form.value = {
      material_id: item.material_id,
      quantity: item.quantity,
      unit_price: item.unit_price,
      supplier_name: item.supplier_name || '',
      supplier_link: item.supplier_link || '',
      ordered_on: item.ordered_on || '',
      notes: item.notes || '',
    }
  } else {
    editingId.value = null
    form.value = {
      material_id: null, quantity: 1, unit_price: null,
      supplier_name: '', supplier_link: '',
      ordered_on: new Date().toISOString().slice(0, 10), notes: '',
    }
  }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    if (editingId.value) {
      await api.patch(`/orders/${editingId.value}`, { order: form.value })
    } else {
      await api.post('/orders', { order: form.value })
    }
    dialog.value = false
    await fetchOrders()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

async function updateStatus(id: number, status: string) {
  const payload: any = { order: { status } }
  if (status === 'received') payload.order.received_on = new Date().toISOString().slice(0, 10)
  await api.patch(`/orders/${id}`, payload)
  await fetchOrders()
}

function formatPrice(val: number | null) {
  if (val == null) return '—'
  return `¥${val.toLocaleString()}`
}

onMounted(() => {
  fetchMaterials()
  fetchOrders()
})
watch([filters, page], fetchOrders, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">発注管理</h1>
      <v-spacer />
      <v-btn color="primary" prepend-icon="mdi-plus" @click="openDialog()">新規発注</v-btn>
    </div>

    <div class="d-flex ga-4 mb-4">
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
      :items="orders"
      :loading="loading"
      hover
    >
      <template #item.unit_price="{ item }">
        {{ formatPrice(item.unit_price) }}
      </template>
      <template #item.status="{ item }">
        <v-menu v-if="item.status !== 'cancelled'">
          <template #activator="{ props }">
            <v-chip v-bind="props" :color="statusColor[item.status]" size="small" style="cursor:pointer">
              {{ statusLabel[item.status] }}
              <v-icon end size="x-small">mdi-chevron-down</v-icon>
            </v-chip>
          </template>
          <v-list density="compact">
            <v-list-item v-if="item.status === 'draft'" @click="updateStatus(item.id, 'ordered')">
              <v-list-item-title>発注確定</v-list-item-title>
            </v-list-item>
            <v-list-item v-if="item.status === 'ordered'" @click="updateStatus(item.id, 'received')">
              <v-list-item-title>受領</v-list-item-title>
            </v-list-item>
            <v-list-item @click="updateStatus(item.id, 'cancelled')">
              <v-list-item-title class="text-error">キャンセル</v-list-item-title>
            </v-list-item>
          </v-list>
        </v-menu>
        <v-chip v-else :color="statusColor[item.status]" size="small">
          {{ statusLabel[item.status] }}
        </v-chip>
      </template>
    </v-data-table>

    <div v-if="totalCount > 25" class="d-flex justify-center mt-4">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / 25)" />
    </div>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editingId ? '発注編集' : '新規発注' }}</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select v-model="form.material_id" :items="materials" item-title="name" item-value="id" label="資材 *" class="mb-2">
            <template #item="{ item, props }">
              <v-list-item v-bind="props" :subtitle="item.raw.part_number" />
            </template>
          </v-select>
          <v-row dense>
            <v-col cols="6">
              <v-text-field v-model.number="form.quantity" label="数量 *" type="number" min="1" />
            </v-col>
            <v-col cols="6">
              <v-text-field v-model.number="form.unit_price" label="単価 (円)" type="number" />
            </v-col>
          </v-row>
          <v-text-field v-model="form.supplier_name" label="仕入先" class="mb-2" />
          <v-text-field v-model="form.supplier_link" label="仕入先リンク" class="mb-2" />
          <v-text-field v-model="form.ordered_on" label="発注日 *" type="date" class="mb-2" />
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
