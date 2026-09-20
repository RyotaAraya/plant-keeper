<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import ResourceHistory from '@/components/ResourceHistory.vue'
import SiteEquipmentSelect from '@/components/SiteEquipmentSelect.vue'
import {
  ACCEPTANCE_RESULT_COLOR,
  ACCEPTANCE_RESULT_LABEL,
  MAINTENANCE_STATUS_COLOR,
  MAINTENANCE_STATUS_FLOW,
  MAINTENANCE_STATUS_LABEL,
  MAINTENANCE_TRANSITIONS,
  periodLabel,
  transitionLabel,
} from '@/constants/maintenanceStatus'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import { todayForInput } from '@/utils/datetime'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { canManageMaintenance } = usePermissions()
const maintenance = ref<any>(null)
const loading = ref(true)
const users = ref<any[]>([])
const actionError = ref('')

const nextStatuses = computed<string[]>(() => MAINTENANCE_TRANSITIONS[maintenance.value?.status] ?? [])
// 完了にできるのは、検収の記録があり、結果が「手直しあり」でないとき
const canComplete = computed(() => {
  const m = maintenance.value
  return !!m?.accepted_on && !!m?.accepted_by && !!m?.acceptance_result && m.acceptance_result !== 'rework_required'
})
const showAcceptance = computed(() => ['acceptance', 'completed'].includes(maintenance.value?.status) || !!maintenance.value?.acceptance_result)

async function fetchMaintenance() {
  loading.value = true
  try {
    const res = await api.get(`/scheduled_maintenances/${route.params.id}`)
    maintenance.value = res.data.data
  } finally {
    loading.value = false
  }
}

// 状態を進める・戻す
async function changeStatus(status: string) {
  actionError.value = ''
  try {
    await api.patch(`/scheduled_maintenances/${route.params.id}`, { scheduled_maintenance: { status } })
    await fetchMaintenance()
  } catch (e: any) {
    actionError.value = (e.response?.data?.errors || ['状態を変更できませんでした']).join('、')
  }
}

// --- 編集 ---
const editDialog = ref(false)
const editForm = ref({
  title: '', description: '', planned_start_on: '', planned_end_on: '', actual_start_on: '', actual_end_on: '', used_materials: '',
  equipment_ids: [] as number[],
})
const editErrors = ref<string[]>([])

function openEdit() {
  const m = maintenance.value
  editForm.value = {
    title: m.title, description: m.description || '', planned_start_on: m.planned_start_on || '', planned_end_on: m.planned_end_on || '',
    actual_start_on: m.actual_start_on || '', actual_end_on: m.actual_end_on || '', used_materials: m.used_materials || '',
    equipment_ids: (m.equipments || []).map((e: any) => e.id),
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

// --- 検収の記録 ---
const acceptanceDialog = ref(false)
const acceptanceForm = ref({ accepted_on: '', acceptance_result: 'passed', acceptance_notes: '' })
const acceptanceErrors = ref<string[]>([])
const acceptanceOptions = Object.entries(ACCEPTANCE_RESULT_LABEL).map(([value, title]) => ({ title, value }))

function openAcceptance() {
  const m = maintenance.value
  acceptanceForm.value = { accepted_on: m.accepted_on || todayForInput(), acceptance_result: m.acceptance_result || 'passed', acceptance_notes: m.acceptance_notes || '' }
  acceptanceErrors.value = []
  acceptanceDialog.value = true
}

async function saveAcceptance() {
  acceptanceErrors.value = []
  try {
    await api.patch(`/scheduled_maintenances/${route.params.id}`, { scheduled_maintenance: acceptanceForm.value })
    acceptanceDialog.value = false
    await fetchMaintenance()
  } catch (e: any) {
    acceptanceErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

// --- 担当者 ---
const assignDialog = ref(false)
const assignForm = ref({ user_id: null as number | null, role: 'member' })
const assignErrors = ref<string[]>([])
const roleOptions = [
  { title: '主担当', value: 'lead' },
  { title: 'メンバー', value: 'member' },
]

async function openAssign() {
  if (!users.value.length) {
    const res = await api.get('/users', { params: { per_page: 200 } })
    users.value = res.data.data
  }
  assignForm.value = { user_id: null, role: 'member' }
  assignErrors.value = []
  assignDialog.value = true
}

async function saveAssign() {
  assignErrors.value = []
  try {
    await api.post('/maintenance_assignments', { maintenance_assignment: { scheduled_maintenance_id: maintenance.value.id, ...assignForm.value } })
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
      maintenance_assignment: { scheduled_maintenance_id: maintenance.value.id, user_id: authStore.user?.id, role: 'member' },
    })
    await fetchMaintenance()
  } catch { /* ignore */ }
}

onMounted(fetchMaintenance)
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading && !maintenance" indeterminate />
    <template v-else-if="maintenance">
      <div class="d-flex align-center mb-2">
        <v-btn icon="mdi-arrow-left" variant="text" @click="router.push('/maintenances')" />
        <h1 class="text-h5 ml-2">{{ maintenance.title }}</h1>
        <v-spacer />
        <v-btn v-if="canManageMaintenance" variant="outlined" @click="openEdit"><v-icon start>mdi-pencil</v-icon>編集</v-btn>
      </div>

      <!-- 状態の流れ -->
      <div class="d-flex align-center flex-wrap ga-2 mb-2" data-testid="maintenance-flow">
        <template v-for="(status, i) in MAINTENANCE_STATUS_FLOW" :key="status">
          <v-icon v-if="i > 0" size="small" color="grey" aria-hidden="true">mdi-chevron-right</v-icon>
          <v-chip
            :color="MAINTENANCE_STATUS_COLOR[status]"
            :variant="status === maintenance.status ? 'flat' : 'outlined'"
            size="small"
            :data-testid="status === maintenance.status ? 'maintenance-status' : undefined"
          >
            {{ MAINTENANCE_STATUS_LABEL[status] }}
          </v-chip>
        </template>
      </div>
      <div v-if="canManageMaintenance && nextStatuses.length" class="d-flex align-center flex-wrap ga-2 mb-3">
        <v-btn
          v-for="status in nextStatuses"
          :key="status"
          size="small"
          :color="status === 'completed' ? 'success' : 'primary'"
          :variant="MAINTENANCE_STATUS_FLOW.indexOf(status as any) < MAINTENANCE_STATUS_FLOW.indexOf(maintenance.status) ? 'outlined' : 'flat'"
          :disabled="status === 'completed' && !canComplete"
          @click="changeStatus(status)"
        >
          {{ transitionLabel(maintenance.status, status) }}
        </v-btn>
        <span v-if="nextStatuses.includes('completed') && !canComplete" class="text-caption text-medium-emphasis">
          完了にするには、検収を記録してください（結果が「手直しあり」のときは、実施中に戻して手直しします）
        </span>
      </div>
      <v-alert v-if="actionError" type="error" density="compact" class="mb-3" closable @click:close="actionError = ''">{{ actionError }}</v-alert>

      <v-card class="mb-4">
        <v-card-text>
          <v-row>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">拠点</div>
              <div>{{ maintenance.site?.name }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">予定期間</div>
              <div>{{ periodLabel(maintenance.planned_start_on, maintenance.planned_end_on) }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">実績期間</div>
              <div>{{ maintenance.actual_start_on || maintenance.actual_end_on ? periodLabel(maintenance.actual_start_on, maintenance.actual_end_on) : '—' }}</div>
            </v-col>
            <v-col cols="12">
              <div class="text-caption text-grey">対象設備（{{ maintenance.equipments?.length ?? 0 }}）</div>
              <v-chip
                v-for="equipment in maintenance.equipments"
                :key="equipment.id"
                size="small"
                label
                variant="tonal"
                class="mr-1 mt-1"
                style="cursor: pointer"
                @click="router.push(`/equipments/${equipment.id}`)"
              >
                {{ equipment.name }}
              </v-chip>
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

      <!-- 検収 -->
      <v-card v-if="showAcceptance" class="mb-4" data-testid="acceptance-card">
        <v-card-title class="d-flex align-center text-subtitle-1">
          検収
          <v-spacer />
          <v-btn v-if="canManageMaintenance && maintenance.status === 'acceptance'" size="small" color="primary" prepend-icon="mdi-clipboard-check-outline" @click="openAcceptance">
            検収を記録
          </v-btn>
        </v-card-title>
        <v-card-text>
          <p v-if="!maintenance.acceptance_result" class="text-body-2 text-medium-emphasis">検収の記録はまだありません。</p>
          <v-row v-else>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">検収日</div>
              <div>{{ maintenance.accepted_on }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">検収者</div>
              <div>{{ maintenance.accepted_by?.name }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">結果</div>
              <v-chip :color="ACCEPTANCE_RESULT_COLOR[maintenance.acceptance_result]" size="small" label variant="tonal">
                {{ ACCEPTANCE_RESULT_LABEL[maintenance.acceptance_result] }}
              </v-chip>
            </v-col>
            <v-col v-if="maintenance.acceptance_notes" cols="12">
              <div class="text-caption text-grey">指摘事項</div>
              <div style="white-space: pre-wrap">{{ maintenance.acceptance_notes }}</div>
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <div class="d-flex align-center mb-3">
        <h2 class="text-h6">担当者</h2>
        <v-spacer />
        <v-btn v-if="canManageMaintenance" size="small" variant="text" class="mr-2" @click="quickAssignSelf"><v-icon start>mdi-account-plus</v-icon>自分を追加</v-btn>
        <v-btn v-if="canManageMaintenance" size="small" variant="outlined" prepend-icon="mdi-plus" @click="openAssign">担当追加</v-btn>
      </div>

      <v-list v-if="maintenance.maintenance_assignments?.length">
        <v-list-item v-for="a in maintenance.maintenance_assignments" :key="a.id" :title="a.user?.name" :subtitle="a.role === 'lead' ? '主担当' : 'メンバー'">
          <template #prepend>
            <v-icon :color="a.role === 'lead' ? 'primary' : 'grey'">{{ a.role === 'lead' ? 'mdi-account-star' : 'mdi-account' }}</v-icon>
          </template>
          <template #append>
            <v-btn v-if="canManageMaintenance" icon="mdi-close" size="x-small" variant="text" @click="removeAssignment(a.id)" />
          </template>
        </v-list-item>
      </v-list>
      <div v-else class="text-center text-grey py-4">担当者が割り当てられていません</div>

      <v-divider class="my-4" />
      <h2 class="text-h6 mb-3">変更履歴</h2>
      <ResourceHistory auditable-type="ScheduledMaintenance" :auditable-id="maintenance.id" />

      <!-- 編集 -->
      <v-dialog v-model="editDialog" max-width="640" scrollable>
        <v-card>
          <v-card-title>定期整備の編集</v-card-title>
          <v-card-text>
            <v-alert v-if="editErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in editErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-text-field v-model="editForm.title" label="名称 *" class="mb-2" />
            <v-row dense>
              <v-col cols="6"><v-text-field v-model="editForm.planned_start_on" label="予定 開始日 *" type="date" /></v-col>
              <v-col cols="6"><v-text-field v-model="editForm.planned_end_on" label="予定 終了日" type="date" /></v-col>
              <v-col cols="6"><v-text-field v-model="editForm.actual_start_on" label="実績 開始日" type="date" /></v-col>
              <v-col cols="6"><v-text-field v-model="editForm.actual_end_on" label="実績 終了日" type="date" /></v-col>
            </v-row>
            <SiteEquipmentSelect v-model="editForm.equipment_ids" :site-id="maintenance.site_id" class="mb-2" />
            <v-textarea v-model="editForm.description" label="説明" rows="3" class="mt-2 mb-2" />
            <v-text-field v-model="editForm.used_materials" label="使用資材" />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn @click="editDialog = false">キャンセル</v-btn>
            <v-btn color="primary" @click="saveEdit">保存</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>

      <!-- 検収の記録 -->
      <v-dialog v-model="acceptanceDialog" max-width="520">
        <v-card>
          <v-card-title>検収を記録</v-card-title>
          <v-card-text>
            <div class="text-caption text-medium-emphasis mb-3">整備が終わったあとの完了確認です。検収者は、記録した人になります。</div>
            <v-alert v-if="acceptanceErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in acceptanceErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-text-field v-model="acceptanceForm.accepted_on" label="検収日 *" type="date" class="mb-2" />
            <v-select v-model="acceptanceForm.acceptance_result" :items="acceptanceOptions" item-title="title" item-value="value" label="結果 *" class="mb-2" />
            <v-textarea v-model="acceptanceForm.acceptance_notes" label="指摘事項" rows="3" />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn @click="acceptanceDialog = false">キャンセル</v-btn>
            <v-btn color="primary" @click="saveAcceptance">記録</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>

      <!-- 担当者追加 -->
      <v-dialog v-model="assignDialog" max-width="400">
        <v-card>
          <v-card-title>担当者追加</v-card-title>
          <v-card-text>
            <v-alert v-if="assignErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in assignErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-autocomplete v-model="assignForm.user_id" :items="users" item-title="name" item-value="id" label="担当者 *" clearable class="mb-2" />
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
