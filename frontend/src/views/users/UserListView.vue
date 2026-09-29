<script setup lang="ts">
import { computed, ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { useSiteScope } from '@/composables/useSiteScope'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { latestGuard } from '@/utils/latestGuard'

const route = useRoute()
const router = useRouter()
const { initialSiteIds } = useSiteScope()
const users = ref<any[]>([])
const { departments, load: loadSiteOptions } = useSiteScopeOptions({ withEquipments: false })
const loading = ref(false)
const showInactive = ref(false)

// 通常業務では自拠点のユーザだけ見ればよいため、自分の所属拠点を初期値にする（空は全拠点）
const filters = ref({
  site_ids: initialSiteIds(route.query.site_ids),
  q: '',
  employment_type: null as string | null,
  system_role: null as string | null,
  department_id: null as number | null,
})

// 1行に収まる列だけにする。入社年は詳細画面で見られる。
// 拠点は、1拠点だけ表示しているときは絞り込み欄で分かるので出さない。状態は、退職者を表示するときだけ出す（通常は全員「在籍」）
const headers = computed(() => [
  { title: '名前', key: 'name' },
  { title: 'メール', key: 'email' },
  { title: '権限', key: 'system_role' },
  { title: '在籍区分', key: 'employment_type' },
  { title: '所属会社', key: 'company' },
  ...(filters.value.site_ids.length === 1 ? [] : [{ title: '拠点', key: 'site.name' }]),
  { title: '部署', key: 'department_path' },
  ...(showInactive.value ? [{ title: '状態', key: 'is_active' }] : []),
])

const employmentTypeLabel: Record<string, string> = {
  employee: '正社員', dispatch: '派遣社員', contractor: '協力会社員',
}
const employmentTypeOptions = [
  { title: '正社員', value: 'employee' },
  { title: '派遣社員', value: 'dispatch' },
  { title: '協力会社員', value: 'contractor' },
]

const systemRoleLabel: Record<string, string> = {
  admin: 'システム管理者', manager: '業務管理者', member: '一般', worker: '技能員',
}
const systemRoleOptions = [
  { title: 'システム管理者', value: 'admin' },
  { title: '業務管理者', value: 'manager' },
  { title: '一般', value: 'member' },
  { title: '技能員', value: 'worker' },
]

// 拠点を変えたら、表示する拠点にない部署の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
async function changeSite(siteIds: number[]) {
  filters.value = { ...filters.value, site_ids: siteIds }
  await loadSiteOptions(siteIds)
  if (filters.value.department_id && !departments.value.some((d) => d.id === filters.value.department_id)) {
    filters.value = { ...filters.value, department_id: null }
  }
}

const fetchUsersGuard = latestGuard()

async function fetchUsers() {
  const isLatest = fetchUsersGuard()
  loading.value = true
  try {
    const params: any = {}
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.q) params.q = filters.value.q
    if (filters.value.employment_type) params.employment_type = filters.value.employment_type
    if (filters.value.system_role) params.system_role = filters.value.system_role
    if (filters.value.department_id) params.department_id = filters.value.department_id
    if (!showInactive.value) params.is_active = true
    const res = await api.get('/users', { params })
    if (!isLatest()) return
    users.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

function departmentPath(user: any): string {
  return user.company?.company_type === 'owner' ? (user.department?.full_path || '—') : '—'
}

function goToDetail(row: any) {
  router.push(`/users/${row.id}`)
}

const AVATAR_COLORS = [
  '#1565C0', '#2E7D32', '#6A1B9A', '#00838F',
  '#E65100', '#AD1457', '#4527A0', '#00695C',
]
function avatarColor(id: number) {
  return AVATAR_COLORS[id % AVATAR_COLORS.length]
}
function nameInitial(name: string) {
  return name.charAt(0)
}

onMounted(() => {
  loadSiteOptions(filters.value.site_ids)
  fetchUsers()
})
watch([filters, showInactive], fetchUsers, { deep: true })
</script>

<template>
  <MainLayout>
    <PageHeader title="ユーザ管理" description="ユーザの所属会社・雇用区分・権限を管理します。退職・復帰の対応もここで行います。" />

    <div class="pk-filters">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <v-text-field
        v-model="filters.q"
        label="名前・メール検索"
        prepend-inner-icon="mdi-magnify"
        clearable
        density="compact"
        hide-details
        style="max-width: 220px"
      />
      <v-select
        v-model="filters.employment_type"
        :items="employmentTypeOptions"
        item-title="title"
        item-value="value"
        label="在籍区分"
        clearable
        density="compact"
        hide-details
        style="max-width: 140px"
      />
      <v-select
        v-model="filters.system_role"
        :items="systemRoleOptions"
        item-title="title"
        item-value="value"
        label="権限"
        clearable
        density="compact"
        hide-details
        style="max-width: 120px"
      />
      <v-select
        v-model="filters.department_id"
        :items="departments"
        item-title="display_name"
        item-value="id"
        label="部署"
        clearable
        density="compact"
        hide-details
        style="max-width: 320px"
      />
      <v-switch v-model="showInactive" label="退職者表示" density="compact" hide-details />
    </div>

    <v-data-table
      :headers="headers"
      :items="users"
      :loading="loading"
      hover
      class="cursor-pointer pk-users"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.name="{ item }">
        <div class="d-flex align-center ga-2 py-1">
          <v-avatar :color="avatarColor(item.id)" size="32">
            <span class="text-white text-body-2 font-weight-bold">{{ nameInitial(item.name) }}</span>
          </v-avatar>
          <span class="pk-users__name">{{ item.name }}</span>
        </div>
      </template>
      <template #item.email="{ item }">
        <span class="pk-users__ellipsis text-medium-emphasis" :title="item.email">{{ item.email }}</span>
      </template>
      <template #item.employment_type="{ item }">
        {{ employmentTypeLabel[item.employment_type] || item.employment_type }}
      </template>
      <template #item.system_role="{ item }">
        {{ systemRoleLabel[item.system_role] || item.system_role }}
      </template>
      <template #item.company="{ item }">
        <span class="mr-2">{{ item.company?.name || '—' }}</span>
        <v-chip
          v-if="item.company"
          :color="item.company.company_type === 'owner' ? 'primary' : 'orange'"
          size="x-small"
          label
          variant="tonal"
        >
          {{ item.company.company_type === 'owner' ? '自社' : '協力' }}
        </v-chip>
      </template>
      <template #item.department_path="{ item }">
        <span class="pk-users__ellipsis" :title="departmentPath(item)">{{ departmentPath(item) }}</span>
      </template>
      <template #item.is_active="{ item }">
        <v-chip :color="item.is_active ? 'success' : 'grey'" size="x-small">
          {{ item.is_active ? '在籍' : '退職' }}
        </v-chip>
      </template>
    </v-data-table>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}

/* 各セルは折り返さず1行にする。長いメールと部署だけは、省略して全体を（title で）読めるようにする */
.pk-users :deep(td),
.pk-users :deep(th) {
  padding: 0 12px !important;
  white-space: nowrap;
}

.pk-users__name {
  font-weight: 500;
}

.pk-users__ellipsis {
  display: block;
  max-width: 17rem;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
