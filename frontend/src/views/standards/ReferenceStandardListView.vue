<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import CalibrationStateChip from '@/components/CalibrationStateChip.vue'
import FilterSelect from '@/components/FilterSelect.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import ReferenceStandardFormDialog from '@/components/ReferenceStandardFormDialog.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { ReferenceStandard } from '@/types/models'
import { latestGuard } from '@/utils/latestGuard'
import { CATEGORY_LABEL, STATUS_COLOR, STATUS_LABEL } from '@/utils/referenceStandard'

const router = useRouter()
const { canManageReferenceStandard } = usePermissions()
const authStore = useAuthStore()

const standards = ref<ReferenceStandard[]>([])
const loading = ref(false)
// 通常業務では自拠点の基準器だけ見ればよいため、自分の所属拠点を初期値にする（複数選択、空は全拠点）
const selectedSiteIds = ref<number[]>(authStore.user?.site_id ? [authStore.user.site_id] : [])
const statuses = ref<string[]>([])
const categories = ref<string[]>([])
const search = ref('')

const statusOptions = Object.entries(STATUS_LABEL).map(([value, title]) => ({ title, value }))
const categoryOptions = Object.entries(CATEGORY_LABEL).map(([value, title]) => ({ title, value }))

const headers = [
  { title: '管理番号', key: 'management_number', width: '120px' },
  { title: '名称', key: 'name', minWidth: '240px' },
  { title: '種別', key: 'category', width: '110px' },
  { title: '拠点', key: 'site.name', width: '120px' },
  { title: '状態', key: 'status', width: '100px' },
  { title: '校正', key: 'calibration_state', minWidth: '210px' },
  { title: '最終校正', key: 'last_calibration', sortable: false, minWidth: '190px' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
]

const fetchGuard = latestGuard()

async function fetchStandards() {
  const isLatest = fetchGuard()
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (selectedSiteIds.value.length) params.site_ids = selectedSiteIds.value
    if (statuses.value.length) params.statuses = statuses.value
    if (categories.value.length) params.categories = categories.value
    if (search.value) params.q = search.value
    const res = await api.get('/reference_standards', { params })
    if (!isLatest()) return
    standards.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

// --- 登録・編集（ダイアログは詳細画面と共通） ---
const dialog = ref(false)
const editing = ref<ReferenceStandard | null>(null)

function openCreate() {
  editing.value = null
  dialog.value = true
}

function openEdit(item: ReferenceStandard) {
  editing.value = item
  dialog.value = true
}

onMounted(fetchStandards)
watch([selectedSiteIds, statuses, categories, search], fetchStandards)
</script>

<template>
  <MainLayout>
    <PageHeader title="基準器" description="校正に使う基準器（圧力校正器・マルチテスタ・温度校正器など）の台帳です。メーカー校正の履歴と期限を管理し、点検で使った基準器をたどれます。">
      <v-btn v-if="canManageReferenceStandard" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規登録</v-btn>
    </PageHeader>

    <div class="pk-filters">
      <SiteScopeTag v-model="selectedSiteIds" />
      <v-divider vertical class="pk-scope-divider" />
      <FilterSelect v-model="statuses" :items="statusOptions" label="状態" style="max-width: 200px" />
      <FilterSelect v-model="categories" :items="categoryOptions" label="種別" style="max-width: 200px" />
      <v-text-field v-model="search" label="管理番号・名称・型式・製造番号" density="compact" hide-details clearable prepend-inner-icon="mdi-magnify" style="max-width: 320px" />
    </div>

    <v-data-table
      :headers="headers"
      :items="standards"
      :loading="loading"
      :sort-by="[{ key: 'management_number', order: 'asc' }]"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => router.push(`/reference-standards/${item.id}`)"
    >
      <template #item.category="{ item }">{{ CATEGORY_LABEL[item.category] }}</template>
      <template #item.status="{ item }">
        <v-chip :color="STATUS_COLOR[item.status]" size="small" label variant="tonal">{{ STATUS_LABEL[item.status] }}</v-chip>
      </template>
      <template #item.calibration_state="{ item }">
        <CalibrationStateChip :state="item.calibration_state" :next-due-on="item.next_due_on" />
      </template>
      <template #item.last_calibration="{ item }">
        <template v-if="item.calibrations[0]">
          <div class="text-no-wrap">{{ item.calibrations[0].performed_on }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.calibrations[0].performed_by }}</div>
        </template>
        <span v-else class="text-medium-emphasis">—</span>
      </template>
      <template #item.actions="{ item }">
        <v-btn v-if="canManageReferenceStandard" icon="mdi-pencil" size="x-small" variant="text" @click.stop="openEdit(item)" />
      </template>
    </v-data-table>

    <ReferenceStandardFormDialog
      v-model="dialog"
      :standard="editing"
      :default-site-id="selectedSiteIds.length === 1 ? selectedSiteIds[0] : null"
      @saved="fetchStandards"
    />
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
