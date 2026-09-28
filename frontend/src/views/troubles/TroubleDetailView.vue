<script setup lang="ts">
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import AiAvailability from '@/components/AiAvailability.vue'
import { useAiAvailability } from '@/composables/useAiAvailability'
import { useUnsavedWork } from '@/composables/useUnsavedWork'
import DeferTroubleDialog from '@/components/DeferTroubleDialog.vue'
import DiagnosticChip from '@/components/DiagnosticChip.vue'
import InstrumentHistoryList from '@/components/InstrumentHistoryList.vue'
import DetailHeader from '@/components/layout/DetailHeader.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import StatusChip from '@/components/StatusChip.vue'
import { useDetailTab } from '@/composables/useDetailTab'
import { usePermissions } from '@/composables/usePermissions'
import { useSimilarTroubles } from '@/composables/useSimilarTroubles'
import { responseTypeLabel } from '@/constants/recordLabels'
import ResourceHistory from '@/components/ResourceHistory.vue'
import ResponseAiAssist from '@/components/ResponseAiAssist.vue'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
import SimilarTroubleList from '@/components/SimilarTroubleList.vue'
import { nowForInput } from '@/utils/datetime'
import { latestGuard } from '@/utils/latestGuard'
import { revealApplied } from '@/utils/revealApplied'
import type { AiResponseDraft } from '@/types/models'

const route = useRoute()
const router = useRouter()

const { canUpdateTrouble, canCreateTroubleResponse, canViewUsers, canManageMaintenance } = usePermissions()
const trouble = ref<any>(null)
// 機器の診断から自動で作ったトラブルの報告者は、人ではなく連携（報告者の列には連携用のトークンを発行した人が入っている）
const reporterLabel = computed(() => {
  const t = trouble.value
  if (t?.source !== 'device_diagnostic') return t?.reported_by?.name ?? ''
  const connection = t.instrument_diagnostic?.integration_token?.name
  return connection ? `機器の診断（${connection}）` : '機器の診断'
})
// 詳細の中身は「概要 → タブ」（この計器の履歴は、計器があるときだけ）
const tab = useDetailTab(() => ['responses', ...(trouble.value?.instrument ? ['history'] : []), 'changes'])
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

const responseInitial = ref('')
const responseMemoDirty = ref(false)
const responseSession = ref(0)
const responseDirty = computed(() => responseDialog.value && (
  responseMemoDirty.value || JSON.stringify(responseForm.value) !== responseInitial.value
))
useUnsavedWork(responseDirty)
// 閉じたら、開いたボタンへフォーカスを戻すのは、アプリ全体の仕組み（utils/dialogFocusReturn.ts）に任せる。
// プラナの作業場から開いたとき（この画面で押したボタンがない）だけ、この画面の「対応記録」ボタンへ戻す
const responseButton = ref<{ $el: HTMLElement } | null>(null)
const responseOpenedWithoutOpener = ref(false)
const responseRecord = ref<HTMLElement | null>(null)
function hideResponse() {
  responseDialog.value = false
  if (responseOpenedWithoutOpener.value) nextTick(() => responseButton.value?.$el.focus())
}
function closeResponse() {
  if (responseDirty.value && !confirm('入力中の対応記録とメモを破棄しますか？')) return
  hideResponse()
  responseMemoDirty.value = false
  responseSession.value++
}

// AI支援（対応記録の下書き・類似トラブル）。状況が取れない・無効なときは、AIのボタンを出さない
const { status: aiStatus, loading: aiLoading, failed: aiFailed, refresh: fetchAiStatus } = useAiAvailability()
const similarButton = ref<{ $el: { focus(): void } } | null>(null)
function closeSimilar() {
  similar.clear()
  similarButton.value?.$el.focus()
}
const similar = useSimilarTroubles((count) => {
  if (aiStatus.value) aiStatus.value.remaining_today = count
})

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
  responseInitial.value = JSON.stringify(responseForm.value)
  responseMemoDirty.value = false
  responseSession.value++
  const active = document.activeElement
  responseOpenedWithoutOpener.value = !(active instanceof HTMLElement && active !== document.body)
  responseDialog.value = true
}

// AIの下書きを入力欄に入れる（保存はしない。対応日時は入れない）。対応種別は、AIが決められなかったときは今の値のまま。
// 反映したら「保存する内容」を見える位置に出し、対応内容へフォーカスを移す（スマホでは提案の下にあるため）
async function applyAiResponseDraft(draft: AiResponseDraft) {
  if (draft.response_type) responseForm.value.response_type = draft.response_type
  responseForm.value.description = draft.description
  if (draft.used_materials) responseForm.value.used_materials = draft.used_materials
  responseAiSuggestionId.value = draft.suggestion_id
  await nextTick()
  revealApplied(responseRecord.value, 'textarea')
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
    hideResponse()
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
      <DetailHeader back-to="/troubles" back-label="トラブル管理" kind="トラブル" :title="trouble.title">
        <template #status>
          <StatusChip kind="trouble" :value="trouble.status" />
          <StatusChip kind="priority" :value="trouble.priority" />
        </template>
        <template #meta>
          {{ trouble.equipment?.name }}<template v-if="trouble.instrument"> ／ {{ trouble.instrument.tag_number }}</template>
          ・ {{ reporterLabel }}が{{ formatDate(trouble.reported_at) }}に報告
        </template>
        <template #actions>
          <v-btn v-if="canDefer" color="deep-purple" variant="tonal" prepend-icon="mdi-wrench-clock" @click="deferDialog = true">定期整備に回す</v-btn>
          <v-btn v-if="canUpdateTrouble" variant="outlined" prepend-icon="mdi-pencil" @click="openEdit">編集</v-btn>
          <v-btn v-if="canCreateTroubleResponse" ref="responseButton" color="primary" prepend-icon="mdi-comment-plus" @click="openResponse">対応記録</v-btn>
        </template>
      </DetailHeader>

      <!-- 概要: 常に見える基本情報 -->
      <v-card class="mb-4 pk-summary" data-testid="detail-summary">
        <v-card-text>
          <dl class="pk-summary__grid">
            <div><dt>設備</dt><dd><router-link class="text-primary" :to="`/equipments/${trouble.equipment?.id}`">{{ trouble.equipment?.name }}</router-link></dd></div>
            <div>
              <dt>計器</dt>
              <dd><router-link v-if="trouble.instrument" class="text-primary" :to="`/instruments/${trouble.instrument.id}`">{{ trouble.instrument.tag_number }}</router-link><template v-else>—</template></dd>
            </div>
            <div><dt>報告者</dt><dd>{{ reporterLabel }}</dd></div>
            <div><dt>担当者</dt><dd>{{ trouble.assigned_to?.name || '未割当' }}</dd></div>
            <div><dt>報告日時</dt><dd>{{ formatDate(trouble.reported_at) }}</dd></div>
            <div><dt>解決日時</dt><dd>{{ trouble.resolved_at ? formatDate(trouble.resolved_at) : '—' }}</dd></div>
            <div v-if="trouble.instrument_diagnostic" class="pk-summary__wide" data-testid="trouble-diagnostic-source">
              <dt>発生元の診断</dt>
              <dd class="d-flex flex-wrap align-center ga-2">
                <DiagnosticChip :status="trouble.instrument_diagnostic.status" size="x-small" />
                <span>
                  {{ formatDate(trouble.instrument_diagnostic.occurred_at) }}
                  <template v-if="trouble.instrument_diagnostic.message"> ／ {{ trouble.instrument_diagnostic.message }}</template>
                  <template v-if="trouble.instrument_diagnostic.code">（{{ trouble.instrument_diagnostic.code }}）</template>
                  ／ 自動で登録
                </span>
              </dd>
            </div>
            <div v-if="trouble.inspection_item" class="pk-summary__wide">
              <dt>発生元点検</dt>
              <dd>
                <router-link class="text-primary" :to="`/inspections/${trouble.inspection_item?.inspection?.id}`">{{ formatDate(trouble.inspection_item.inspection?.inspected_at) }} の点検</router-link>
                ／ 項目: {{ trouble.inspection_item.content }}
              </dd>
            </div>
            <div v-if="trouble.maintenance_tasks?.length" class="pk-summary__wide" data-testid="deferred-card">
              <dt>定期整備</dt>
              <dd v-for="task in trouble.maintenance_tasks" :key="task.id">
                <router-link class="text-primary" :to="`/maintenances/${task.scheduled_maintenance_id}`">{{ task.scheduled_maintenance?.title }}</router-link>
                ／ 作業: {{ task.title }} <StatusChip kind="task" :value="task.status" class="ml-1" />
              </dd>
            </div>
            <div v-if="trouble.description" class="pk-summary__wide"><dt>詳細</dt><dd style="white-space: pre-wrap">{{ trouble.description }}</dd></div>
          </dl>
          <AiAvailability :status="aiStatus" :loading="aiLoading" :failed="aiFailed" @retry="fetchAiStatus" />
          <div v-if="aiStatus?.enabled" class="mt-3" data-testid="similar-section">
            <div class="d-flex align-center ga-3">
              <v-btn
                ref="similarButton"
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
            <SimilarTroubleList v-if="similar.result.value" :result="similar.result.value" @close="closeSimilar" />
          </div>
        </v-card-text>
      </v-card>

      <!-- 関連の一覧はタブで切り替える -->
      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="responses">対応記録（{{ trouble.trouble_responses?.length ?? 0 }}）</v-tab>
        <v-tab v-if="trouble.instrument" value="history">この計器の履歴</v-tab>
        <v-tab value="changes">変更履歴</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item value="responses">
          <v-timeline v-if="trouble.trouble_responses?.length" density="compact" side="end">
            <v-timeline-item
              v-for="resp in trouble.trouble_responses"
              :key="resp.id"
              :dot-color="resp.response_type === 'repair' ? 'primary' : resp.response_type === 'replacement' ? 'warning' : 'grey'"
              size="small"
            >
              <v-card variant="outlined">
                <v-card-text>
                  <div class="d-flex align-center mb-1">
                    <v-chip size="x-small" label variant="tonal" class="mr-2">{{ responseTypeLabel[resp.response_type] }}</v-chip>
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
          <div v-else class="text-center text-grey py-4">対応記録がありません</div>
        </v-window-item>
        <!-- この計器の過去のトラブルと点検。AIを使わずに、同じ計器の履歴を全件たどれる（各行から詳細へ、「すべて見る」から一覧へ） -->
        <v-window-item v-if="trouble.instrument" value="history">
          <v-card data-testid="instrument-history">
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
        </v-window-item>
        <v-window-item value="changes">
          <ResourceHistory auditable-type="Trouble" :auditable-id="trouble.id" />
        </v-window-item>
      </v-window>

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
      <v-dialog :model-value="responseDialog" scrollable :max-width="aiStatus?.enabled ? 1100 : 600" aria-labelledby="response-dialog-title" @update:model-value="!$event && closeResponse()">
        <v-card>
          <v-card-title id="response-dialog-title">対応記録追加</v-card-title>
          <v-card-text>
            <p class="text-body-2 text-medium-emphasis mb-4">{{ trouble.title }}の対応を記録します。内容を確認してから、「記録」で保存します。</p>
            <v-alert v-if="responseErrors.length" type="error" density="compact" class="mb-4">
              <div v-for="err in responseErrors" :key="err">{{ err }}</div>
            </v-alert>
            <AiAvailability :status="aiStatus" :loading="aiLoading" :failed="aiFailed" @retry="fetchAiStatus" />
            <div class="response-workspace" :class="{ 'response-workspace--assisted': aiStatus?.enabled }">
              <section v-if="aiStatus?.enabled" class="response-workspace__draft" aria-labelledby="response-draft-heading">
                <h2 id="response-draft-heading">メモをプラナに整理してもらう</h2>
                <p class="response-workspace__hint">行った対応を短いメモで入力してください。提案は確認してから反映できます。</p>
                <ResponseAiAssist
                  :key="responseSession"
                  :status="aiStatus"
                  :trouble-id="trouble.id"
                  :has-existing="!!responseForm.description.trim()"
                  @dirty="responseMemoDirty = $event"
                  @apply="applyAiResponseDraft"
                  @remaining="aiStatus.remaining_today = $event"
                />
              </section>
              <section ref="responseRecord" class="response-workspace__record" aria-labelledby="response-record-heading">
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
            <v-btn @click="closeResponse">キャンセル</v-btn>
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
