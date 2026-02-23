<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'

const router = useRouter()
const { canManageEquipment } = usePermissions()

const instruments = ref<any[]>([])
const equipments = ref<any[]>([])
const loading = ref(false)
const selectedEquipmentId = ref<number | null>(null)
const search = ref('')
const dialog = ref(false)
const editingId = ref<number | null>(null)
const services = ref<any[]>([])
const lineClasses = ref<any[]>([])
const form = ref({
  equipment_id: null as number | null,
  tag_number: '',
  instrument_type: '',
  service_id: null as number | null,
  line_class_id: null as number | null,
  location: '',
  notes: '',
})
const errors = ref<string[]>([])

const headers = [
  { title: 'タグナンバー', key: 'tag_number' },
  { title: '種別', key: 'instrument_type' },
  { title: '設備', key: 'equipment.name' },
  { title: 'サービス', key: 'service.name' },
  { title: 'ラインクラス', key: 'line_class.code' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
]

async function fetchInstruments() {
  loading.value = true
  try {
    const params: any = { per_page: 100 }
    if (selectedEquipmentId.value) params.equipment_id = selectedEquipmentId.value
    if (search.value) params.q = search.value
    const res = await api.get('/instruments', { params })
    instruments.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function fetchMasters() {
  const [eqRes, svcRes, lcRes] = await Promise.all([
    api.get('/equipments', { params: { per_page: 100 } }),
    api.get('/services'),
    api.get('/line_classes'),
  ])
  equipments.value = eqRes.data.data
  services.value = svcRes.data.data
  lineClasses.value = lcRes.data.data
}

function openCreate() {
  editingId.value = null
  form.value = { equipment_id: selectedEquipmentId.value, tag_number: '', instrument_type: '', service_id: null, line_class_id: null, location: '', notes: '' }
  errors.value = []
  dialog.value = true
}

function openEdit(item: any) {
  editingId.value = item.id
  form.value = {
    equipment_id: item.equipment_id,
    tag_number: item.tag_number,
    instrument_type: item.instrument_type || '',
    service_id: item.service_id ?? null,
    line_class_id: item.line_class_id ?? null,
    location: item.location || '',
    notes: item.notes || '',
  }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    if (editingId.value) {
      await api.patch(`/instruments/${editingId.value}`, { instrument: form.value })
    } else {
      await api.post('/instruments', { instrument: form.value })
    }
    dialog.value = false
    await fetchInstruments()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function goToDetail(row: any) {
  router.push(`/instruments/${row.id}`)
}

let searchTimeout: ReturnType<typeof setTimeout>
watch(search, () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(fetchInstruments, 300)
})

onMounted(() => {
  fetchMasters()
  fetchInstruments()
})
watch(selectedEquipmentId, fetchInstruments)
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center flex-wrap mb-4">
      <h1 class="text-h5 mr-4">装置・計器</h1>
      <v-spacer />
      <v-text-field
        v-model="search"
        label="タグナンバー検索"
        prepend-inner-icon="mdi-magnify"
        clearable
        density="compact"
        hide-details
        style="max-width: 220px"
        class="mr-4"
      />
      <v-select
        v-model="selectedEquipmentId"
        :items="equipments"
        item-title="name"
        item-value="id"
        label="設備フィルタ"
        clearable
        density="compact"
        hide-details
        style="max-width: 220px"
        class="mr-4"
      />
      <v-btn v-if="canManageEquipment" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規作成</v-btn>
    </div>

    <v-data-table
      :headers="headers"
      :items="instruments"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.actions="{ item }">
        <v-btn v-if="canManageEquipment" icon="mdi-pencil" size="x-small" variant="text" @click.stop="openEdit(item)" />
      </template>
    </v-data-table>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editingId ? '計器編集' : '計器作成' }}</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select v-model="form.equipment_id" :items="equipments" item-title="name" item-value="id" label="設備" class="mb-2" />
          <v-text-field v-model="form.tag_number" label="タグナンバー" class="mb-2" />
          <v-text-field v-model="form.instrument_type" label="種別" class="mb-2" />
          <v-select v-model="form.service_id" :items="services" item-title="name" item-value="id" label="サービス・流体" clearable class="mb-2" />
          <v-select v-model="form.line_class_id" :items="lineClasses" item-title="code" item-value="id" label="ラインクラス" clearable class="mb-2" />
          <v-text-field v-model="form.location" label="設置場所" class="mb-2" />
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

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
