<script setup lang="ts">
import { ref, onMounted } from 'vue'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const tab = ref('services')

// Services
const services = ref<any[]>([])
const serviceDialog = ref(false)
const serviceForm = ref({ name: '', temperature: '', pressure: '', hazard_level: 'low', hazard_description: '' })
const serviceEditingId = ref<number | null>(null)
const serviceErrors = ref<string[]>([])

async function fetchServices() {
  const res = await api.get('/services')
  services.value = res.data.data
}

function openServiceDialog(item?: any) {
  if (item) {
    serviceEditingId.value = item.id
    serviceForm.value = { name: item.name, temperature: item.temperature || '', pressure: item.pressure || '', hazard_level: item.hazard_level || 'low', hazard_description: item.hazard_description || '' }
  } else {
    serviceEditingId.value = null
    serviceForm.value = { name: '', temperature: '', pressure: '', hazard_level: 'low', hazard_description: '' }
  }
  serviceErrors.value = []
  serviceDialog.value = true
}

async function saveService() {
  try {
    if (serviceEditingId.value) {
      await api.patch(`/services/${serviceEditingId.value}`, { service: serviceForm.value })
    } else {
      await api.post('/services', { service: serviceForm.value })
    }
    serviceDialog.value = false
    await fetchServices()
  } catch (e: any) {
    serviceErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

// Line Classes
const lineClasses = ref<any[]>([])
const lcDialog = ref(false)
const lcForm = ref({ code: '', description: '' })
const lcEditingId = ref<number | null>(null)
const lcErrors = ref<string[]>([])

async function fetchLineClasses() {
  const res = await api.get('/line_classes')
  lineClasses.value = res.data.data
}

function openLcDialog(item?: any) {
  if (item) {
    lcEditingId.value = item.id
    lcForm.value = { code: item.code, description: item.description || '' }
  } else {
    lcEditingId.value = null
    lcForm.value = { code: '', description: '' }
  }
  lcErrors.value = []
  lcDialog.value = true
}

async function saveLc() {
  try {
    if (lcEditingId.value) {
      await api.patch(`/line_classes/${lcEditingId.value}`, { line_class: lcForm.value })
    } else {
      await api.post('/line_classes', { line_class: lcForm.value })
    }
    lcDialog.value = false
    await fetchLineClasses()
  } catch (e: any) {
    lcErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

// Departments
const departments = ref<any[]>([])
const sites = ref<any[]>([])
const deptDialog = ref(false)
const deptForm = ref({ name: '', department_type: 'maintenance', site_id: null as number | null })
const deptEditingId = ref<number | null>(null)
const deptErrors = ref<string[]>([])

async function fetchDepartments() {
  const res = await api.get('/departments')
  departments.value = res.data.data
}

async function fetchSites() {
  const res = await api.get('/sites', { params: { per_page: 100 } })
  sites.value = res.data.data
}

function openDeptDialog(item?: any) {
  if (item) {
    deptEditingId.value = item.id
    deptForm.value = { name: item.name, department_type: item.department_type, site_id: item.site_id }
  } else {
    deptEditingId.value = null
    deptForm.value = { name: '', department_type: 'maintenance', site_id: null }
  }
  deptErrors.value = []
  deptDialog.value = true
}

async function saveDept() {
  try {
    if (deptEditingId.value) {
      await api.patch(`/departments/${deptEditingId.value}`, { department: deptForm.value })
    } else {
      await api.post('/departments', { department: deptForm.value })
    }
    deptDialog.value = false
    await fetchDepartments()
  } catch (e: any) {
    deptErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

const deptTypeLabel: Record<string, string> = {
  maintenance: '保全', operation: '運転', environment: '環境安全'
}
const hazardOptions = [
  { title: '高', value: 'high' },
  { title: '中', value: 'medium' },
  { title: '低', value: 'low' },
]
const deptTypeOptions = [
  { title: '保全', value: 'maintenance' },
  { title: '運転', value: 'operation' },
  { title: '環境安全', value: 'environment' },
]

onMounted(() => {
  fetchServices()
  fetchLineClasses()
  fetchDepartments()
  fetchSites()
})
</script>

<template>
  <MainLayout>
    <h1 class="text-h5 mb-4">設定</h1>

    <v-tabs v-model="tab" class="mb-4">
      <v-tab value="services">サービス・流体</v-tab>
      <v-tab value="lineClasses">ラインクラス</v-tab>
      <v-tab value="departments">部署</v-tab>
    </v-tabs>

    <v-window v-model="tab">
      <!-- サービス・流体 -->
      <v-window-item value="services">
        <div class="d-flex mb-2">
          <v-spacer />
          <v-btn color="primary" size="small" prepend-icon="mdi-plus" @click="openServiceDialog()">追加</v-btn>
        </div>
        <v-data-table
          :headers="[
            { title: '流体名', key: 'name' },
            { title: '温度', key: 'temperature' },
            { title: '圧力', key: 'pressure' },
            { title: '危険性', key: 'hazard_level', width: '80px' },
            { title: '', key: 'actions', width: '80px', sortable: false },
          ]"
          :items="services"
          density="compact"
        >
          <template #item.hazard_level="{ item }">
            <v-chip :color="item.hazard_level === 'high' ? 'error' : item.hazard_level === 'medium' ? 'warning' : 'success'" size="x-small">
              {{ { high: '高', medium: '中', low: '低' }[item.hazard_level as string] }}
            </v-chip>
          </template>
          <template #item.actions="{ item }">
            <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openServiceDialog(item)" />
          </template>
        </v-data-table>

        <v-dialog v-model="serviceDialog" max-width="500">
          <v-card>
            <v-card-title>{{ serviceEditingId ? 'サービス編集' : 'サービス追加' }}</v-card-title>
            <v-card-text>
              <v-alert v-if="serviceErrors.length" type="error" density="compact" class="mb-4">
                <div v-for="err in serviceErrors" :key="err">{{ err }}</div>
              </v-alert>
              <v-text-field v-model="serviceForm.name" label="流体名" class="mb-2" />
              <v-text-field v-model="serviceForm.temperature" label="温度" class="mb-2" />
              <v-text-field v-model="serviceForm.pressure" label="圧力" class="mb-2" />
              <v-select v-model="serviceForm.hazard_level" :items="hazardOptions" item-title="title" item-value="value" label="危険性" class="mb-2" />
              <v-textarea v-model="serviceForm.hazard_description" label="危険性の詳細" rows="2" />
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn @click="serviceDialog = false">キャンセル</v-btn>
              <v-btn color="primary" @click="saveService">保存</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-window-item>

      <!-- ラインクラス -->
      <v-window-item value="lineClasses">
        <div class="d-flex mb-2">
          <v-spacer />
          <v-btn color="primary" size="small" prepend-icon="mdi-plus" @click="openLcDialog()">追加</v-btn>
        </div>
        <v-data-table
          :headers="[
            { title: 'コード', key: 'code' },
            { title: '仕様説明', key: 'description' },
            { title: '', key: 'actions', width: '80px', sortable: false },
          ]"
          :items="lineClasses"
          density="compact"
        >
          <template #item.actions="{ item }">
            <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openLcDialog(item)" />
          </template>
        </v-data-table>

        <v-dialog v-model="lcDialog" max-width="500">
          <v-card>
            <v-card-title>{{ lcEditingId ? 'ラインクラス編集' : 'ラインクラス追加' }}</v-card-title>
            <v-card-text>
              <v-alert v-if="lcErrors.length" type="error" density="compact" class="mb-4">
                <div v-for="err in lcErrors" :key="err">{{ err }}</div>
              </v-alert>
              <v-text-field v-model="lcForm.code" label="コード" class="mb-2" />
              <v-textarea v-model="lcForm.description" label="仕様説明" rows="2" />
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn @click="lcDialog = false">キャンセル</v-btn>
              <v-btn color="primary" @click="saveLc">保存</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-window-item>

      <!-- 部署 -->
      <v-window-item value="departments">
        <div class="d-flex mb-2">
          <v-spacer />
          <v-btn color="primary" size="small" prepend-icon="mdi-plus" @click="openDeptDialog()">追加</v-btn>
        </div>
        <v-data-table
          :headers="[
            { title: '部署名', key: 'name' },
            { title: '種別', key: 'department_type', width: '120px' },
            { title: '拠点', key: 'site.name' },
            { title: '', key: 'actions', width: '80px', sortable: false },
          ]"
          :items="departments"
          density="compact"
        >
          <template #item.department_type="{ item }">
            {{ deptTypeLabel[item.department_type] || item.department_type }}
          </template>
          <template #item.actions="{ item }">
            <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openDeptDialog(item)" />
          </template>
        </v-data-table>

        <v-dialog v-model="deptDialog" max-width="500">
          <v-card>
            <v-card-title>{{ deptEditingId ? '部署編集' : '部署追加' }}</v-card-title>
            <v-card-text>
              <v-alert v-if="deptErrors.length" type="error" density="compact" class="mb-4">
                <div v-for="err in deptErrors" :key="err">{{ err }}</div>
              </v-alert>
              <v-text-field v-model="deptForm.name" label="部署名" class="mb-2" />
              <v-select v-model="deptForm.department_type" :items="deptTypeOptions" item-title="title" item-value="value" label="種別" class="mb-2" />
              <v-select v-model="deptForm.site_id" :items="sites" item-title="name" item-value="id" label="拠点" class="mb-2" />
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn @click="deptDialog = false">キャンセル</v-btn>
              <v-btn color="primary" @click="saveDept">保存</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-window-item>
    </v-window>
  </MainLayout>
</template>
