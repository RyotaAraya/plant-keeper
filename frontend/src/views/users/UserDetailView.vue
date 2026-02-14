<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const route = useRoute()
const router = useRouter()
const user = ref<any>(null)
const departments = ref<any[]>([])
const loading = ref(true)
const editDialog = ref(false)
const editForm = ref<any>({})
const editErrors = ref<string[]>([])

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

async function fetchUser() {
  loading.value = true
  try {
    const res = await api.get(`/users/${route.params.id}`)
    user.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function fetchDepartments() {
  const res = await api.get('/departments')
  departments.value = res.data.data
}

function openEdit() {
  editForm.value = {
    name: user.value.name,
    role: user.value.role,
    department_id: user.value.department_id,
    join_year: user.value.join_year,
    home_prefecture: user.value.home_prefecture || '',
    previous_company: user.value.previous_company || '',
    is_active: user.value.is_active,
  }
  editErrors.value = []
  editDialog.value = true
}

async function saveEdit() {
  editErrors.value = []
  try {
    const payload: any = { user: { ...editForm.value } }
    if (!editForm.value.is_active && user.value.is_active) {
      payload.user.deactivated_on = new Date().toISOString().slice(0, 10)
    }
    if (editForm.value.is_active && !user.value.is_active) {
      payload.user.deactivated_on = null
    }
    await api.patch(`/users/${route.params.id}`, payload)
    editDialog.value = false
    await fetchUser()
  } catch (e: any) {
    editErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

onMounted(() => {
  fetchUser()
  fetchDepartments()
})
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="user">
      <div class="d-flex align-center mb-4">
        <v-btn icon="mdi-arrow-left" variant="text" @click="router.push('/users')" />
        <h1 class="text-h5 ml-2">{{ user.name }}</h1>
        <v-chip class="ml-3" :color="user.is_active ? 'success' : 'grey'" size="small">
          {{ user.is_active ? '在籍' : '退職' }}
        </v-chip>
        <v-spacer />
        <v-btn variant="outlined" @click="openEdit">
          <v-icon start>mdi-pencil</v-icon>編集
        </v-btn>
      </div>

      <v-card class="mb-4">
        <v-card-text>
          <v-row>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">メール</div>
              <div>{{ user.email }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">役割</div>
              <div>{{ roleLabel[user.role] }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">部署</div>
              <div>{{ user.department?.name || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">入社年</div>
              <div>{{ user.join_year ? `${user.join_year}年` : '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">出身地</div>
              <div>{{ user.home_prefecture || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">前職</div>
              <div>{{ user.previous_company || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3" v-if="user.deactivated_on">
              <div class="text-caption text-grey">退職日</div>
              <div>{{ user.deactivated_on }}</div>
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <h2 class="text-h6 mb-3">設備担当</h2>
      <v-table density="compact" v-if="user.equipment_assignments?.length">
        <thead><tr><th>設備</th><th>役割</th><th>開始日</th><th>終了日</th></tr></thead>
        <tbody>
          <tr v-for="a in user.equipment_assignments" :key="a.id">
            <td>
              <a class="text-primary" style="cursor:pointer" @click="router.push(`/equipments/${a.equipment?.id}`)">
                {{ a.equipment?.name }}
              </a>
            </td>
            <td>{{ a.role === 'lead' ? '主担当' : 'メンバー' }}</td>
            <td>{{ a.started_on }}</td>
            <td>{{ a.ended_on || '—' }}</td>
          </tr>
        </tbody>
      </v-table>
      <div v-else class="text-grey">設備担当なし</div>

      <!-- Edit Dialog -->
      <v-dialog v-model="editDialog" max-width="600">
        <v-card>
          <v-card-title>ユーザ編集</v-card-title>
          <v-card-text>
            <v-alert v-if="editErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in editErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-text-field v-model="editForm.name" label="名前" class="mb-2" />
            <v-select v-model="editForm.role" :items="roleOptions" item-title="title" item-value="value" label="役割" class="mb-2" />
            <v-select v-model="editForm.department_id" :items="departments" item-title="name" item-value="id" label="部署" class="mb-2" />
            <v-text-field v-model.number="editForm.join_year" label="入社年" type="number" class="mb-2" />
            <v-text-field v-model="editForm.home_prefecture" label="出身地" class="mb-2" />
            <v-text-field v-model="editForm.previous_company" label="前職" class="mb-2" />
            <v-switch v-model="editForm.is_active" label="在籍" color="success" />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn @click="editDialog = false">キャンセル</v-btn>
            <v-btn color="primary" @click="saveEdit">保存</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </template>
  </MainLayout>
</template>
