<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { useAuthStore } from '@/stores/auth'
import { usePermissions } from '@/composables/usePermissions'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { canManageMaintenance } = usePermissions()
const maintenance = ref<any>(null)
const loading = ref(true)
const users = ref<any[]>([])

// Edit dialog
const editDialog = ref(false)
const editForm = ref({ title: '', description: '', scheduled_date: '', completed_date: '', status: '', used_materials: '' })
const editErrors = ref<string[]>([])

// Assignment dialog
const assignDialog = ref(false)
const assignForm = ref({ user_id: null as number | null, role: 'member' })
const assignErrors = ref<string[]>([])

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
const roleOptions = [
  { title: '主担当', value: 'lead' },
  { title: 'メンバー', value: 'member' },
]

async function fetchMaintenance() {
  loading.value = true
  try {
    const res = await api.get(`/scheduled_maintenances/${route.params.id}`)
    maintenance.value = res.data.data
  } finally {
    loading.value = false
  }
}

function openEdit() {
  editForm.value = {
    title: maintenance.value.title,
    description: maintenance.value.description || '',
    scheduled_date: maintenance.value.scheduled_date || '',
    completed_date: maintenance.value.completed_date || '',
    status: maintenance.value.status,
    used_materials: maintenance.value.used_materials || '',
  }
  editErrors.value = []
  editDialog.value = true
}

async function saveEdit() {
  editErrors.value = []
  try {
    await api.patch(`/scheduled_maintenances/${route.params.id}`, { scheduled_maintenance: editForm.value })
    editDialog.value = false
    await fetchMaintenance()
  } catch (e: any) {
    editErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

async function fetchUsers() {
  if (users.value.length) return
  const res = await api.get('/users', { params: { per_page: 200 } })
  users.value = res.data.data
}

async function openAssign() {
  await fetchUsers()
  assignForm.value = { user_id: null, role: 'member' }
  assignErrors.value = []
  assignDialog.value = true
}

async function saveAssign() {
  assignErrors.value = []
  try {
    await api.post('/maintenance_assignments', {
      maintenance_assignment: {
        scheduled_maintenance_id: maintenance.value.id,
        ...assignForm.value,
      }
    })
    assignDialog.value = false
    await fetchMaintenance()
  } catch (e: any) {
    assignErrors.value = e.response?.data?.errors || ['追加に失敗しました']
  }
}

async function removeAssignment(id: number) {
  if (!confirm('この担当者を外しますか？')) return
  await api.delete(`/maintenance_assignments/${id}`)
  await fetchMaintenance()
}

async function quickAssignSelf() {
  try {
    await api.post('/maintenance_assignments', {
      maintenance_assignment: {
        scheduled_maintenance_id: maintenance.value.id,
        user_id: authStore.user?.id,
        role: 'member',
      }
    })
    await fetchMaintenance()
  } catch { /* ignore */ }
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleDateString('ja-JP')
}

onMounted(fetchMaintenance)
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="maintenance">
      <div class="d-flex align-center mb-4">
        <v-btn icon="mdi-arrow-left" variant="text" @click="router.push('/maintenances')" />
        <h1 class="text-h5 ml-2">{{ maintenance.title }}</h1>
        <v-spacer />
        <v-btn v-if="canManageMaintenance" variant="outlined" @click="openEdit">
          <v-icon start>mdi-pencil</v-icon>編集
        </v-btn>
      </div>

      <v-card class="mb-4">
        <v-card-text>
          <v-row>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">ステータス</div>
              <v-chip :color="statusColor[maintenance.status]" size="small">
                {{ statusLabel[maintenance.status] }}
              </v-chip>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">設備</div>
              <a class="text-primary" style="cursor:pointer" @click="router.push(`/equipments/${maintenance.equipment?.id}`)">
                {{ maintenance.equipment?.name }}
              </a>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">予定日</div>
              <div>{{ formatDate(maintenance.scheduled_date) }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">完了日</div>
              <div>{{ maintenance.completed_date ? formatDate(maintenance.completed_date) : '—' }}</div>
            </v-col>
          </v-row>
          <div v-if="maintenance.description" class="mt-3">
            <div class="text-caption text-grey">説明</div>
            <div style="white-space: pre-wrap">{{ maintenance.description }}</div>
          </div>
          <div v-if="maintenance.used_materials" class="mt-3">
            <div class="text-caption text-grey">使用資材</div>
            <div>{{ maintenance.used_materials }}</div>
          </div>
        </v-card-text>
      </v-card>

      <div class="d-flex align-center mb-3">
        <h2 class="text-h6">担当者</h2>
        <v-spacer />
        <v-btn v-if="canManageMaintenance" size="small" variant="text" class="mr-2" @click="quickAssignSelf">
          <v-icon start>mdi-account-plus</v-icon>自分を追加
        </v-btn>
        <v-btn v-if="canManageMaintenance" size="small" variant="outlined" prepend-icon="mdi-plus" @click="openAssign">担当追加</v-btn>
      </div>

      <v-list v-if="maintenance.maintenance_assignments?.length">
        <v-list-item
          v-for="a in maintenance.maintenance_assignments"
          :key="a.id"
          :title="a.user?.name"
          :subtitle="a.role === 'lead' ? '主担当' : 'メンバー'"
        >
          <template #prepend>
            <v-icon :color="a.role === 'lead' ? 'primary' : 'grey'">
              {{ a.role === 'lead' ? 'mdi-account-star' : 'mdi-account' }}
            </v-icon>
          </template>
          <template #append>
            <v-btn v-if="canManageMaintenance" icon="mdi-close" size="x-small" variant="text" @click="removeAssignment(a.id)" />
          </template>
        </v-list-item>
      </v-list>
      <div v-else class="text-center text-grey py-4">担当者が割り当てられていません</div>

      <!-- Edit Dialog -->
      <v-dialog v-model="editDialog" max-width="600">
        <v-card>
          <v-card-title>定期整備編集</v-card-title>
          <v-card-text>
            <v-alert v-if="editErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in editErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-text-field v-model="editForm.title" label="タイトル" class="mb-2" />
            <v-select v-model="editForm.status" :items="statusOptions" item-title="title" item-value="value" label="ステータス" class="mb-2" />
            <v-text-field v-model="editForm.scheduled_date" label="予定日" type="date" class="mb-2" />
            <v-text-field v-model="editForm.completed_date" label="完了日" type="date" class="mb-2" />
            <v-textarea v-model="editForm.description" label="説明" rows="3" class="mb-2" />
            <v-text-field v-model="editForm.used_materials" label="使用資材" />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn @click="editDialog = false">キャンセル</v-btn>
            <v-btn color="primary" @click="saveEdit">保存</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>

      <!-- Assignment Dialog -->
      <v-dialog v-model="assignDialog" max-width="400">
        <v-card>
          <v-card-title>担当者追加</v-card-title>
          <v-card-text>
            <v-alert v-if="assignErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in assignErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-autocomplete
              v-model="assignForm.user_id"
              :items="users"
              item-title="name"
              item-value="id"
              label="担当者 *"
              clearable
              class="mb-2"
            />
            <v-select v-model="assignForm.role" :items="roleOptions" item-title="title" item-value="value" label="役割" />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn @click="assignDialog = false">キャンセル</v-btn>
            <v-btn color="primary" @click="saveAssign">追加</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </template>
  </MainLayout>
</template>
