<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'

const route = useRoute()
const router = useRouter()
const { canManageUsers } = usePermissions()
const user = ref<any>(null)
const sites = ref<any[]>([])
const companies = ref<any[]>([])
const departmentTreeBySite = ref<Record<number, any[]>>({})
const loading = ref(true)
const editDialog = ref(false)
const editForm = ref<any>({})
const editErrors = ref<string[]>([])

// 部署カスケード選択用
const selectedSiteId = ref<number | null>(null)
const selectedDivisionId = ref<number | null>(null)
const selectedSectionId = ref<number | null>(null)
const selectedTeamId = ref<number | null>(null)

const employmentTypeLabel: Record<string, string> = {
  employee: '正社員', dispatch: '派遣社員', contractor: '協力会社員',
}

const systemRoleLabel: Record<string, string> = {
  admin: 'システム管理者', manager: '業務管理者', member: '一般', worker: '技能員',
}

const positionLabel: Record<string, string> = {
  general_manager: '部長', section_manager: '課長', team_leader: 'チームリーダー',
  senior_staff: '主任', staff: '担当',
}

const positionOptions = [
  { title: '部長', value: 'general_manager' },
  { title: '課長', value: 'section_manager' },
  { title: 'チームリーダー', value: 'team_leader' },
  { title: '主任', value: 'senior_staff' },
  { title: '担当', value: 'staff' },
]

// 選択中の会社タイプに応じた動的オプション
const selectedCompanyType = computed(() => {
  const c = companies.value.find((c: any) => c.id === editForm.value.company_id)
  return c?.company_type || null
})

const filteredEmploymentTypeOptions = computed(() => {
  if (selectedCompanyType.value === 'contractor') {
    return [{ title: '協力会社員', value: 'contractor' }]
  }
  return [
    { title: '正社員', value: 'employee' },
    { title: '派遣社員', value: 'dispatch' },
  ]
})

const filteredSystemRoleOptions = computed(() => {
  if (selectedCompanyType.value === 'contractor') {
    return [
      { title: '業務管理者', value: 'manager' },
      { title: '技能員', value: 'worker' },
    ]
  }
  return [
    { title: 'システム管理者', value: 'admin' },
    { title: '業務管理者', value: 'manager' },
    { title: '一般', value: 'member' },
  ]
})

// カスケードセレクト: 拠点の一覧
const siteOptions = computed(() =>
  sites.value.map((s: any) => ({ title: s.name, value: s.id }))
)

// カスケードセレクト: 選択中の拠点の部一覧
const divisionOptions = computed(() =>
  (departmentTreeBySite.value[selectedSiteId.value!] || []).map((d: any) => ({ title: d.name, value: d.id }))
)

// カスケードセレクト: 選択中の部の課一覧
const sectionOptions = computed(() => {
  const tree = departmentTreeBySite.value[selectedSiteId.value!] || []
  const div = tree.find((d: any) => d.id === selectedDivisionId.value)
  return (div?.children || []).map((s: any) => ({ title: s.name, value: s.id }))
})

// カスケードセレクト: 選択中の課のチーム一覧
const teamOptions = computed(() => {
  const tree = departmentTreeBySite.value[selectedSiteId.value!] || []
  const div = tree.find((d: any) => d.id === selectedDivisionId.value)
  const sec = (div?.children || []).find((s: any) => s.id === selectedSectionId.value)
  return (sec?.children || []).map((t: any) => ({ title: t.name, value: t.id }))
})

// openEdit時のwatch連鎖リセットを抑制するフラグ
const initializing = ref(false)

// 会社が変わったら在籍区分・権限をリセット
watch(() => editForm.value.company_id, () => {
  if (initializing.value) return
  if (selectedCompanyType.value === 'contractor') {
    editForm.value.employment_type = 'contractor'
    editForm.value.system_role = 'worker'
    editForm.value.department_id = null
    selectedSiteId.value = null
    selectedDivisionId.value = null
    selectedSectionId.value = null
    selectedTeamId.value = null
  } else if (selectedCompanyType.value === 'owner') {
    editForm.value.employment_type = 'employee'
    editForm.value.system_role = 'member'
  }
})

// 拠点が変わったら部・課・チームをリセット
watch(selectedSiteId, () => {
  if (initializing.value) return
  selectedDivisionId.value = null
  selectedSectionId.value = null
  selectedTeamId.value = null
})

// 部が変わったら課・チームをリセット
watch(selectedDivisionId, () => {
  if (initializing.value) return
  selectedSectionId.value = null
  selectedTeamId.value = null
})

// 課が変わったらチームをリセット
watch(selectedSectionId, () => {
  if (initializing.value) return
  selectedTeamId.value = null
})

// 最も深い選択を department_id に反映
watch([selectedSiteId, selectedDivisionId, selectedSectionId, selectedTeamId], () => {
  if (initializing.value) return
  editForm.value.department_id =
    selectedTeamId.value || selectedSectionId.value || selectedDivisionId.value || null
})

async function fetchUser() {
  loading.value = true
  try {
    const res = await api.get(`/users/${route.params.id}`)
    user.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function fetchSitesAndDepartments() {
  const [sitesRes, deptsRes, companiesRes] = await Promise.all([
    api.get('/sites'),
    api.get('/departments', { params: { tree: 'true' } }),
    api.get('/companies'),
  ])
  sites.value = sitesRes.data.data
  companies.value = companiesRes.data.data
  // ツリーを site_id ごとにグルーピング
  const tree = deptsRes.data.data as any[]
  const bySite: Record<number, any[]> = {}
  for (const node of tree) {
    const sid = node.site_id
    if (!bySite[sid]) bySite[sid] = []
    bySite[sid].push(node)
  }
  departmentTreeBySite.value = bySite
}

function openEdit() {
  editForm.value = {
    name: user.value.name,
    employment_type: user.value.employment_type,
    system_role: user.value.system_role,
    company_id: user.value.company_id,
    department_id: user.value.department_id,
    site_id: user.value.site_id,
    position: user.value.position,
    join_year: user.value.join_year,
    home_prefecture: user.value.home_prefecture || '',
    previous_company: user.value.previous_company || '',
    is_active: user.value.is_active,
  }
  // ancestors + site_id からカスケードセレクトの初期値を復元
  const dept = user.value.department
  const ancestors = dept?.ancestors || []
  initializing.value = true
  selectedSiteId.value = dept?.site_id || null
  selectedDivisionId.value = ancestors.find((a: any) => a.level === 'division')?.id || null
  selectedSectionId.value = ancestors.find((a: any) => a.level === 'section')?.id || null
  selectedTeamId.value = ancestors.find((a: any) => a.level === 'team')?.id || null
  initializing.value = false
  editErrors.value = []
  editDialog.value = true
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
  fetchSitesAndDepartments()
})
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="user">
      <div class="d-flex align-center mb-4">
        <v-btn icon="mdi-arrow-left" variant="text" @click="router.push('/users')" />
        <v-avatar :color="avatarColor(user.id)" size="48" class="ml-2">
          <span class="text-white text-h6 font-weight-bold">{{ nameInitial(user.name) }}</span>
        </v-avatar>
        <h1 class="text-h5 ml-3">{{ user.name }}</h1>
        <v-chip class="ml-3" :color="user.is_active ? 'success' : 'grey'" size="small">
          {{ user.is_active ? '在籍' : '退職' }}
        </v-chip>
        <v-spacer />
        <v-btn v-if="canManageUsers" variant="outlined" @click="openEdit">
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
              <div class="text-caption text-grey">在籍区分</div>
              <div>{{ employmentTypeLabel[user.employment_type] || user.employment_type }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">権限</div>
              <div>{{ systemRoleLabel[user.system_role] || user.system_role }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">所属会社</div>
              <div class="d-flex align-center ga-2">
                <span>{{ user.company?.name || '—' }}</span>
                <v-chip
                  v-if="user.company"
                  :color="user.company.company_type === 'owner' ? 'primary' : 'orange'"
                  size="x-small"
                  label
                  variant="tonal"
                >
                  {{ user.company.company_type === 'owner' ? '自社' : '協力' }}
                </v-chip>
              </div>
            </v-col>
            <template v-if="user.company?.company_type === 'owner'">
              <v-col cols="6" md="3">
                <div class="text-caption text-grey">役職</div>
                <div>{{ positionLabel[user.position] || '—' }}</div>
              </v-col>
              <v-col cols="12" md="6">
                <div class="text-caption text-grey">部署</div>
                <div>{{ user.department?.full_path || '—' }}</div>
              </v-col>
            </template>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">{{ user.company?.company_type === 'owner' ? '入社年' : '参加年' }}</div>
              <div>{{ user.join_year ? `${user.join_year}年` : '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">出身地</div>
              <div>{{ user.home_prefecture || '—' }}</div>
            </v-col>
            <v-col v-if="user.company?.company_type === 'owner'" cols="6" md="3">
              <div class="text-caption text-grey">前職</div>
              <div>{{ user.previous_company || '—' }}</div>
            </v-col>
            <v-col v-if="user.deactivated_on" cols="6" md="3">
              <div class="text-caption text-grey">退職日</div>
              <div>{{ user.deactivated_on }}</div>
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <h2 class="text-h6 mb-3">設備担当</h2>
      <v-table v-if="user.equipment_assignments?.length" density="compact">
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
            <v-row dense class="mb-2">
              <v-col cols="6">
                <v-select
                  v-model="editForm.company_id"
                  :items="companies"
                  item-title="name"
                  item-value="id"
                  label="所属会社"
                />
              </v-col>
              <v-col cols="6">
                <v-select
                  v-model="editForm.employment_type"
                  :items="filteredEmploymentTypeOptions"
                  item-title="title"
                  item-value="value"
                  label="在籍区分"
                />
              </v-col>
            </v-row>
            <v-row dense class="mb-2">
              <v-col cols="6">
                <v-select
                  v-model="editForm.system_role"
                  :items="filteredSystemRoleOptions"
                  item-title="title"
                  item-value="value"
                  label="権限"
                />
              </v-col>
              <v-col v-if="selectedCompanyType === 'owner'" cols="6">
                <v-select
                  v-model="editForm.position"
                  :items="positionOptions"
                  item-title="title"
                  item-value="value"
                  label="役職"
                  clearable
                />
              </v-col>
            </v-row>
            <template v-if="selectedCompanyType === 'owner'">
              <v-select
                v-model="selectedSiteId"
                :items="siteOptions"
                item-title="title"
                item-value="value"
                label="拠点"
                class="mb-2"
              />
              <v-row dense class="mb-2">
                <v-col cols="4">
                  <v-select
                    v-model="selectedDivisionId"
                    :items="divisionOptions"
                    item-title="title"
                    item-value="value"
                    label="部"
                    clearable
                    :disabled="!selectedSiteId"
                  />
                </v-col>
                <v-col cols="4">
                  <v-select
                    v-model="selectedSectionId"
                    :items="sectionOptions"
                    item-title="title"
                    item-value="value"
                    label="課"
                    clearable
                    :disabled="!selectedDivisionId || sectionOptions.length === 0"
                  />
                </v-col>
                <v-col cols="4">
                  <v-select
                    v-model="selectedTeamId"
                    :items="teamOptions"
                    item-title="title"
                    item-value="value"
                    label="チーム"
                    clearable
                    :disabled="!selectedSectionId || teamOptions.length === 0"
                  />
                </v-col>
              </v-row>
            </template>
            <v-text-field
              v-model.number="editForm.join_year"
              :label="selectedCompanyType === 'contractor' ? '参加年' : '入社年'"
              type="number"
              class="mb-2"
            />
            <v-text-field v-model="editForm.home_prefecture" label="出身地" class="mb-2" />
            <v-text-field
              v-if="selectedCompanyType === 'owner'"
              v-model="editForm.previous_company"
              label="前職"
              class="mb-2"
            />
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
