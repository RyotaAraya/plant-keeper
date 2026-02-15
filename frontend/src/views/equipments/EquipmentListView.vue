<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const router = useRouter()

const equipments = ref<any[]>([])
const sites = ref<any[]>([])
const loading = ref(false)
const selectedSiteId = ref<number | null>(null)
const dialog = ref(false)
const editingId = ref<number | null>(null)
const form = ref({ name: '', description: '', site_id: null as number | null })
const errors = ref<string[]>([])

const headers = [
  { title: '設備名', key: 'name' },
  { title: '拠点', key: 'site.name' },
  { title: '説明', key: 'description' },
]

async function fetchEquipments() {
  loading.value = true
  try {
    const params: any = { per_page: 100 }
    if (selectedSiteId.value) params.site_id = selectedSiteId.value
    const res = await api.get('/equipments', { params })
    equipments.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function fetchSites() {
  const res = await api.get('/sites', { params: { per_page: 100 } })
  sites.value = res.data.data
}

function openCreate() {
  editingId.value = null
  form.value = { name: '', description: '', site_id: selectedSiteId.value }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    if (editingId.value) {
      await api.patch(`/equipments/${editingId.value}`, { equipment: form.value })
    } else {
      await api.post('/equipments', { equipment: form.value })
    }
    dialog.value = false
    await fetchEquipments()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function goToDetail(row: any) {
  router.push(`/equipments/${row.id}`)
}

onMounted(() => {
  fetchSites()
  fetchEquipments()
})
watch(selectedSiteId, fetchEquipments)
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">設備台帳</h1>
      <v-spacer />
      <v-select
        v-model="selectedSiteId"
        :items="sites"
        item-title="name"
        item-value="id"
        label="拠点フィルタ"
        clearable
        density="compact"
        hide-details
        style="max-width: 250px"
        class="mr-4"
      />
      <v-btn color="primary" prepend-icon="mdi-plus" @click="openCreate">新規作成</v-btn>
    </div>

    <v-data-table
      :headers="headers"
      :items="equipments"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    />

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editingId ? '設備編集' : '設備作成' }}</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select
            v-model="form.site_id"
            :items="sites"
            item-title="name"
            item-value="id"
            label="拠点"
            class="mb-2"
          />
          <v-text-field v-model="form.name" label="設備名" class="mb-2" />
          <v-textarea v-model="form.description" label="説明" rows="3" />
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
