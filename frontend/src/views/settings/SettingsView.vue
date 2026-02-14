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

// Checklist Templates
const templates = ref<any[]>([])
const templateDialog = ref(false)
const templateEditingId = ref<number | null>(null)
const templateForm = ref({ name: '', department_id: null as number | null, inspection_type: 'routine', items: [] as any[] })
const templateErrors = ref<string[]>([])
const inspectionTypeOptions = [
  { title: '日常点検', value: 'routine' },
  { title: '定期点検', value: 'periodic' },
  { title: 'テレメトリ', value: 'telemetry' },
  { title: '運転チェック', value: 'operation_check' },
]
const inspectionTypeLabel: Record<string, string> = {
  routine: '日常点検', periodic: '定期点検', telemetry: 'テレメトリ', operation_check: '運転チェック'
}
const itemTypeOptions = [
  { title: 'チェック', value: 'check' },
  { title: '計測値', value: 'measurement' },
  { title: 'テキスト', value: 'text' },
]

async function fetchTemplates() {
  const res = await api.get('/checklist_templates')
  templates.value = res.data.data
}

function openTemplateDialog(item?: any) {
  if (item) {
    templateEditingId.value = item.id
    templateForm.value = {
      name: item.name,
      department_id: item.department_id,
      inspection_type: item.inspection_type,
      items: (item.checklist_template_items || []).map((i: any) => ({ id: i.id, content: i.content, item_type: i.item_type }))
    }
  } else {
    templateEditingId.value = null
    templateForm.value = { name: '', department_id: null, inspection_type: 'routine', items: [] }
  }
  templateErrors.value = []
  templateDialog.value = true
}

function addTemplateItem() {
  templateForm.value.items.push({ content: '', item_type: 'check' })
}

function removeTemplateItem(idx: number) {
  templateForm.value.items.splice(idx, 1)
}

async function saveTemplate() {
  try {
    const payload = { checklist_template: { ...templateForm.value } }
    if (templateEditingId.value) {
      await api.patch(`/checklist_templates/${templateEditingId.value}`, payload)
    } else {
      await api.post('/checklist_templates', payload)
    }
    templateDialog.value = false
    await fetchTemplates()
  } catch (e: any) {
    templateErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

async function duplicateTemplate(item: any) {
  try {
    await api.post(`/checklist_templates/${item.id}/duplicate`)
    await fetchTemplates()
  } catch (e: any) {
    alert(e.response?.data?.errors?.[0] || '複製に失敗しました')
  }
}

async function deleteTemplate(item: any) {
  if (!confirm(`「${item.name}」を削除しますか？`)) return
  try {
    await api.delete(`/checklist_templates/${item.id}`)
    await fetchTemplates()
  } catch (e: any) {
    alert(e.response?.data?.errors?.[0] || '削除に失敗しました（使用中の可能性があります）')
  }
}

// Manufacturers
const mfrs = ref<any[]>([])
const mfrDialog = ref(false)
const mfrForm = ref({ name: '', former_names: '', notes: '' })
const mfrEditingId = ref<number | null>(null)
const mfrErrors = ref<string[]>([])

async function fetchManufacturers() {
  const res = await api.get('/manufacturers')
  mfrs.value = res.data.data
}

function openMfrDialog(item?: any) {
  if (item) {
    mfrEditingId.value = item.id
    mfrForm.value = { name: item.name, former_names: item.former_names || '', notes: item.notes || '' }
  } else {
    mfrEditingId.value = null
    mfrForm.value = { name: '', former_names: '', notes: '' }
  }
  mfrErrors.value = []
  mfrDialog.value = true
}

async function saveMfr() {
  try {
    if (mfrEditingId.value) {
      await api.patch(`/manufacturers/${mfrEditingId.value}`, { manufacturer: mfrForm.value })
    } else {
      await api.post('/manufacturers', { manufacturer: mfrForm.value })
    }
    mfrDialog.value = false
    await fetchManufacturers()
  } catch (e: any) {
    mfrErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

// Warehouses
const whs = ref<any[]>([])
const whDialog = ref(false)
const whForm = ref({ name: '', site_id: null as number | null })
const whEditingId = ref<number | null>(null)
const whErrors = ref<string[]>([])

async function fetchWarehouses() {
  const res = await api.get('/warehouses')
  whs.value = res.data.data
}

function openWhDialog(item?: any) {
  if (item) {
    whEditingId.value = item.id
    whForm.value = { name: item.name, site_id: item.site_id }
  } else {
    whEditingId.value = null
    whForm.value = { name: '', site_id: null }
  }
  whErrors.value = []
  whDialog.value = true
}

async function saveWh() {
  try {
    if (whEditingId.value) {
      await api.patch(`/warehouses/${whEditingId.value}`, { warehouse: whForm.value })
    } else {
      await api.post('/warehouses', { warehouse: whForm.value })
    }
    whDialog.value = false
    await fetchWarehouses()
  } catch (e: any) {
    whErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

onMounted(() => {
  fetchServices()
  fetchLineClasses()
  fetchDepartments()
  fetchSites()
  fetchTemplates()
  fetchManufacturers()
  fetchWarehouses()
})
</script>

<template>
  <MainLayout>
    <h1 class="text-h5 mb-4">設定</h1>

    <v-tabs v-model="tab" class="mb-4">
      <v-tab value="services">サービス・流体</v-tab>
      <v-tab value="lineClasses">ラインクラス</v-tab>
      <v-tab value="departments">部署</v-tab>
      <v-tab value="checklists">チェックリスト</v-tab>
      <v-tab value="manufacturers">メーカー</v-tab>
      <v-tab value="warehouses">倉庫</v-tab>
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
      <!-- チェックリストテンプレート -->
      <v-window-item value="checklists">
        <div class="d-flex mb-2">
          <v-spacer />
          <v-btn color="primary" size="small" prepend-icon="mdi-plus" @click="openTemplateDialog()">追加</v-btn>
        </div>
        <v-data-table
          :headers="[
            { title: 'テンプレート名', key: 'name' },
            { title: '種別', key: 'inspection_type', width: '120px' },
            { title: '部署', key: 'department.name' },
            { title: '項目数', key: 'itemCount', width: '80px' },
            { title: '', key: 'actions', width: '150px', sortable: false },
          ]"
          :items="templates.map(t => ({ ...t, itemCount: (t.checklist_template_items || []).length }))"
          density="compact"
        >
          <template #item.inspection_type="{ item }">
            {{ inspectionTypeLabel[item.inspection_type] || item.inspection_type }}
          </template>
          <template #item.actions="{ item }">
            <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openTemplateDialog(item)" />
            <v-btn icon="mdi-content-copy" size="x-small" variant="text" @click="duplicateTemplate(item)" />
            <v-btn icon="mdi-delete" size="x-small" variant="text" color="error" @click="deleteTemplate(item)" />
          </template>
        </v-data-table>

        <v-dialog v-model="templateDialog" max-width="700">
          <v-card>
            <v-card-title>{{ templateEditingId ? 'テンプレート編集' : 'テンプレート作成' }}</v-card-title>
            <v-card-text>
              <v-alert v-if="templateErrors.length" type="error" density="compact" class="mb-4">
                <div v-for="err in templateErrors" :key="err">{{ err }}</div>
              </v-alert>
              <v-text-field v-model="templateForm.name" label="テンプレート名" class="mb-2" />
              <v-select v-model="templateForm.department_id" :items="departments" item-title="name" item-value="id" label="部署" class="mb-2" />
              <v-select v-model="templateForm.inspection_type" :items="inspectionTypeOptions" item-title="title" item-value="value" label="点検種別" class="mb-4" />

              <div class="d-flex align-center mb-2">
                <span class="text-subtitle-2">チェック項目</span>
                <v-spacer />
                <v-btn size="x-small" variant="outlined" prepend-icon="mdi-plus" @click="addTemplateItem">追加</v-btn>
              </div>
              <div v-for="(ci, idx) in templateForm.items" :key="idx" class="d-flex align-center mb-2 ga-2">
                <span class="text-body-2" style="min-width: 24px">{{ idx + 1 }}.</span>
                <v-text-field v-model="ci.content" label="内容" density="compact" hide-details class="flex-grow-1" />
                <v-select v-model="ci.item_type" :items="itemTypeOptions" item-title="title" item-value="value" density="compact" hide-details style="max-width: 140px" />
                <v-btn icon="mdi-close" size="x-small" variant="text" @click="removeTemplateItem(idx)" />
              </div>
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn @click="templateDialog = false">キャンセル</v-btn>
              <v-btn color="primary" @click="saveTemplate">保存</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-window-item>

      <!-- メーカー -->
      <v-window-item value="manufacturers">
        <div class="d-flex mb-2">
          <v-spacer />
          <v-btn color="primary" size="small" prepend-icon="mdi-plus" @click="openMfrDialog()">追加</v-btn>
        </div>
        <v-data-table
          :headers="[
            { title: 'メーカー名', key: 'name' },
            { title: '旧名称', key: 'former_names' },
            { title: '備考', key: 'notes' },
            { title: '', key: 'actions', width: '80px', sortable: false },
          ]"
          :items="mfrs"
          density="compact"
        >
          <template #item.actions="{ item }">
            <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openMfrDialog(item)" />
          </template>
        </v-data-table>

        <v-dialog v-model="mfrDialog" max-width="500">
          <v-card>
            <v-card-title>{{ mfrEditingId ? 'メーカー編集' : 'メーカー追加' }}</v-card-title>
            <v-card-text>
              <v-alert v-if="mfrErrors.length" type="error" density="compact" class="mb-4">
                <div v-for="err in mfrErrors" :key="err">{{ err }}</div>
              </v-alert>
              <v-text-field v-model="mfrForm.name" label="メーカー名" class="mb-2" />
              <v-text-field v-model="mfrForm.former_names" label="旧名称" class="mb-2" />
              <v-textarea v-model="mfrForm.notes" label="備考" rows="2" />
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn @click="mfrDialog = false">キャンセル</v-btn>
              <v-btn color="primary" @click="saveMfr">保存</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-window-item>

      <!-- 倉庫 -->
      <v-window-item value="warehouses">
        <div class="d-flex mb-2">
          <v-spacer />
          <v-btn color="primary" size="small" prepend-icon="mdi-plus" @click="openWhDialog()">追加</v-btn>
        </div>
        <v-data-table
          :headers="[
            { title: '倉庫名', key: 'name' },
            { title: '拠点', key: 'site.name' },
            { title: '', key: 'actions', width: '80px', sortable: false },
          ]"
          :items="whs"
          density="compact"
        >
          <template #item.actions="{ item }">
            <v-btn icon="mdi-pencil" size="x-small" variant="text" @click="openWhDialog(item)" />
          </template>
        </v-data-table>

        <v-dialog v-model="whDialog" max-width="500">
          <v-card>
            <v-card-title>{{ whEditingId ? '倉庫編集' : '倉庫追加' }}</v-card-title>
            <v-card-text>
              <v-alert v-if="whErrors.length" type="error" density="compact" class="mb-4">
                <div v-for="err in whErrors" :key="err">{{ err }}</div>
              </v-alert>
              <v-text-field v-model="whForm.name" label="倉庫名" class="mb-2" />
              <v-select v-model="whForm.site_id" :items="sites" item-title="name" item-value="id" label="拠点" />
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn @click="whDialog = false">キャンセル</v-btn>
              <v-btn color="primary" @click="saveWh">保存</v-btn>
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-window-item>
    </v-window>
  </MainLayout>
</template>
