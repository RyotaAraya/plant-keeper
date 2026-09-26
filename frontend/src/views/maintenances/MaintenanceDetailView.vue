<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import MaintenanceSeriesDialog from '@/components/MaintenanceSeriesDialog.vue'
import MaintenanceTaskBulkDialog from '@/components/MaintenanceTaskBulkDialog.vue'
import MaintenanceTaskDialog from '@/components/MaintenanceTaskDialog.vue'
import NextMaintenanceDialog from '@/components/NextMaintenanceDialog.vue'
import ResourceHistory from '@/components/ResourceHistory.vue'
import SiteEquipmentSelect from '@/components/SiteEquipmentSelect.vue'
import {
  ACCEPTANCE_RESULT_COLOR,
  ACCEPTANCE_RESULT_LABEL,
  MAINTENANCE_STATUS_COLOR,
  MAINTENANCE_STATUS_FLOW,
  MAINTENANCE_STATUS_LABEL,
  MAINTENANCE_TRANSITIONS,
  TASK_KIND_LABEL,
  TASK_STATUS_COLOR,
  TASK_STATUS_LABEL,
  periodLabel,
  transitionLabel,
} from '@/constants/maintenanceStatus'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import { todayForInput } from '@/utils/datetime'
import type { InterlockBypass } from '@/types/models'
import { bypassColor, bypassLabel, formatDateTime, restoreDueLabel } from '@/utils/interlock'

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
// 対象設備のインターロックの、終わっていないバイパス。バイパス中・復帰確認待ちが残っていると、運転を再開できないため検収・完了へ進めない
const bypasses = computed<InterlockBypass[]>(() => maintenance.value?.interlock_bypasses ?? [])
const blockingBypasses = computed(() => bypasses.value.filter((b) => b.status === 'bypassed' || b.status === 'restored'))
const blockedByBypass = (status: string) => ['acceptance', 'completed'].includes(status) && blockingBypasses.value.length > 0
const showAcceptance = computed(() => ['acceptance', 'completed'].includes(maintenance.value?.status) || !!maintenance.value?.acceptance_result)

// --- 作業（部署ごと） ---
const taskDialog = ref(false)
const bulkDialog = ref(false)
const editingTask = ref<any>(null)
const taskStatusItems = Object.entries(TASK_STATUS_LABEL).map(([value, title]) => ({ title, value }))
const tasks = computed<any[]>(() => maintenance.value?.maintenance_tasks ?? [])
// 完了（検収済み）の整備の作業は変更できない
const tasksEditable = computed(() => maintenance.value?.status !== 'completed')
const taskProgress = computed(() => maintenance.value?.tasks_summary ?? { total: 0, completed: 0 })
// 部署ごとにまとめる（部署が未設定の作業は「部署未定」）
const taskGroups = computed(() => {
  const groups = new Map<string, any[]>()
  for (const task of tasks.value) {
    const name = task.department?.name ?? '部署未定'
    groups.set(name, [...(groups.get(name) ?? []), task])
  }
  return [...groups.entries()].map(([name, list]) => ({ name, tasks: list }))
})

function openTaskDialog(task: any = null) {
  editingTask.value = task
  taskDialog.value = true
}

async function changeTaskStatus(task: any, status: string) {
  actionError.value = ''
  try {
    await api.patch(`/scheduled_maintenances/${route.params.id}/tasks/${task.id}`, { maintenance_task: { status } })
  } catch (e: any) {
    actionError.value = (e.response?.data?.errors || ['状態を変更できませんでした']).join('、')
  }
  await fetchMaintenance()
}

async function deleteTask(task: any) {
  if (!confirm(`「${task.title}」を削除しますか？`)) return
  actionError.value = ''
  try {
    await api.delete(`/scheduled_maintenances/${route.params.id}/tasks/${task.id}`)
  } catch (e: any) {
    actionError.value = (e.response?.data?.errors || ['削除できませんでした']).join('、')
  }
  await fetchMaintenance()
}

// 作業から点検を実施する（設備・計器・チェックリストを引き継ぐ。点検が下書きを出ると、作業が完了になる）
function startInspection(task: any) {
  const query: Record<string, string> = {
    maintenance_task_id: String(task.id),
    equipment_id: String(task.equipment?.id ?? ''),
    inspection_type: 'periodic',
  }
  if (task.instrument) query.instrument_id = String(task.instrument.id)
  if (task.checklist_template) query.checklist_template_id = String(task.checklist_template.id)
  router.push({ path: '/inspections/new', query })
}

// 系列（繰り返しのまとまり）: 設備ごとの周期と、各回の履歴
const series = ref<any>(null)
const seriesDialog = ref(false)
const nextDialog = ref(false)

async function fetchMaintenance() {
  loading.value = true
  try {
    const res = await api.get(`/scheduled_maintenances/${route.params.id}`)
    // 系列の取得が終わるまで、系列つきの整備に「系列に属していません」と出ないよう、そろってから反映する
    const seriesId = res.data.data.maintenance_series?.id
    const seriesData = seriesId ? (await api.get(`/maintenance_series/${seriesId}`)).data.data : null
    maintenance.value = res.data.data
    series.value = seriesData
  } finally {
    loading.value = false
  }
}

// 次回を作ったら、その定期整備の画面へ移る（同じ画面コンポーネントのまま、対象を切り替える）
async function goToCreated(id: number) {
  await router.push(`/maintenances/${id}`)
  await fetchMaintenance()
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
          :disabled="(status === 'completed' && !canComplete) || blockedByBypass(status)"
          @click="changeStatus(status)"
        >
          {{ transitionLabel(maintenance.status, status) }}
        </v-btn>
        <span v-if="nextStatuses.some(blockedByBypass)" class="text-caption text-error" data-testid="bypass-blocking-note">
          対象設備のインターロックに、戻っていないバイパスが{{ blockingBypasses.length }}件あります（復帰と、別の人の確認を済ませてから進んでください）
        </span>
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

      <!-- 対象設備のインターロックのバイパス（完了した定期整備では出さない） -->
      <v-card v-if="bypasses.length" class="mb-4" data-testid="maintenance-bypasses">
        <v-card-title class="d-flex align-center text-subtitle-1">
          <v-icon class="mr-2" :color="blockingBypasses.length ? 'error' : undefined">mdi-shield-alert-outline</v-icon>
          対象設備のインターロックのバイパス
        </v-card-title>
        <v-card-subtitle>運転を再開する前に、バイパス中・復帰確認待ちのものをすべて戻し、別の人が確認します（残っていると検収へ進めません）</v-card-subtitle>
        <v-card-text>
          <v-table density="compact">
            <tbody>
              <tr v-for="b in bypasses" :key="b.id" style="cursor: pointer" @click="router.push(`/interlocks/${b.interlock.id}`)">
                <td class="text-no-wrap"><v-chip :color="bypassColor(b)" size="small" label variant="flat">{{ bypassLabel(b) }}</v-chip></td>
                <td class="text-no-wrap">{{ b.interlock.tag_number }} {{ b.interlock.name }}</td>
                <td class="text-no-wrap">{{ b.interlock.equipment.name }}</td>
                <td>{{ b.reason }}</td>
                <td class="text-no-wrap text-caption">
                  予定の復帰 {{ formatDateTime(b.planned_restore_at) }}<template v-if="b.status === 'bypassed'">（{{ restoreDueLabel(b) }}）</template>
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-card-text>
      </v-card>

      <!-- 作業（部署ごと） -->
      <v-card class="mb-4" data-testid="tasks-card">
        <v-card-title class="d-flex align-center text-subtitle-1">
          作業
          <span class="ml-2 text-body-2 text-medium-emphasis" data-testid="tasks-progress">完了 {{ taskProgress.completed }} / {{ taskProgress.total }}</span>
          <v-spacer />
          <v-btn v-if="canManageMaintenance && tasksEditable" size="small" variant="outlined" class="mr-2" prepend-icon="mdi-playlist-plus" @click="bulkDialog = true">計器を一括追加</v-btn>
          <v-btn v-if="canManageMaintenance && tasksEditable" size="small" color="primary" prepend-icon="mdi-plus" @click="openTaskDialog()">作業を追加</v-btn>
        </v-card-title>
        <v-card-text>
          <v-progress-linear v-if="taskProgress.total" :model-value="(taskProgress.completed / taskProgress.total) * 100" color="success" height="6" rounded class="mb-3" />
          <p v-if="!tasks.length" class="text-body-2 text-medium-emphasis">
            作業はまだありません。部署ごとに、この整備で点検・整備する設備や計器を追加します（「計器を一括追加」で、設備の計器を種類ごとの定修点検つきでまとめて追加できます）。
          </p>
          <div v-for="group in taskGroups" :key="group.name" class="mb-4">
            <div class="text-subtitle-2 mb-1">{{ group.name }}（{{ group.tasks.length }}）</div>
            <v-table density="compact">
              <thead>
                <tr>
                  <th class="text-no-wrap">対象</th>
                  <th class="text-no-wrap">種類</th>
                  <th>内容</th>
                  <th class="text-no-wrap">担当者</th>
                  <th class="text-no-wrap">状態</th>
                  <th class="text-no-wrap">完了日</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                <tr v-for="task in group.tasks" :key="task.id" :data-testid="`task-${task.title}`">
                  <td class="text-no-wrap">{{ task.equipment?.name }}<span v-if="task.instrument"> / {{ task.instrument.tag_number }}</span></td>
                  <td class="text-no-wrap">{{ TASK_KIND_LABEL[task.kind] }}</td>
                  <td>
                    {{ task.title }}
                    <div v-if="task.checklist_template && !task.title.includes(task.checklist_template.name)" class="text-caption text-medium-emphasis">{{ task.checklist_template.name }}</div>
                    <div v-if="task.notes" class="text-caption text-medium-emphasis">{{ task.notes }}</div>
                    <v-chip v-if="task.trouble" size="x-small" label color="deep-purple" variant="tonal" class="mt-1" style="cursor: pointer" :data-testid="`task-trouble-${task.trouble.id}`" @click="router.push(`/troubles/${task.trouble.id}`)">
                      トラブル #{{ task.trouble.id }}
                    </v-chip>
                  </td>
                  <td class="text-no-wrap">{{ task.assigned_to?.name || '—' }}</td>
                  <td style="min-width: 150px">
                    <v-select
                      :model-value="task.status"
                      :items="taskStatusItems"
                      item-title="title"
                      item-value="value"
                      density="compact"
                      variant="outlined"
                      hide-details
                      :disabled="!tasksEditable"
                      :aria-label="`${task.title}の状態`"
                      :base-color="TASK_STATUS_COLOR[task.status]"
                      @update:model-value="changeTaskStatus(task, $event)"
                    />
                  </td>
                  <td class="text-no-wrap">{{ task.completed_on || '—' }}</td>
                  <td class="text-no-wrap text-right">
                    <v-btn
                      v-if="tasksEditable && task.kind === 'inspection' && !['completed', 'cancelled'].includes(task.status)"
                      size="x-small"
                      variant="outlined"
                      color="primary"
                      @click="startInspection(task)"
                    >
                      点検を実施
                    </v-btn>
                    <v-btn v-else-if="task.latest_inspection" size="x-small" variant="text" @click="router.push(`/inspections/${task.latest_inspection.id}`)">点検記録</v-btn>
                    <v-btn v-if="canManageMaintenance && tasksEditable" icon="mdi-pencil" size="x-small" variant="text" :aria-label="`${task.title}を編集`" @click="openTaskDialog(task)" />
                    <v-btn v-if="canManageMaintenance && tasksEditable" icon="mdi-delete" size="x-small" variant="text" color="error" :aria-label="`${task.title}を削除`" @click="deleteTask(task)" />
                  </td>
                </tr>
              </tbody>
            </v-table>
          </div>
        </v-card-text>
      </v-card>

      <!-- 系列（繰り返し） -->
      <v-card class="mb-4" data-testid="series-card">
        <v-card-title class="d-flex align-center text-subtitle-1">
          系列（繰り返し）<span v-if="series" class="ml-2 text-body-1">{{ series.name }}</span>
          <v-spacer />
          <v-btn v-if="canManageMaintenance" size="small" color="primary" prepend-icon="mdi-content-copy" class="mr-2" @click="nextDialog = true">次回を作る</v-btn>
          <v-btn v-if="canManageMaintenance && series" size="small" variant="outlined" @click="seriesDialog = true">系列を編集</v-btn>
          <v-btn v-else-if="canManageMaintenance" size="small" variant="outlined" @click="seriesDialog = true">系列に登録</v-btn>
        </v-card-title>
        <v-card-text>
          <p v-if="!series" class="text-body-2 text-medium-emphasis">
            系列に属していません。繰り返し行う整備は、系列に登録すると、設備ごとの周期から「次回を作る」で対象設備を自動で選べます。
          </p>
          <template v-else>
            <div class="text-caption text-grey mb-1">設備ごとの周期</div>
            <v-chip v-for="m in series.maintenance_series_equipments" :key="m.id" size="small" label variant="tonal" class="mr-1 mb-2">
              {{ m.equipment?.name }}（{{ m.interval_months }}か月ごと）
            </v-chip>
            <div class="text-caption text-grey mt-2 mb-1">各回</div>
            <v-list density="compact">
              <v-list-item
                v-for="m in series.maintenances"
                :key="m.id"
                :active="m.id === maintenance.id"
                :title="m.title"
                :subtitle="`${periodLabel(m.planned_start_on, m.planned_end_on)} ／ ${(m.equipments || []).map((e: any) => e.name).join('・')}`"
                :data-testid="`series-history-${m.id}`"
                @click="m.id !== maintenance.id && router.push(`/maintenances/${m.id}`).then(fetchMaintenance)"
              >
                <template #append>
                  <v-chip :color="MAINTENANCE_STATUS_COLOR[m.status]" size="x-small">{{ MAINTENANCE_STATUS_LABEL[m.status] }}</v-chip>
                </template>
              </v-list-item>
            </v-list>
          </template>
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

      <MaintenanceTaskDialog v-model="taskDialog" :maintenance="maintenance" :task="editingTask" @saved="fetchMaintenance" />
      <MaintenanceTaskBulkDialog v-model="bulkDialog" :maintenance="maintenance" @saved="fetchMaintenance" />
      <MaintenanceSeriesDialog v-model="seriesDialog" :series="series" :maintenance="maintenance" @saved="fetchMaintenance" />
      <NextMaintenanceDialog v-model="nextDialog" :maintenance-id="maintenance.id" @created="goToCreated" />

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
