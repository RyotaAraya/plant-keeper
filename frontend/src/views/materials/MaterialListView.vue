<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const router = useRouter()
const materials = ref<any[]>([])
const manufacturers = ref<any[]>([])
const loading = ref(false)
const totalCount = ref(0)
const page = ref(1)
const dialog = ref(false)
const editingId = ref<number | null>(null)
const errors = ref<string[]>([])

const filters = ref({
  q: '',
  category: null as string | null,
  manufacturer_id: null as number | null,
})

const form = ref({
  manufacturer_id: null as number | null,
  part_number: '',
  name: '',
  description: '',
  category: 'instrument',
  availability: 'catalog',
  rating: '',
  lead_time_days: null as number | null,
  is_hazardous: false,
  hazard_note: '',
  reorder_method: 'reorder_point',
  reorder_point: null as number | null,
  reorder_quantity: null as number | null,
})

const headers = [
  { title: '型番', key: 'part_number', width: '150px' },
  { title: '資材名', key: 'name' },
  { title: 'カテゴリ', key: 'category', width: '100px' },
  { title: 'メーカー', key: 'manufacturer.name', width: '140px' },
  { title: '入手性', key: 'availability', width: '90px' },
  { title: '危険物', key: 'is_hazardous', width: '70px' },
]

const categoryLabel: Record<string, string> = {
  instrument: '計装', valve: 'バルブ', electrical: '電気', piping: '配管'
}
const categoryOptions = [
  { title: '計装', value: 'instrument' },
  { title: 'バルブ', value: 'valve' },
  { title: '電気', value: 'electrical' },
  { title: '配管', value: 'piping' },
]
const availabilityLabel: Record<string, string> = {
  custom: '特注', catalog: 'カタログ', commodity: '汎用'
}
const availabilityOptions = [
  { title: '特注', value: 'custom' },
  { title: 'カタログ', value: 'catalog' },
  { title: '汎用', value: 'commodity' },
]
const reorderOptions = [
  { title: '発注点方式', value: 'reorder_point' },
  { title: '使用時発注', value: 'use_based' },
]

async function fetchMaterials() {
  loading.value = true
  try {
    const params: any = { page: page.value, per_page: 25 }
    if (filters.value.q) params.q = filters.value.q
    if (filters.value.category) params.category = filters.value.category
    if (filters.value.manufacturer_id) params.manufacturer_id = filters.value.manufacturer_id
    const res = await api.get('/materials', { params })
    materials.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

async function fetchManufacturers() {
  const res = await api.get('/manufacturers')
  manufacturers.value = res.data.data
}

function openDialog(item?: any) {
  if (item) {
    editingId.value = item.id
    form.value = {
      manufacturer_id: item.manufacturer_id,
      part_number: item.part_number,
      name: item.name,
      description: item.description || '',
      category: item.category,
      availability: item.availability,
      rating: item.rating || '',
      lead_time_days: item.lead_time_days,
      is_hazardous: item.is_hazardous,
      hazard_note: item.hazard_note || '',
      reorder_method: item.reorder_method,
      reorder_point: item.reorder_point,
      reorder_quantity: item.reorder_quantity,
    }
  } else {
    editingId.value = null
    form.value = {
      manufacturer_id: null, part_number: '', name: '', description: '',
      category: 'instrument', availability: 'catalog', rating: '',
      lead_time_days: null, is_hazardous: false, hazard_note: '',
      reorder_method: 'reorder_point', reorder_point: null, reorder_quantity: null,
    }
  }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    if (editingId.value) {
      await api.patch(`/materials/${editingId.value}`, { material: form.value })
    } else {
      await api.post('/materials', { material: form.value })
    }
    dialog.value = false
    await fetchMaterials()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function goToDetail(row: any) {
  router.push(`/materials/${row.id}`)
}

onMounted(() => {
  fetchManufacturers()
  fetchMaterials()
})
watch([filters, page], fetchMaterials, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">資材管理</h1>
      <v-spacer />
      <v-btn color="primary" prepend-icon="mdi-plus" @click="openDialog()">新規登録</v-btn>
    </div>

    <div class="d-flex ga-4 mb-4 flex-wrap">
      <v-text-field
        v-model="filters.q"
        label="資材名・型番検索"
        prepend-inner-icon="mdi-magnify"
        clearable
        density="compact"
        hide-details
        style="max-width: 250px"
      />
      <v-select
        v-model="filters.category"
        :items="categoryOptions"
        item-title="title"
        item-value="value"
        label="カテゴリ"
        clearable
        density="compact"
        hide-details
        style="max-width: 140px"
      />
      <v-select
        v-model="filters.manufacturer_id"
        :items="manufacturers"
        item-title="name"
        item-value="id"
        label="メーカー"
        clearable
        density="compact"
        hide-details
        style="max-width: 180px"
      />
    </div>

    <v-data-table
      :headers="headers"
      :items="materials"
      :loading="loading"
      hover
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
      class="cursor-pointer"
    >
      <template #item.category="{ item }">
        {{ categoryLabel[item.category] || item.category }}
      </template>
      <template #item.availability="{ item }">
        {{ availabilityLabel[item.availability] || item.availability }}
      </template>
      <template #item.is_hazardous="{ item }">
        <v-icon v-if="item.is_hazardous" color="error" size="small">mdi-alert</v-icon>
      </template>
    </v-data-table>

    <div class="d-flex justify-center mt-4" v-if="totalCount > 25">
      <v-pagination v-model="page" :length="Math.ceil(totalCount / 25)" />
    </div>

    <v-dialog v-model="dialog" max-width="700">
      <v-card>
        <v-card-title>{{ editingId ? '資材編集' : '資材登録' }}</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-row dense>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.name" label="資材名 *" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.part_number" label="型番 *" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.manufacturer_id" :items="manufacturers" item-title="name" item-value="id" label="メーカー *" />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="form.category" :items="categoryOptions" item-title="title" item-value="value" label="カテゴリ" />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="form.availability" :items="availabilityOptions" item-title="title" item-value="value" label="入手性" />
            </v-col>
            <v-col cols="12">
              <v-textarea v-model="form.description" label="説明" rows="2" />
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model="form.rating" label="定格" />
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model.number="form.lead_time_days" label="リード日数" type="number" />
            </v-col>
            <v-col cols="6" md="3">
              <v-select v-model="form.reorder_method" :items="reorderOptions" item-title="title" item-value="value" label="発注方式" />
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model.number="form.reorder_point" label="発注点" type="number" />
            </v-col>
            <v-col cols="6" md="3">
              <v-text-field v-model.number="form.reorder_quantity" label="発注数量" type="number" />
            </v-col>
            <v-col cols="6" md="3">
              <v-checkbox v-model="form.is_hazardous" label="危険物" density="compact" />
            </v-col>
            <v-col cols="12" md="6" v-if="form.is_hazardous">
              <v-text-field v-model="form.hazard_note" label="危険物備考" />
            </v-col>
          </v-row>
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
