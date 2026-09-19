<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { useAuthStore } from '@/stores/auth'
import { latestGuard } from '@/utils/latestGuard'

const router = useRouter()
const { canManageEquipment, canViewSites } = usePermissions()
const authStore = useAuthStore()

const equipments = ref<any[]>([])
const sites = ref<any[]>([])
const loading = ref(false)
// 通常業務では自拠点だけ意識すればよいため、自分の所属拠点をデフォルト選択（複数選択、空は全拠点）
const selectedSiteIds = ref<number[]>(authStore.user?.site_id ? [authStore.user.site_id] : [])
const dialog = ref(false)
const editingId = ref<number | null>(null)
const form = ref({ name: '', description: '', site_id: null as number | null })
const errors = ref<string[]>([])

const headers = [
  { title: '設備名', key: 'name' },
  { title: '拠点', key: 'site.name' },
  { title: '説明', key: 'description' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
]

const fetchEquipmentsGuard = latestGuard()

async function fetchEquipments() {
  const isLatest = fetchEquipmentsGuard()
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (selectedSiteIds.value.length) params.site_ids = selectedSiteIds.value
    const res = await api.get('/equipments', { params })
    if (!isLatest()) return
    equipments.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

// 設備の作成・編集ダイアログの拠点の選択肢（拠点の絞り込みは SiteScopeTag が自分で取得する）
async function fetchSites() {
  if (!canViewSites.value) return
  const res = await api.get('/sites', { params: { per_page: 100 } })
  sites.value = res.data.data
}

function openCreate() {
  editingId.value = null
  form.value = { name: '', description: '', site_id: selectedSiteIds.value.length === 1 ? (selectedSiteIds.value[0] ?? null) : null }
  errors.value = []
  dialog.value = true
}

function openEdit(item: any) {
  editingId.value = item.id
  form.value = { name: item.name, description: item.description || '', site_id: item.site_id }
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
watch(selectedSiteIds, fetchEquipments)
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">設備台帳</h1>
      <v-spacer />
      <v-btn v-if="canManageEquipment" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規作成</v-btn>
    </div>

    <div class="d-flex ga-4 mb-4 flex-wrap align-center">
      <SiteScopeTag v-model="selectedSiteIds" />
    </div>

    <v-data-table
      :headers="headers"
      :items="equipments"
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
