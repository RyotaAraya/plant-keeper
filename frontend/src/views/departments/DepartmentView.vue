<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

// --- マスタ ---
const sites = ref<any[]>([])
const allUsers = ref<any[]>([])
const tree = ref<any[]>([])

// --- フィルタ ---
const selectedSiteId = ref<number | null>(null)

const filteredDepts = computed(() => {
  if (!selectedSiteId.value) return allDepartments.value
  return allDepartments.value.filter((d: any) => d.site_id === selectedSiteId.value)
})

const groupedDepts = computed(() => {
  const result: { siteId: number; siteName: string; depts: any[] }[] = []
  for (const dept of filteredDepts.value) {
    let group = result.find((g) => g.siteId === dept.site_id)
    if (!group) {
      const site = sites.value.find((s: any) => s.id === dept.site_id)
      group = { siteId: dept.site_id, siteName: site?.name ?? '', depts: [] }
      result.push(group)
    }
    group.depts.push(dept)
  }
  return result
})

// --- 選択中部署 ---
const selectedDept = ref<any>(null)
const loadingDetail = ref(false)

async function selectDept(id: number) {
  loadingDetail.value = true
  try {
    const res = await api.get(`/departments/${id}`)
    selectedDept.value = res.data.data
  } finally {
    loadingDetail.value = false
  }
}

// --- ロール定義 ---
const roleOptions: Record<string, string[]> = {
  division: ['部長', 'メンバー'],
  section: ['課長', 'メンバー'],
  team: ['チームリーダー', 'メンバー'],
}

const levelLabel: Record<string, string> = { division: '部', section: '課', team: 'チーム' }
const levelColor: Record<string, string> = { division: 'primary', section: 'info', team: 'grey' }
const typeLabel: Record<string, string> = { maintenance: '保全', operation: '運転', environment: '環境安全' }

// --- 部署 CRUD ---
const deptDialog = ref(false)
const deptErrors = ref<string[]>([])
const deptEditingId = ref<number | null>(null)
const deptForm = ref({
  name: '',
  department_type: 'maintenance',
  level: 'section',
  site_id: null as number | null,
  parent_id: null as number | null,
})

const allDepartments = computed(() => flattenTree(tree.value))

function flattenTree(nodes: any[]): any[] {
  return nodes.flatMap((n: any) => [n, ...flattenTree(n.children || [])])
}

function openDeptCreate(parentId?: number, parentLevel?: string) {
  deptEditingId.value = null
  deptForm.value = {
    name: '',
    department_type: selectedDept.value?.department_type || 'maintenance',
    level: parentLevel === 'division' ? 'section' : parentLevel === 'section' ? 'team' : 'division',
    site_id: selectedDept.value?.site_id ?? selectedSiteId.value ?? null,
    parent_id: parentId ?? null,
  }
  deptErrors.value = []
  deptDialog.value = true
}

function openDeptEdit(dept: any) {
  deptEditingId.value = dept.id
  deptForm.value = {
    name: dept.name,
    department_type: dept.department_type,
    level: dept.level,
    site_id: dept.site_id,
    parent_id: dept.parent_id ?? null,
  }
  deptErrors.value = []
  deptDialog.value = true
}

watch(
  () => deptForm.value.parent_id,
  (parentId) => {
    if (parentId === null) {
      deptForm.value.level = 'division'
    } else {
      const parent = allDepartments.value.find((d: any) => d.id === parentId)
      if (parent?.level === 'division') deptForm.value.level = 'section'
      else if (parent?.level === 'section') deptForm.value.level = 'team'
    }
  },
)

async function saveDept() {
  deptErrors.value = []
  try {
    if (deptEditingId.value) {
      await api.patch(`/departments/${deptEditingId.value}`, { department: deptForm.value })
    } else {
      await api.post('/departments', { department: deptForm.value })
    }
    deptDialog.value = false
    await fetchTree()
    if (selectedDept.value) await selectDept(selectedDept.value.id)
  } catch (e: any) {
    deptErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

// --- メンバー追加 ---
const memberDialog = ref(false)
const memberErrors = ref<string[]>([])
const memberForm = ref({ user_id: null as number | null, role_note: 'メンバー' })

function openMemberAdd() {
  memberForm.value = {
    user_id: null,
    role_note: roleOptions[selectedDept.value?.level]?.[0] ?? 'メンバー',
  }
  memberErrors.value = []
  memberDialog.value = true
}

async function saveMember() {
  memberErrors.value = []
  try {
    await api.post('/department_histories', {
      department_history: {
        department_id: selectedDept.value.id,
        user_id: memberForm.value.user_id,
        role_note: memberForm.value.role_note,
      },
    })
    memberDialog.value = false
    await selectDept(selectedDept.value.id)
  } catch (e: any) {
    memberErrors.value = e.response?.data?.errors || ['追加に失敗しました']
  }
}

// --- ロール変更 ---
const roleDialog = ref(false)
const roleTarget = ref<any>(null)
const roleForm = ref('')

function openRoleEdit(member: any) {
  roleTarget.value = member
  roleForm.value = member.role_note || ''
  roleDialog.value = true
}

async function saveRole() {
  try {
    await api.patch(`/department_histories/${roleTarget.value.id}`, {
      department_history: { role_note: roleForm.value },
    })
    roleDialog.value = false
    await selectDept(selectedDept.value.id)
  } catch (e: any) {
    alert(e.response?.data?.errors?.[0] || 'ロール変更に失敗しました')
  }
}

// --- メンバー削除 ---
async function removeMember(member: any) {
  if (!confirm(`${member.user.name} を ${selectedDept.value.name} から外しますか？`)) return
  try {
    await api.delete(`/department_histories/${member.id}`)
    await selectDept(selectedDept.value.id)
  } catch {
    alert('削除に失敗しました')
  }
}

// --- 初期データ取得 ---
async function fetchTree() {
  const res = await api.get('/departments', { params: { tree: true } })
  tree.value = res.data.data
}

async function fetchSites() {
  const res = await api.get('/sites', { params: { per_page: 100 } })
  sites.value = res.data.data
}

async function fetchUsers() {
  const res = await api.get('/users', { params: { per_page: 500 } })
  allUsers.value = res.data.data
}

onMounted(() => {
  fetchTree()
  fetchSites()
  fetchUsers()
})
</script>

<template>
  <MainLayout>
    <!-- ヘッダー -->
    <div class="d-flex align-center mb-4">
      <h1 class="text-h5">部署管理</h1>
      <v-spacer />
      <v-btn color="primary" prepend-icon="mdi-plus" @click="openDeptCreate()">部署を追加</v-btn>
    </div>

    <!-- 拠点フィルタ -->
    <v-select
      v-model="selectedSiteId"
      :items="sites"
      item-title="name"
      item-value="id"
      label="拠点で絞り込み"
      clearable
      density="compact"
      hide-details
      style="max-width: 280px"
      class="mb-4"
    />

    <div class="d-flex ga-4 align-start">
      <!-- 左: フラットリスト -->
      <v-card style="min-width: 280px; width: 280px" variant="outlined">
        <v-list density="compact" nav>
          <div v-if="filteredDepts.length === 0" class="text-body-2 text-grey pa-3">部署がありません</div>
          <template v-for="group in groupedDepts" :key="group.siteId">
            <v-list-subheader v-if="groupedDepts.length > 1">{{ group.siteName }}</v-list-subheader>
            <v-list-item
              v-for="dept in group.depts"
              :key="dept.id"
              :active="selectedDept?.id === dept.id"
              active-color="primary"
              :class="dept.level === 'section' ? 'pl-8' : dept.level === 'team' ? 'pl-12' : ''"
              @click="selectDept(dept.id)"
            >
              <template #prepend>
                <v-chip
                  :color="levelColor[dept.level]"
                  size="x-small"
                  variant="tonal"
                  class="mr-2"
                  style="min-width: 28px; justify-content: center"
                >
                  {{ levelLabel[dept.level] }}
                </v-chip>
              </template>
              <v-list-item-title :class="dept.level === 'division' ? 'font-weight-medium' : 'text-body-2'">
                {{ dept.name }}
              </v-list-item-title>
            </v-list-item>
          </template>
        </v-list>
      </v-card>

      <!-- 右: 詳細 -->
      <div class="flex-grow-1">
        <v-skeleton-loader v-if="loadingDetail" type="card" />

        <template v-else-if="selectedDept">
          <!-- 部署ヘッダー -->
          <v-card class="mb-4">
            <v-card-title class="d-flex align-center flex-wrap ga-2">
              {{ selectedDept.name }}
              <v-chip :color="levelColor[selectedDept.level]" size="small">
                {{ levelLabel[selectedDept.level] }}
              </v-chip>
              <v-chip variant="tonal" size="small">{{ typeLabel[selectedDept.department_type] }}</v-chip>
              <v-spacer />
              <v-btn variant="outlined" size="small" prepend-icon="mdi-pencil" @click="openDeptEdit(selectedDept)">
                編集
              </v-btn>
              <v-btn
                v-if="selectedDept.level !== 'team'"
                variant="outlined"
                size="small"
                prepend-icon="mdi-plus"
                @click="openDeptCreate(selectedDept.id, selectedDept.level)"
              >
                子部署を追加
              </v-btn>
            </v-card-title>
            <v-card-subtitle v-if="selectedDept.parent || selectedDept.site">
              {{ selectedDept.site?.name }}
              <template v-if="selectedDept.parent"> > {{ selectedDept.parent.name }}</template>
              > {{ selectedDept.name }}
            </v-card-subtitle>
          </v-card>

          <!-- 子部署 -->
          <div v-if="selectedDept.children?.length" class="mb-4">
            <div class="text-subtitle-2 mb-2">
              {{ selectedDept.level === 'division' ? '所属する課' : '所属するチーム' }}
            </div>
            <div class="d-flex flex-wrap ga-2">
              <v-chip
                v-for="child in selectedDept.children"
                :key="child.id"
                :color="levelColor[child.level]"
                variant="tonal"
                class="cursor-pointer"
                @click="selectDept(child.id)"
              >
                {{ child.name }}
              </v-chip>
            </div>
          </div>

          <!-- メンバー -->
          <v-card>
            <v-card-title class="d-flex align-center">
              メンバー
              <v-chip class="ml-2" size="small">{{ (selectedDept.current_members || []).length }}名</v-chip>
              <v-spacer />
              <v-btn size="small" variant="outlined" prepend-icon="mdi-account-plus" @click="openMemberAdd">
                追加
              </v-btn>
            </v-card-title>
            <v-card-text class="pa-0">
              <v-list v-if="(selectedDept.current_members || []).length">
                <v-list-item
                  v-for="member in selectedDept.current_members"
                  :key="member.id"
                >
                  <template #prepend>
                    <v-avatar color="grey-lighten-2" size="36">
                      <v-icon>mdi-account</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title>{{ member.user.name }}</v-list-item-title>
                  <v-list-item-subtitle>{{ member.user.email }}</v-list-item-subtitle>
                  <template #append>
                    <v-chip
                      size="small"
                      :color="member.role_note && member.role_note !== 'メンバー' ? 'warning' : 'grey'"
                      variant="tonal"
                      class="mr-2"
                    >
                      {{ member.role_note || 'メンバー' }}
                    </v-chip>
                    <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openRoleEdit(member)" />
                    <v-btn icon="mdi-account-minus" size="x-small" variant="text" color="error" @click="removeMember(member)" />
                  </template>
                </v-list-item>
              </v-list>
              <p v-else class="text-body-2 text-grey pa-4">メンバーなし</p>
            </v-card-text>
          </v-card>
        </template>

        <v-card v-else variant="tonal" class="d-flex align-center justify-center" style="min-height: 200px">
          <p class="text-body-2 text-grey">左のツリーから部署を選択してください</p>
        </v-card>
      </div>
    </div>

    <!-- 部署作成・編集ダイアログ -->
    <v-dialog v-model="deptDialog" max-width="500">
      <v-card>
        <v-card-title>{{ deptEditingId ? '部署編集' : '部署追加' }}</v-card-title>
        <v-card-text>
          <v-alert v-if="deptErrors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in deptErrors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select
            v-if="!deptEditingId"
            v-model="deptForm.site_id"
            :items="sites"
            item-title="name"
            item-value="id"
            label="拠点"
            class="mb-2"
          />
          <v-text-field
            v-else
            :model-value="sites.find((s: any) => s.id === deptForm.site_id)?.name ?? ''"
            label="拠点"
            readonly
            class="mb-2"
          />
          <v-select
            v-if="deptForm.level !== 'division'"
            v-model="deptForm.parent_id"
            :items="allDepartments.filter((d: any) =>
              d.id !== deptEditingId &&
              d.site_id === deptForm.site_id &&
              (deptForm.level === 'section' ? d.level === 'division' : d.level === 'section')
            )"
            item-title="name"
            item-value="id"
            label="上位部署"
            class="mb-2"
          />
          <v-text-field v-model="deptForm.name" label="部署名" class="mb-2" />
          <v-text-field
            :model-value="levelLabel[deptForm.level]"
            label="階層"
            readonly
            class="mb-2"
          />
          <v-select
            v-model="deptForm.department_type"
            :items="[{ title: '保全', value: 'maintenance' }, { title: '運転', value: 'operation' }, { title: '環境安全', value: 'environment' }]"
            item-title="title"
            item-value="value"
            label="種別"
            class="mb-2"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="deptDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveDept">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- メンバー追加ダイアログ -->
    <v-dialog v-model="memberDialog" max-width="480">
      <v-card>
        <v-card-title>メンバー追加 — {{ selectedDept?.name }}</v-card-title>
        <v-card-text>
          <v-alert v-if="memberErrors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in memberErrors" :key="err">{{ err }}</div>
          </v-alert>
          <v-autocomplete
            v-model="memberForm.user_id"
            :items="allUsers"
            item-title="name"
            item-value="id"
            label="ユーザ"
            class="mb-2"
          >
            <template #item="{ props, item }">
              <v-list-item v-bind="props" :subtitle="item.raw.email" />
            </template>
          </v-autocomplete>
          <v-select
            v-model="memberForm.role_note"
            :items="roleOptions[selectedDept?.level] ?? ['メンバー']"
            label="ロール"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="memberDialog = false">キャンセル</v-btn>
          <v-btn color="primary" :disabled="!memberForm.user_id" @click="saveMember">追加</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- ロール変更ダイアログ -->
    <v-dialog v-model="roleDialog" max-width="360">
      <v-card>
        <v-card-title>ロール変更 — {{ roleTarget?.user?.name }}</v-card-title>
        <v-card-text>
          <v-select
            v-model="roleForm"
            :items="roleOptions[selectedDept?.level] ?? ['メンバー']"
            label="ロール"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="roleDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveRole">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer {
  cursor: pointer;
}
</style>
