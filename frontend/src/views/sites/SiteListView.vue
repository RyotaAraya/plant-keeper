<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'

const router = useRouter()
const { canManageSite } = usePermissions()

const sites = ref<any[]>([])
const loading = ref(false)
const showInactive = ref(false)
const dialog = ref(false)
const editingId = ref<number | null>(null)
const form = ref({ name: '', prefecture: '', address: '', is_active: true, closed_on: '' })
const errors = ref<string[]>([])

const headers = [
  { title: '拠点名', key: 'name' },
  { title: '所在県', key: 'prefecture' },
  { title: '住所', key: 'address' },
  { title: '状態', key: 'is_active', width: '100px' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
]

async function fetchSites() {
  loading.value = true
  try {
    const params: any = {}
    if (!showInactive.value) params.is_active = true
    const res = await api.get('/sites', { params })
    sites.value = res.data.data
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingId.value = null
  form.value = { name: '', prefecture: '', address: '', is_active: true, closed_on: '' }
  errors.value = []
  dialog.value = true
}

function openEdit(item: any) {
  editingId.value = item.id
  form.value = { name: item.name, prefecture: item.prefecture || '', address: item.address || '', is_active: item.is_active, closed_on: item.closed_on || '' }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    if (editingId.value) {
      await api.patch(`/sites/${editingId.value}`, { site: form.value })
    } else {
      await api.post('/sites', { site: form.value })
    }
    dialog.value = false
    await fetchSites()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function goToDetail(row: any) {
  router.push(`/sites/${row.id}`)
}

onMounted(fetchSites)
watch(showInactive, fetchSites)
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">拠点管理</h1>
      <v-spacer />
      <v-switch
        v-model="showInactive"
        label="閉鎖拠点を表示"
        density="compact"
        hide-details
        class="mr-4"
      />
      <v-btn v-if="canManageSite" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規作成</v-btn>
    </div>

    <v-data-table
      :headers="headers"
      :items="sites"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.is_active="{ item }">
        <v-chip :color="item.is_active ? 'success' : 'grey'" size="small">
          {{ item.is_active ? '稼働中' : '閉鎖' }}
        </v-chip>
      </template>
      <template #item.actions="{ item }">
        <v-btn v-if="canManageSite" icon="mdi-pencil" size="x-small" variant="text" @click.stop="openEdit(item)" />
      </template>
    </v-data-table>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editingId ? '拠点編集' : '拠点作成' }}</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="form.name" label="拠点名" class="mb-2" />
          <v-text-field v-model="form.prefecture" label="所在県" class="mb-2" />
          <v-text-field v-model="form.address" label="住所" class="mb-2" />
          <v-switch v-model="form.is_active" label="稼働中" class="mb-2" />
          <v-text-field v-if="!form.is_active" v-model="form.closed_on" label="閉鎖日" type="date" />
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
