<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const router = useRouter()
const users = ref<any[]>([])
const departments = ref<any[]>([])
const loading = ref(false)
const showInactive = ref(false)

const filters = ref({
  q: '',
  role: null as string | null,
  department_id: null as number | null,
})

const headers = [
  { title: '名前', key: 'name' },
  { title: 'メール', key: 'email' },
  { title: '役割', key: 'role', width: '100px' },
  { title: '部署', key: 'department.name', width: '160px' },
  { title: '入社年', key: 'join_year', width: '80px' },
  { title: '状態', key: 'is_active', width: '80px' },
]

const roleLabel: Record<string, string> = {
  worker: '作業員', contractor: '協力会社', supervisor: '監督', maintenance: '保全', admin: '管理者', environment: '環境安全'
}
const roleOptions = [
  { title: '作業員', value: 'worker' },
  { title: '協力会社', value: 'contractor' },
  { title: '監督', value: 'supervisor' },
  { title: '保全', value: 'maintenance' },
  { title: '管理者', value: 'admin' },
  { title: '環境安全', value: 'environment' },
]

async function fetchUsers() {
  loading.value = true
  try {
    const params: any = {}
    if (filters.value.q) params.q = filters.value.q
    if (filters.value.role) params.role = filters.value.role
    if (filters.value.department_id) params.department_id = filters.value.department_id
    if (!showInactive.value) params.is_active = true
    const res = await api.get('/users', { params })
    users.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function fetchDepartments() {
  const res = await api.get('/departments')
  departments.value = res.data.data
}

function goToDetail(row: any) {
  router.push(`/users/${row.id}`)
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
        v-model="filters.role"
        :items="roleOptions"
        item-title="title"
        item-value="value"
        label="役割"
        clearable
        density="compact"
        hide-details
        style="max-width: 140px"
      />
      <v-select
        v-model="filters.department_id"
        :items="departments"
        item-title="name"
        item-value="id"
        label="部署"
        clearable
        density="compact"
        hide-details
        style="max-width: 180px"
      />
      <v-switch v-model="showInactive" label="退職者表示" density="compact" hide-details />
    </div>

    <v-data-table
      :headers="headers"
      :items="users"
      :loading="loading"
      hover
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
      class="cursor-pointer"
    >
      <template #item.role="{ item }">
        {{ roleLabel[item.role] || item.role }}
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
