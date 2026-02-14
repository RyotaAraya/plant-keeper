<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const route = useRoute()
const router = useRouter()
const trouble = ref<any>(null)
const loading = ref(true)
const users = ref<any[]>([])

// Edit dialog
const editDialog = ref(false)
const editForm = ref({ status: '', priority: '', assigned_to_id: null as number | null })
const editErrors = ref<string[]>([])

// Response dialog
const responseDialog = ref(false)
const responseForm = ref({
  response_type: 'investigation',
  description: '',
  used_materials: '',
  responded_at: new Date().toISOString().slice(0, 16),
})
const responseErrors = ref<string[]>([])

const statusLabel: Record<string, string> = {
  open: '未対応', in_progress: '対応中', resolved: '解決済', closed: '完了'
}
const statusColor: Record<string, string> = {
  open: 'error', in_progress: 'warning', resolved: 'info', closed: 'success'
}
const priorityLabel: Record<string, string> = {
  low: '低', medium: '中', high: '高', critical: '緊急'
}
const priorityColor: Record<string, string> = {
  low: 'success', medium: 'info', high: 'warning', critical: 'error'
}
const responseTypeLabel: Record<string, string> = {
  investigation: '調査', repair: '修理', replacement: '交換', observation: '経過観察'
}

const statusOptions = [
  { title: '未対応', value: 'open' },
  { title: '対応中', value: 'in_progress' },
  { title: '解決済', value: 'resolved' },
  { title: '完了', value: 'closed' },
]
const priorityOptions = [
  { title: '低', value: 'low' },
  { title: '中', value: 'medium' },
  { title: '高', value: 'high' },
  { title: '緊急', value: 'critical' },
]
const responseTypeOptions = [
  { title: '調査', value: 'investigation' },
  { title: '修理', value: 'repair' },
  { title: '交換', value: 'replacement' },
  { title: '経過観察', value: 'observation' },
]

async function fetchTrouble() {
  loading.value = true
  try {
    const res = await api.get(`/troubles/${route.params.id}`)
    trouble.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function fetchUsers() {
  // Simple fetch — will be improved in Phase 4
  try {
    const res = await api.get('/current_user')
    users.value = [res.data.user]
  } catch { /* ignore */ }
}

function openEdit() {
  editForm.value = {
    status: trouble.value.status,
    priority: trouble.value.priority,
    assigned_to_id: trouble.value.assigned_to_id,
  }
  editErrors.value = []
  editDialog.value = true
}

async function saveEdit() {
  editErrors.value = []
  try {
    const payload: any = { trouble: { ...editForm.value } }
    if (editForm.value.status === 'resolved' || editForm.value.status === 'closed') {
      payload.trouble.resolved_at = new Date().toISOString()
    }
    await api.patch(`/troubles/${route.params.id}`, payload)
    editDialog.value = false
    await fetchTrouble()
  } catch (e: any) {
    editErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function openResponse() {
  responseForm.value = {
    response_type: 'investigation',
    description: '',
    used_materials: '',
    responded_at: new Date().toISOString().slice(0, 16),
  }
  responseErrors.value = []
  responseDialog.value = true
}

async function saveResponse() {
  responseErrors.value = []
  try {
    await api.post('/trouble_responses', {
      trouble_response: {
        trouble_id: trouble.value.id,
        ...responseForm.value,
      }
    })
    responseDialog.value = false
    await fetchTrouble()
  } catch (e: any) {
    responseErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

onMounted(() => {
  fetchTrouble()
  fetchUsers()
})
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="trouble">
      <div class="d-flex align-center mb-4">
        <v-btn icon="mdi-arrow-left" variant="text" @click="router.push('/troubles')" />
        <h1 class="text-h5 ml-2">{{ trouble.title }}</h1>
        <v-spacer />
        <v-btn class="mr-2" variant="outlined" @click="openEdit">
          <v-icon start>mdi-pencil</v-icon>編集
        </v-btn>
        <v-btn color="primary" @click="openResponse">
          <v-icon start>mdi-comment-plus</v-icon>対応記録
        </v-btn>
      </div>

      <v-card class="mb-4">
        <v-card-text>
          <v-row>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">ステータス</div>
              <v-chip :color="statusColor[trouble.status]" size="small">
                {{ statusLabel[trouble.status] }}
              </v-chip>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">優先度</div>
              <v-chip :color="priorityColor[trouble.priority]" size="small">
                {{ priorityLabel[trouble.priority] }}
              </v-chip>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">報告日時</div>
              <div>{{ formatDate(trouble.reported_at) }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">解決日時</div>
              <div>{{ trouble.resolved_at ? formatDate(trouble.resolved_at) : '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">設備</div>
              <a class="text-primary" style="cursor:pointer" @click="router.push(`/equipments/${trouble.equipment?.id}`)">
                {{ trouble.equipment?.name }}
              </a>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">計器</div>
              <div>{{ trouble.instrument?.tag_number || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">報告者</div>
              <div>{{ trouble.reported_by?.name }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">担当者</div>
              <div>{{ trouble.assigned_to?.name || '未割当' }}</div>
            </v-col>
          </v-row>
          <div v-if="trouble.description" class="mt-3">
            <div class="text-caption text-grey">詳細</div>
            <div style="white-space: pre-wrap">{{ trouble.description }}</div>
          </div>
          <div v-if="trouble.inspection_item" class="mt-3">
            <div class="text-caption text-grey">発生元点検</div>
            <v-chip size="small" class="mr-2" @click="router.push(`/inspections/${trouble.inspection_item?.inspection?.id}`)">
              {{ trouble.inspection_item.inspection?.inspection_type }} — {{ formatDate(trouble.inspection_item.inspection?.inspected_at) }}
            </v-chip>
            <span>項目: {{ trouble.inspection_item.content }}</span>
          </div>
        </v-card-text>
      </v-card>

      <h2 class="text-h6 mb-3">対応履歴</h2>
      <v-timeline density="compact" side="end">
        <v-timeline-item
          v-for="resp in trouble.trouble_responses"
          :key="resp.id"
          :dot-color="resp.response_type === 'repair' ? 'primary' : resp.response_type === 'replacement' ? 'warning' : 'grey'"
          size="small"
        >
          <v-card variant="outlined">
            <v-card-text>
              <div class="d-flex align-center mb-1">
                <v-chip size="x-small" class="mr-2">{{ responseTypeLabel[resp.response_type] }}</v-chip>
                <span class="text-body-2 font-weight-bold">{{ resp.user?.name }}</span>
                <v-spacer />
                <span class="text-caption text-grey">{{ formatDate(resp.responded_at) }}</span>
              </div>
              <div style="white-space: pre-wrap">{{ resp.description }}</div>
              <div v-if="resp.used_materials" class="mt-1 text-caption">
                <v-icon size="x-small">mdi-package-variant</v-icon> 使用資材: {{ resp.used_materials }}
              </div>
            </v-card-text>
          </v-card>
        </v-timeline-item>
      </v-timeline>

      <div v-if="!trouble.trouble_responses?.length" class="text-center text-grey py-4">
        対応記録がありません
      </div>

      <!-- Edit Dialog -->
      <v-dialog v-model="editDialog" max-width="500">
        <v-card>
          <v-card-title>トラブル編集</v-card-title>
          <v-card-text>
            <v-alert v-if="editErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in editErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-select v-model="editForm.status" :items="statusOptions" item-title="title" item-value="value" label="ステータス" class="mb-2" />
            <v-select v-model="editForm.priority" :items="priorityOptions" item-title="title" item-value="value" label="優先度" class="mb-2" />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn @click="editDialog = false">キャンセル</v-btn>
            <v-btn color="primary" @click="saveEdit">保存</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>

      <!-- Response Dialog -->
      <v-dialog v-model="responseDialog" max-width="600">
        <v-card>
          <v-card-title>対応記録追加</v-card-title>
          <v-card-text>
            <v-alert v-if="responseErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in responseErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-select v-model="responseForm.response_type" :items="responseTypeOptions" item-title="title" item-value="value" label="対応種別" class="mb-2" />
            <v-textarea v-model="responseForm.description" label="対応内容 *" rows="4" class="mb-2" />
            <v-text-field v-model="responseForm.used_materials" label="使用資材" class="mb-2" />
            <v-text-field v-model="responseForm.responded_at" label="対応日時" type="datetime-local" />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn @click="responseDialog = false">キャンセル</v-btn>
            <v-btn color="primary" @click="saveResponse">記録</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </template>
  </MainLayout>
</template>
