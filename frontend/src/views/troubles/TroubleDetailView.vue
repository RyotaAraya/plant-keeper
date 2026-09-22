<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import DeferTroubleDialog from '@/components/DeferTroubleDialog.vue'
import InstrumentHistoryList from '@/components/InstrumentHistoryList.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'
import { useSimilarTroubles } from '@/composables/useSimilarTroubles'
import { priorityColor, priorityLabel, troubleStatusColor, troubleStatusLabel } from '@/constants/recordLabels'
import ResourceHistory from '@/components/ResourceHistory.vue'
import ResponseAiAssist from '@/components/ResponseAiAssist.vue'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
import SimilarTroubleList from '@/components/SimilarTroubleList.vue'
import { nowForInput } from '@/utils/datetime'
import { latestGuard } from '@/utils/latestGuard'
import type { AiResponseDraft, AiStatus } from '@/types/models'

const route = useRoute()
const router = useRouter()
const { canUpdateTrouble, canCreateTroubleResponse, canViewUsers, canManageMaintenance } = usePermissions()
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
  responded_at: nowForInput(),
})
const responseErrors = ref<string[]>([])
// AIの下書きを反映したときの提案のID（保存のときに送り、AIの案と確定した内容を突き合わせられるようにする）
const responseAiSuggestionId = ref<number | null>(null)

// AI支援（対応記録の下書き・類似トラブル）。状況が取れない・無効なときは、AIのボタンを出さない
const aiStatus = ref<AiStatus | null>(null)
const similar = useSimilarTroubles((count) => {
  if (aiStatus.value) aiStatus.value.remaining_today = count
})

const responseTypeLabel: Record<string, string> = {
  investigation: '調査', repair: '修理', replacement: '交換', observation: '経過観察'
}

const statusOptions = [
  { title: '未対応', value: 'open' },
  { title: '対応中', value: 'in_progress' },
  { title: '定修待ち', value: 'deferred' },
  { title: '解決済', value: 'resolved' },
  { title: '完了', value: 'closed' },
]
// バックエンド（Trouble::STATUS_TRANSITIONS）と同じ。現在のステータスと、そこから進められるものだけを選択肢にする
const allowedNext: Record<string, string[]> = {
  open: ['in_progress', 'resolved', 'closed', 'deferred'],
  in_progress: ['open', 'resolved', 'closed', 'deferred'],
  resolved: ['in_progress', 'closed', 'deferred'],
  deferred: ['open', 'in_progress', 'resolved', 'closed'],
  closed: [],
}
// 定修待ちは、「定期整備に回す」で作業に回したときだけ設定できるため、手動の選択肢には出さない（今が定修待ちのときの表示だけ）
const selectableStatusOptions = computed(() =>
  statusOptions.filter(
    (o) => o.value === trouble.value?.status || (o.value !== 'deferred' && (allowedNext[trouble.value?.status] ?? []).includes(o.value))
  )
)

// 定期整備に回せるのは、未対応・対応中で、回した作業（見送りを除く）がないトラブル。操作は定期整備を管理する人
const canDefer = computed(
  () => canManageMaintenance.value && ['open', 'in_progress'].includes(trouble.value?.status) && !(trouble.value?.maintenance_tasks ?? []).some((t: any) => t.status !== 'cancelled'),
)
const deferDialog = ref(false)
async function onDeferred(maintenanceId: number) {
  await router.push(`/maintenances/${maintenanceId}`)
}
const taskStatusLabel: Record<string, string> = { not_started: '未着手', in_progress: '実施中', completed: '完了', cancelled: '見送り' }
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

// 履歴の行や戻る操作で、続けて別のトラブルへ移ることがある。古い取得の応答が、あとから新しい表示を上書きしないようにする
const fetchGuard = latestGuard()

// keepContent: 保存のあとの読み込み直しは、画面を作り直さずに（進捗表示に切り替えずに）、今の表示のまま更新する
async function fetchTrouble({ keepContent = false } = {}) {
  const isLatest = fetchGuard()
  if (!keepContent) loading.value = true
  try {
    const res = await api.get(`/troubles/${route.params.id}`)
    if (!isLatest()) return
    trouble.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

async function fetchUsers() {
  if (users.value.length) return
  const res = await api.get('/users', { params: { per_page: 200 } })
  users.value = res.data.data
}

async function openEdit() {
  // ユーザ一覧を見られない協力会社は、担当者の選択欄を出さない（担当者は変更できない）
  if (canViewUsers.value) await fetchUsers()
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
    await api.patch(`/troubles/${route.params.id}`, payload)
    editDialog.value = false
    await fetchTrouble({ keepContent: true })
  } catch (e: any) {
    editErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function openResponse() {
  if (!canCreateTroubleResponse.value || !trouble.value) return
  responseForm.value = {
    response_type: 'investigation',
    description: '',
    used_materials: '',
    responded_at: nowForInput(),
  }
  responseAiSuggestionId.value = null
  responseErrors.value = []
  responseDialog.value = true
}

async function fetchAiStatus() {
  try {
    aiStatus.value = (await api.get('/ai/status')).data.data
  } catch {
    // AIの状況が取れなくても、トラブルの表示・対応記録には影響しない（AIのボタンを出さないだけ）
    aiStatus.value = null
  }
}

// AIの下書きを入力欄に入れる（保存はしない。対応日時は入れない）。対応種別は、AIが決められなかったときは今の値のまま
function applyAiResponseDraft(draft: AiResponseDraft) {
  if (draft.response_type) responseForm.value.response_type = draft.response_type
  responseForm.value.description = draft.description
  if (draft.used_materials) responseForm.value.used_materials = draft.used_materials
  responseAiSuggestionId.value = draft.suggestion_id
}

// このトラブルのタイトルと詳細を現場メモとして、過去の類似トラブルを探す（このトラブル自身は候補から外す）
function searchSimilar() {
  const memo = [trouble.value.title, trouble.value.description].filter(Boolean).join('\n').slice(0, aiStatus.value?.max_memo_length)
  return similar.search({
    equipmentId: trouble.value.equipment_id,
    instrumentId: trouble.value.instrument_id,
    memo,
    excludeTroubleId: trouble.value.id,
  })
}

async function saveResponse() {
  responseErrors.value = []
  try {
    await api.post('/trouble_responses', {
      trouble_response: {
        trouble_id: trouble.value.id,
        ...responseForm.value,
        ai_suggestion_id: responseAiSuggestionId.value,
      }
    })
    responseDialog.value = false
    await fetchTrouble({ keepContent: true })
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
  fetchAiStatus()
})

// 目的を持って開いたときだけ入力欄を開く。AIは利用者が押すまで呼び出さない。
watch([() => trouble.value?.id, () => route.query.plana], ([id, task]) => {
  if (id === Number(route.params.id) && task === 'response-draft' && canCreateTroubleResponse.value) openResponse()
})

// 履歴の行から別のトラブルへ移ると、同じ画面のまま ID だけが変わる。読み込み直し、前のトラブルへのAIの結果は消す
watch(() => route.params.id, (id, previous) => {
  if (id && id !== previous) {
    responseDialog.value = false
    responseAiSuggestionId.value = null
    similar.clear()
    fetchTrouble()
  }
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
        <v-btn v-if="canDefer" class="mr-2" color="deep-purple" variant="tonal" prepend-icon="mdi-wrench-clock" @click="deferDialog = true">定期整備に回す</v-btn>
        <v-btn v-if="canUpdateTrouble" class="mr-2" variant="outlined" @click="openEdit">
          <v-icon start>mdi-pencil</v-icon>編集
        </v-btn>
        <v-btn v-if="canCreateTroubleResponse" color="primary" @click="openResponse">
          <v-icon start>mdi-comment-plus</v-icon>対応記録
        </v-btn>
      </div>

      <v-card class="mb-4">
        <v-card-text>
          <v-row>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">ステータス</div>
              <v-chip :color="troubleStatusColor[trouble.status]" size="small">
                {{ troubleStatusLabel[trouble.status] }}
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
              <router-link v-if="trouble.instrument" class="text-primary" :to="`/instruments/${trouble.instrument.id}`">{{ trouble.instrument.tag_number }}</router-link>
              <div v-else>—</div>
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

      <v-card v-if="trouble.maintenance_tasks?.length" class="mb-4" data-testid="deferred-card">
        <v-card-title class="text-subtitle-1">定期整備</v-card-title>
        <v-card-text>
          <div v-for="task in trouble.maintenance_tasks" :key="task.id" class="d-flex align-center ga-2 mb-1">
            <a class="text-primary" style="cursor: pointer" @click="router.push(`/maintenances/${task.scheduled_maintenance_id}`)">{{ task.scheduled_maintenance?.title }}</a>
            <span class="text-caption text-medium-emphasis">作業: {{ task.title }}</span>
            <v-chip size="x-small" label variant="tonal">{{ taskStatusLabel[task.status] }}</v-chip>
          </div>
        </v-card-text>
      </v-card>

      <!-- この計器の過去のトラブルと点検。AIを使わずに、同じ計器の履歴を全件たどれる（各行から詳細へ、「すべて見る」から一覧へ） -->
      <v-card v-if="trouble.instrument" class="mb-4" data-testid="instrument-history">
        <v-card-title class="text-subtitle-1">
          この計器（<router-link class="text-primary" :to="`/instruments/${trouble.instrument.id}`">{{ trouble.instrument.tag_number }}</router-link>）の履歴
        </v-card-title>
        <v-card-text>
          <v-row>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis mb-1">過去のトラブル</div>
              <InstrumentHistoryList kind="troubles" :instrument-id="trouble.instrument.id" :exclude-trouble-id="trouble.id" />
            </v-col>
            <v-col cols="12" md="6">
              <div class="text-caption text-medium-emphasis mb-1">最近の点検</div>
              <InstrumentHistoryList kind="inspections" :instrument-id="trouble.instrument.id" />
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <div v-if="aiStatus?.enabled" class="mb-4" data-testid="similar-section">
        <div class="d-flex align-center ga-3">
          <v-btn
            size="small"
            variant="tonal"
            color="primary"
            :loading="similar.loading.value"
            :disabled="aiStatus.remaining_today <= 0"
            data-testid="ai-similar-button"
            @click="searchSimilar"
          >
            <template #prepend><PlanaAvatar :size="20" /></template>
            過去の類似トラブルを探す
          </v-btn>
          <span class="text-caption text-medium-emphasis">今日の残り {{ aiStatus.remaining_today }} / {{ aiStatus.daily_limit }} 回</span>
        </div>
        <v-alert v-if="similar.error.value" type="warning" variant="tonal" density="compact" class="mt-2" data-testid="ai-similar-error">{{ similar.error.value }}</v-alert>
        <SimilarTroubleList v-if="similar.result.value" :result="similar.result.value" @close="similar.clear()" />
      </div>

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

      <v-divider class="my-4" />
      <h2 class="text-h6 mb-3">変更履歴</h2>
      <ResourceHistory auditable-type="Trouble" :auditable-id="trouble.id" />

      <!-- Edit Dialog -->
      <v-dialog v-model="editDialog" max-width="500">
        <v-card>
          <v-card-title>トラブル編集</v-card-title>
          <v-card-text>
            <v-alert v-if="editErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in editErrors" :key="err">{{ err }}</div>
            </v-alert>
            <v-select v-model="editForm.status" :items="selectableStatusOptions" item-title="title" item-value="value" label="ステータス" class="mb-2" />
            <v-select v-model="editForm.priority" :items="priorityOptions" item-title="title" item-value="value" label="優先度" class="mb-2" />
            <v-autocomplete
              v-if="canViewUsers"
              v-model="editForm.assigned_to_id"
              :items="users"
              item-title="name"
              item-value="id"
              label="担当者"
              clearable
              class="mb-2"
            />
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn @click="editDialog = false">キャンセル</v-btn>
            <v-btn color="primary" @click="saveEdit">保存</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>

      <!-- Response Dialog -->
      <v-dialog v-model="responseDialog" :max-width="aiStatus?.enabled ? 1100 : 600" aria-labelledby="response-dialog-title">
        <v-card>
          <v-card-title id="response-dialog-title">対応記録追加</v-card-title>
          <v-card-text>
            <p class="text-body-2 text-medium-emphasis mb-4">{{ trouble.title }}の対応を記録します。下書きを確認・反映したあと、「記録」で保存します。</p>
            <v-alert v-if="responseErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in responseErrors" :key="err">{{ err }}</div>
            </v-alert>
            <div class="response-workspace" :class="{ 'response-workspace--assisted': aiStatus?.enabled }">
              <section v-if="aiStatus?.enabled" class="response-workspace__draft" aria-labelledby="response-draft-heading">
                <h2 id="response-draft-heading">メモから下書きを作る</h2>
                <p class="response-workspace__hint">行った対応を短いメモで入力してください。提案は確認してから反映できます。</p>
                <ResponseAiAssist
                  :status="aiStatus"
                  :trouble-id="trouble.id"
                  :has-existing="!!responseForm.description.trim()"
                  @apply="applyAiResponseDraft"
                  @remaining="aiStatus.remaining_today = $event"
                />
              </section>
              <section class="response-workspace__record" aria-labelledby="response-record-heading">
                <h2 id="response-record-heading">保存する内容</h2>
                <p class="response-workspace__hint">直接入力・編集できます。「記録」を押すと保存されます。</p>
                <v-select v-model="responseForm.response_type" :items="responseTypeOptions" item-title="title" item-value="value" label="対応種別" class="mb-2" />
                <v-textarea v-model="responseForm.description" label="対応内容 *" rows="4" class="mb-2" />
                <v-text-field v-model="responseForm.used_materials" label="使用資材" class="mb-2" />
                <v-text-field v-model="responseForm.responded_at" label="対応日時" type="datetime-local" />
              </section>
            </div>
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn @click="responseDialog = false">キャンセル</v-btn>
            <v-btn color="primary" @click="saveResponse">記録</v-btn>
          </v-card-actions>
        </v-card>
      </v-dialog>
    </template>
    <DeferTroubleDialog v-if="trouble" v-model="deferDialog" :trouble="trouble" @done="onDeferred" />
  </MainLayout>
</template>

<style scoped>
.response-workspace { display: grid; gap: 24px; }
.response-workspace--assisted { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: start; }
.response-workspace h2 { font-size: 1rem; margin-bottom: 8px; color: var(--pk-plana-navy); }
.response-workspace__hint { font-size: 0.8125rem; line-height: 1.7; color: var(--pk-muted); margin-bottom: 20px; }
.response-workspace__draft { padding: 20px; background: var(--pk-mist); border: 1px solid var(--pk-line); border-radius: 12px; }
.response-workspace__record { padding-top: 20px; }
@media (max-width: 960px) {
  .response-workspace--assisted { grid-template-columns: minmax(0, 1fr); }
}
</style>
