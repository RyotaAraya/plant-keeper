<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const route = useRoute()
const router = useRouter()
const editId = computed(() => route.params.id as string | undefined)
const isEdit = computed(() => !!editId.value && route.name === 'InspectionEdit')

const equipments = ref<any[]>([])
const instruments = ref<any[]>([])
const departments = ref<any[]>([])
const templates = ref<any[]>([])
const errors = ref<string[]>([])
const saving = ref(false)

const form = ref({
  equipment_id: null as number | null,
  instrument_id: null as number | null,
  department_id: null as number | null,
  checklist_template_id: null as number | null,
  inspection_type: 'routine',
  inspected_at: new Date().toISOString().slice(0, 16),
  notes: '',
  items: [] as any[],
})

const inspectionTypeOptions = [
  { title: '日常点検', value: 'routine' },
  { title: '定期点検', value: 'periodic' },
  { title: 'テレメトリ', value: 'telemetry' },
  { title: '運転チェック', value: 'operation_check' },
]

const itemTypeOptions = [
  { title: 'チェック', value: 'check' },
  { title: '計測値', value: 'measurement' },
  { title: 'テキスト', value: 'text' },
]

async function fetchMasters() {
  const [eqRes, deptRes, tmplRes] = await Promise.all([
    api.get('/equipments', { params: { per_page: 100 } }),
    api.get('/departments'),
    api.get('/checklist_templates'),
  ])
  equipments.value = eqRes.data.data
  departments.value = deptRes.data.data
  templates.value = tmplRes.data.data
}

async function fetchInstruments() {
  if (!form.value.equipment_id) {
    instruments.value = []
    return
  }
  const res = await api.get('/instruments', { params: { equipment_id: form.value.equipment_id, per_page: 100 } })
  instruments.value = res.data.data
}

function loadTemplate() {
  const tmpl = templates.value.find((t: any) => t.id === form.value.checklist_template_id)
  if (!tmpl) return
  form.value.inspection_type = tmpl.inspection_type
  form.value.items = (tmpl.checklist_template_items || []).map((item: any) => ({
    checklist_template_item_id: item.id,
    content: item.content,
    item_type: item.item_type,
    checked: false,
    measured_value: '',
    text_value: '',
    has_defect: false,
    defect_title: '',
    defect_description: '',
    defect_priority: 'medium',
    instrument_id: null,
  }))
}

function addItem() {
  form.value.items.push({
    content: '',
    item_type: 'check',
    checked: false,
    measured_value: '',
    text_value: '',
    has_defect: false,
    defect_title: '',
    defect_description: '',
    defect_priority: 'medium',
    instrument_id: null,
  })
}

function removeItem(idx: number) {
  form.value.items.splice(idx, 1)
}

async function save(status?: string) {
  errors.value = []
  saving.value = true
  try {
    const payload = {
      inspection: {
        ...form.value,
        status: status || 'draft',
      }
    }
    if (isEdit.value) {
      await api.patch(`/inspections/${editId.value}`, payload)
    } else {
      await api.post('/inspections', payload)
    }
    router.push('/inspections')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  } finally {
    saving.value = false
  }
}

async function loadExisting() {
  if (!isEdit.value) return
  const res = await api.get(`/inspections/${editId.value}`)
  const data = res.data.data
  form.value = {
    equipment_id: data.equipment_id,
    instrument_id: data.instrument_id,
    department_id: data.department_id,
    checklist_template_id: data.checklist_template_id,
    inspection_type: data.inspection_type,
    inspected_at: data.inspected_at?.slice(0, 16) || '',
    notes: data.notes || '',
    items: (data.inspection_items || []).map((item: any) => ({
      id: item.id,
      checklist_template_item_id: item.checklist_template_item_id,
      content: item.content,
      item_type: item.item_type,
      checked: item.checked,
      measured_value: item.measured_value || '',
      text_value: item.text_value || '',
      has_defect: item.has_defect,
      defect_title: '',
      defect_description: '',
      defect_priority: 'medium',
      instrument_id: item.instrument_id,
    })),
  }
  await fetchInstruments()
}

onMounted(async () => {
  await fetchMasters()
  await loadExisting()
})
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center mb-4">
      <v-btn icon="mdi-arrow-left" variant="text" @click="router.back()" />
      <h1 class="text-h5 ml-2">{{ isEdit ? '点検記録編集' : '新規点検記録' }}</h1>
    </div>

    <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
      <div v-for="err in errors" :key="err">{{ err }}</div>
    </v-alert>

    <v-card class="mb-4">
      <v-card-text>
        <v-row>
          <v-col cols="12" md="6">
            <v-select
              v-model="form.equipment_id"
              :items="equipments"
              item-title="name"
              item-value="id"
              label="設備 *"
              @update:model-value="fetchInstruments"
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-select
              v-model="form.instrument_id"
              :items="instruments"
              item-title="tag_number"
              item-value="id"
              label="計器（任意）"
              clearable
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-select
              v-model="form.department_id"
              :items="departments"
              item-title="name"
              item-value="id"
              label="部署 *"
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              v-model="form.inspected_at"
              label="点検日時 *"
              type="datetime-local"
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-select
              v-model="form.checklist_template_id"
              :items="templates"
              item-title="name"
              item-value="id"
              label="テンプレート（任意）"
              clearable
              @update:model-value="loadTemplate"
            />
          </v-col>
          <v-col cols="12" md="6">
            <v-select
              v-model="form.inspection_type"
              :items="inspectionTypeOptions"
              item-title="title"
              item-value="value"
              label="点検種別"
            />
          </v-col>
          <v-col cols="12">
            <v-textarea v-model="form.notes" label="備考" rows="2" />
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <div class="d-flex align-center mb-3">
      <h2 class="text-h6">点検項目</h2>
      <v-spacer />
      <v-btn size="small" variant="outlined" prepend-icon="mdi-plus" @click="addItem">項目追加</v-btn>
    </div>

    <v-card v-for="(item, idx) in form.items" :key="idx" class="mb-3" variant="outlined">
      <v-card-text>
        <div class="d-flex align-center mb-2">
          <span class="text-subtitle-2">項目 {{ idx + 1 }}</span>
          <v-spacer />
          <v-btn icon="mdi-close" size="x-small" variant="text" @click="removeItem(idx)" />
        </div>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-text-field v-model="item.content" label="内容" density="compact" />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="item.item_type" :items="itemTypeOptions" item-title="title" item-value="value" label="種別" density="compact" />
          </v-col>
          <v-col cols="6" md="3">
            <v-select v-model="item.instrument_id" :items="instruments" item-title="tag_number" item-value="id" label="計器" density="compact" clearable />
          </v-col>
        </v-row>
        <v-row dense>
          <v-col v-if="item.item_type === 'check'" cols="6" md="3">
            <v-checkbox v-model="item.checked" label="OK" density="compact" hide-details />
          </v-col>
          <v-col v-if="item.item_type === 'measurement'" cols="6" md="3">
            <v-text-field v-model="item.measured_value" label="計測値" density="compact" />
          </v-col>
          <v-col v-if="item.item_type === 'text'" cols="12" md="6">
            <v-text-field v-model="item.text_value" label="テキスト" density="compact" />
          </v-col>
          <v-col cols="6" md="3">
            <v-checkbox v-model="item.has_defect" label="不具合あり" density="compact" hide-details color="error" />
          </v-col>
        </v-row>
        <v-expand-transition>
          <v-row v-if="item.has_defect" dense class="mt-1">
            <v-col cols="12" md="5">
              <v-text-field v-model="item.defect_title" label="トラブルタイトル" density="compact" color="error" />
            </v-col>
            <v-col cols="12" md="4">
              <v-text-field v-model="item.defect_description" label="説明" density="compact" />
            </v-col>
            <v-col cols="6" md="3">
              <v-select
                v-model="item.defect_priority"
                :items="[{ title: '低', value: 'low' }, { title: '中', value: 'medium' }, { title: '高', value: 'high' }, { title: '緊急', value: 'critical' }]"
                item-title="title"
                item-value="value"
                label="優先度"
                density="compact"
              />
            </v-col>
          </v-row>
        </v-expand-transition>
      </v-card-text>
    </v-card>

    <div class="d-flex ga-3 mt-4">
      <v-btn @click="router.back()">キャンセル</v-btn>
      <v-spacer />
      <v-btn variant="outlined" :loading="saving" @click="save('draft')">下書き保存</v-btn>
      <v-btn color="primary" :loading="saving" @click="save('submitted')">提出</v-btn>
    </div>
  </MainLayout>
</template>
