<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const router = useRouter()
const users = ref<any[]>([])
const departmentTree = ref<any[]>([])
const loading = ref(false)
const showInactive = ref(false)

const filters = ref({
  q: '',
  employment_type: null as string | null,
  system_role: null as string | null,
  department_id: null as number | null,
})

const headers = [
  { title: '名前', key: 'name' },
  { title: 'メール', key: 'email' },
  { title: '在籍区分', key: 'employment_type', width: '100px' },
  { title: '権限', key: 'system_role', width: '80px' },
  { title: '所属会社', key: 'company', width: '140px' },
  { title: '部署', key: 'department_path', width: '280px' },
  { title: '入社年', key: 'join_year', width: '80px' },
  { title: '状態', key: 'is_active', width: '80px' },
]

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

const levelLabel: Record<string, string> = {
  division: '部', section: '課', team: 'チーム',
}

// ツリーをフラットリストに変換（インデント付き）
function flattenTree(nodes: any[], depth = 0): any[] {
  const result: any[] = []
  for (const node of nodes) {
    const indent = '\u00A0\u00A0'.repeat(depth)
    result.push({
      id: node.id,
      name: node.name,
      title: `${indent}${node.name}（${levelLabel[node.level] || node.level}）`,
      level: node.level,
      depth,
    })
    if (node.children?.length) {
      result.push(...flattenTree(node.children, depth + 1))
    }
  }
  return result
}

const flatDepartments = computed(() => flattenTree(departmentTree.value))

async function fetchUsers() {
  loading.value = true
  try {
    const params: any = {}
    if (filters.value.q) params.q = filters.value.q
    if (filters.value.employment_type) params.employment_type = filters.value.employment_type
    if (filters.value.system_role) params.system_role = filters.value.system_role
    if (filters.value.department_id) params.department_id = filters.value.department_id
    if (!showInactive.value) params.is_active = true
    const res = await api.get('/users', { params })
    users.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function fetchDepartments() {
  const res = await api.get('/departments', { params: { tree: 'true' } })
  departmentTree.value = res.data.data
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
  fetchDepartments()
  fetchUsers()
})
watch([filters, showInactive], fetchUsers, { deep: true })
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">ユーザ管理</h1>
    </div>

    <div class="d-flex ga-4 mb-4 flex-wrap align-center">
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
        :items="flatDepartments"
        item-title="title"
        item-value="id"
        label="部署"
        clearable
        density="compact"
        hide-details
        style="max-width: 260px"
      />
      <v-switch v-model="showInactive" label="退職者表示" density="compact" hide-details />
    </div>

    <v-data-table
      :headers="headers"
      :items="users"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.name="{ item }">
        <div class="d-flex align-center ga-2 py-1">
          <v-avatar :color="avatarColor(item.id)" size="32">
            <span class="text-white text-body-2 font-weight-bold">{{ nameInitial(item.name) }}</span>
          </v-avatar>
          <span>{{ item.name }}</span>
        </div>
      </template>
      <template #item.employment_type="{ item }">
        {{ employmentTypeLabel[item.employment_type] || item.employment_type }}
      </template>
      <template #item.system_role="{ item }">
        {{ systemRoleLabel[item.system_role] || item.system_role }}
      </template>
      <template #item.company="{ item }">
        <span class="mr-1">{{ item.company?.name || '—' }}</span>
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
        {{ item.company?.company_type === 'owner' ? (item.department?.full_path || '—') : '—' }}
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
</style>
