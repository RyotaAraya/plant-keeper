<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { listFromQuery, siteIdsFromQuery } from '@/utils/listQuery'
import api from '@/api/axios'
import FilterSelect from '@/components/FilterSelect.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import SiteEquipmentSelect from '@/components/SiteEquipmentSelect.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { MAINTENANCE_STATUS_COLOR, MAINTENANCE_STATUS_LABEL, periodLabel } from '@/constants/maintenanceStatus'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import { latestGuard } from '@/utils/latestGuard'

const router = useRouter()
const route = useRoute()
const { canManageMaintenance, canViewSites } = usePermissions()
const authStore = useAuthStore()

const maintenances = ref<any[]>([])
const { equipments, load: loadSiteOptions } = useSiteScopeOptions({ withDepartments: false })
const sites = ref<any[]>([])
const loading = ref(false)
const dialog = ref(false)
const errors = ref<string[]>([])

// 通常業務では自拠点の整備だけ見ればよいため、自分の所属拠点を初期値にする
const filters = ref({
  site_ids: siteIdsFromQuery(route.query.site_ids, authStore.user?.site_id ? [authStore.user.site_id] : []),
  equipment_ids: [] as number[],
  // 朝会ボードなどから、状態の絞り込み（?status=in_progress）を引き継ぐ
  statuses: listFromQuery(route.query.status),
})

const form = ref({
  title: '',
  site_id: null as number | null,
  planned_start_on: '',
  planned_end_on: '',
  equipment_ids: [] as number[],
  description: '',
})

const headers = [
  { title: '予定期間', key: 'planned_start_on', width: '190px' },
  { title: '名称', key: 'title' },
  { title: '対象設備', key: 'equipments', sortable: false },
  { title: '系列', key: 'maintenance_series.name', width: '150px' },
  { title: '作業', key: 'tasks_summary', sortable: false, width: '90px' },
  { title: '担当者', key: 'assignees', sortable: false, width: '170px' },
  { title: '状態', key: 'status', width: '100px' },
]

const statusOptions = Object.entries(MAINTENANCE_STATUS_LABEL).map(([value, title]) => ({ title, value }))

const fetchGuard = latestGuard()

async function fetchMaintenances() {
  const isLatest = fetchGuard()
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.equipment_ids.length) params.equipment_ids = filters.value.equipment_ids
    if (filters.value.statuses.length) params.statuses = filters.value.statuses
    const res = await api.get('/scheduled_maintenances', { params })
    if (!isLatest()) return
    maintenances.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

// 拠点を変えたら、表示する拠点にない設備の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
function changeSite(siteIds: number[]) {
  const shown = (id: number) => siteIds.length === 0 || siteIds.includes(id)
  const keepEquipment = filters.value.equipment_ids.filter((id) => equipments.value.find((e) => e.id === id && shown(e.site_id)))
  filters.value = { ...filters.value, site_ids: siteIds, equipment_ids: keepEquipment }
  loadSiteOptions(siteIds)
}

const assignees = (item: any) =>
  (item.maintenance_assignments || []).map((a: any) => `${a.user?.name || ''}${a.role === 'lead' ? '(主)' : ''}`).join(', ')

async function openCreate() {
  if (canViewSites.value && !sites.value.length) {
    const res = await api.get('/sites', { params: { per_page: 100 } })
    sites.value = res.data.data
  }
  form.value = {
    title: '',
    site_id: (filters.value.site_ids.length === 1 ? filters.value.site_ids[0] : authStore.user?.site_id) ?? null,
    planned_start_on: '', planned_end_on: '', equipment_ids: [], description: '',
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

onMounted(() => {
  loadSiteOptions(filters.value.site_ids)
  fetchMaintenances()
})
watch(filters, fetchMaintenances, { deep: true })
watch(() => [route.query.site_ids, route.query.status], ([value, status]) => {
  if (route.path !== '/maintenances') return
  const siteIds = siteIdsFromQuery(value, authStore.user?.site_id ? [authStore.user.site_id] : [])
  filters.value = { site_ids: siteIds, equipment_ids: [], statuses: listFromQuery(status) }
  loadSiteOptions(siteIds)
})
</script>

<template>
  <MainLayout>
    <PageHeader title="定期整備" description="関連設備を停止して行う整備の予定と実績です。複数の設備をまとめて整備し、終わったら検収します。運転中に周期で回す点検は「点検計画」へ。">
      <v-btn v-if="canManageMaintenance" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規作成</v-btn>
    </PageHeader>

    <div class="pk-filters">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <FilterSelect v-model="filters.equipment_ids" :items="equipments" item-title="name" item-value="id" label="設備" searchable style="max-width: 240px" />
      <FilterSelect v-model="filters.statuses" :items="statusOptions" label="状態" style="max-width: 200px" />
    </div>

    <v-data-table
      :headers="headers"
      :items="maintenances"
      :loading="loading"
      :sort-by="[{ key: 'planned_start_on', order: 'desc' }]"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => router.push(`/maintenances/${item.id}`)"
    >
      <template #item.planned_start_on="{ item }"><span class="text-no-wrap">{{ periodLabel(item.planned_start_on, item.planned_end_on) }}</span></template>
      <template #item.equipments="{ item }">
        <v-chip v-for="equipment in item.equipments" :key="equipment.id" size="x-small" label variant="tonal" class="mr-1 my-1">{{ equipment.name }}</v-chip>
      </template>
      <template #item.tasks_summary="{ item }">
        <span v-if="item.tasks_summary?.total" class="text-no-wrap">{{ item.tasks_summary.completed }} / {{ item.tasks_summary.total }}</span>
        <span v-else class="text-medium-emphasis">—</span>
      </template>
      <template #item.assignees="{ item }">{{ assignees(item) || '未割当' }}</template>
      <template #item.status="{ item }">
        <v-chip :color="MAINTENANCE_STATUS_COLOR[item.status]" size="small">{{ MAINTENANCE_STATUS_LABEL[item.status] }}</v-chip>
      </template>
    </v-data-table>

    <v-dialog v-model="dialog" max-width="640" scrollable>
      <v-card>
        <v-card-title>定期整備の作成</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="form.title" label="名称 *（例: 2026年 A号ボイラー整備）" class="mb-2" />
          <v-select v-if="canViewSites" v-model="form.site_id" :items="sites" item-title="name" item-value="id" label="拠点 *" class="mb-2" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model="form.planned_start_on" label="予定 開始日 *" type="date" /></v-col>
            <v-col cols="6"><v-text-field v-model="form.planned_end_on" label="予定 終了日" type="date" /></v-col>
          </v-row>
          <SiteEquipmentSelect v-model="form.equipment_ids" :site-id="form.site_id" class="mb-2" />
          <v-textarea v-model="form.description" label="説明" rows="3" class="mt-2" />
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
