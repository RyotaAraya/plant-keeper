<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import FilterSelect from '@/components/FilterSelect.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const { canManageMaintenance } = usePermissions()
const authStore = useAuthStore()

const maintenances = ref<any[]>([])
const { equipments, load: loadSiteOptions } = useSiteScopeOptions({ withDepartments: false })
const loading = ref(false)
const totalCount = ref(0)
const dialog = ref(false)
const errors = ref<string[]>([])

// 通常業務では自拠点の整備だけ見ればよいため、自分の所属拠点を初期値にする
const filters = ref({
  site_ids: (authStore.user?.site_id ? [authStore.user.site_id] : []) as number[],
  equipment_ids: [] as number[],
  statuses: [] as string[],
})

const form = ref({
  equipment_id: null as number | null,
  title: '',
  description: '',
  scheduled_date: '',
  status: 'planned',
})

const headers = [
  { title: '予定日', key: 'scheduled_date', width: '120px' },
  { title: 'タイトル', key: 'title' },
  { title: '設備', key: 'equipment.name', width: '180px' },
  { title: '担当者', key: 'assignees', width: '180px' },
  { title: 'ステータス', key: 'status', width: '110px' },
]

const statusLabel: Record<string, string> = {
  planned: '計画中', in_progress: '実施中', completed: '完了'
}
const statusColor: Record<string, string> = {
  planned: 'info', in_progress: 'warning', completed: 'success'
}

const statusOptions = [
  { title: '計画中', value: 'planned' },
  { title: '実施中', value: 'in_progress' },
  { title: '完了', value: 'completed' },
]

async function fetchMaintenances() {
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.equipment_ids.length) params.equipment_ids = filters.value.equipment_ids
    if (filters.value.statuses.length) params.statuses = filters.value.statuses
    const res = await api.get('/scheduled_maintenances', { params })
    maintenances.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    loading.value = false
  }
}

// 拠点を変えたら、表示する拠点にない設備の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
function changeSite(siteIds: number[]) {
  const shown = (id: number) => siteIds.length === 0 || siteIds.includes(id)
  const keepEquipment = filters.value.equipment_ids.filter((id) => equipments.value.find((e) => e.id === id && shown(e.site_id)))
  filters.value = { ...filters.value, site_ids: siteIds, equipment_ids: keepEquipment }
  loadSiteOptions(siteIds)
}

function getAssignees(item: any) {
  return (item.maintenance_assignments || [])
    .map((a: any) => `${a.user?.name || ''}${a.role === 'lead' ? '(主)' : ''}`)
    .join(', ')
}

function openCreate() {
  form.value = {
    equipment_id: null,
    title: '',
    description: '',
    scheduled_date: '',
    status: 'planned',
  }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    await api.post('/scheduled_maintenances', { scheduled_maintenance: form.value })
    dialog.value = false
    await fetchMaintenances()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleDateString('ja-JP')
}

function goToDetail(row: any) {
  router.push(`/maintenances/${row.id}`)
}

onMounted(() => {
  loadSiteOptions(filters.value.site_ids)
  fetchMaintenances()
})
watch(filters, fetchMaintenances, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">定期整備</h1>
      <v-spacer />
      <v-btn v-if="canManageMaintenance" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規作成</v-btn>
    </div>

    <div class="d-flex ga-4 mb-4 flex-wrap align-center">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <FilterSelect v-model="filters.equipment_ids" :items="equipments" item-title="name" item-value="id" label="設備" searchable style="max-width: 240px" />
      <FilterSelect v-model="filters.statuses" :items="statusOptions" label="ステータス" style="max-width: 200px" />
    </div>

    <v-data-table
      :headers="headers"
      :items="maintenances"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.scheduled_date="{ item }">
        {{ formatDate(item.scheduled_date) }}
      </template>
      <template #item.assignees="{ item }">
        {{ getAssignees(item) || '未割当' }}
      </template>
      <template #item.status="{ item }">
        <v-chip :color="statusColor[item.status]" size="small">
          {{ statusLabel[item.status] }}
        </v-chip>
      </template>
    </v-data-table>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>定期整備作成</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="form.title" label="タイトル *" class="mb-2" />
          <v-select
            v-model="form.equipment_id"
            :items="equipments"
            item-title="name"
            item-value="id"
            label="設備 *"
            class="mb-2"
          />
          <v-text-field v-model="form.scheduled_date" label="予定日 *" type="date" class="mb-2" />
          <v-textarea v-model="form.description" label="説明" rows="3" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="save">作成</v-btn>
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
