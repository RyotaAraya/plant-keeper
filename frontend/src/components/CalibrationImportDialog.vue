<script setup lang="ts">
// キャリブレータ・校正管理ソフトの校正結果（JSON）を取り込む。ファイルを選ぶと、記録ごとに取り込めるかと理由を確認し（preview）、
// 取り込める記録だけを、5点校正の点検の下書きにする（記録に点検計画のIDがあれば、その計画のチェックリストの点検の下書き）。
// 提出は、各点検の内容を確かめてから人が行う
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import StatusChip from '@/components/StatusChip.vue'
import { useAuthStore } from '@/stores/auth'
import type { CalibrationResult } from '@/types/models'
import { RESULT_COLOR, RESULT_LABEL } from '@/utils/calibration'
import { downloadBlob } from '@/utils/download'
import { latestGuard } from '@/utils/latestGuard'

// 選んだファイル（使うのは名前と中身だけ）
type ChosenFile = { name: string; text: () => Promise<string> }

const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ imported: [] }>()
const authStore = useAuthStore()

const needsDepartment = computed(() => !authStore.user?.department_id)
const guard = latestGuard()
let session = 0
const importing = ref(false)
const departments = ref<any[]>([])
const departmentId = ref<number | null>(null)
const file = ref<ChosenFile | null>(null)
const content = ref('')
const preview = ref<any | null>(null)
const imported = ref<{ id: number; tag_number: string }[]>([])
const errors = ref<string[]>([])
const loading = ref(false)
// ファイルの選択欄は、開き直し・取り込みのあとに作り直して空にする
const inputKey = ref(0)

const importableCount = computed(() => preview.value?.importable_count ?? 0)

watch(open, async (isOpen) => {
  guard()
  const currentSession = ++session
  const isLatest = () => session === currentSession
  if (!isOpen) return
  file.value = null
  inputKey.value++
  content.value = ''
  preview.value = null
  imported.value = []
  errors.value = []
  loading.value = false
  departmentId.value = null
  if (!needsDepartment.value) return
  try {
    const res = await api.get('/departments', { params: { site_ids: [authStore.user?.site_id] } })
    if (isLatest()) departments.value = res.data.data
  } catch {
    if (isLatest()) errors.value = ['部署を読み込めませんでした。閉じてもう一度開いてください。']
  }
})

// 所属部署がある人はサーバの既定値を使う。部署のない人だけ明示的に指定する。
function payload() {
  return { file_name: file.value?.name, content: content.value,
    ...(needsDepartment.value ? { department_id: departmentId.value } : {}) }
}

async function chooseFile(value: ChosenFile | ChosenFile[] | null) {
  const isLatest = guard()
  file.value = (Array.isArray(value) ? value[0] : value) ?? null
  content.value = ''
  imported.value = []
  preview.value = null
  errors.value = []
  loading.value = !!file.value
  try {
    const text = file.value ? await file.value.text() : ''
    if (!isLatest()) return
    content.value = text
    await loadPreview()
  } catch {
    if (isLatest()) errors.value = ['ファイルを読み込めませんでした。選び直してください。']
  } finally {
    if (isLatest()) loading.value = false
  }
}

async function loadPreview() {
  const isLatest = guard()
  preview.value = null
  errors.value = []
  loading.value = false
  if (!file.value || (needsDepartment.value && !departmentId.value)) return
  loading.value = true
  try {
    const res = await api.post('/calibration_imports/preview', payload())
    if (isLatest()) preview.value = res.data.data
  } catch (e: any) {
    if (isLatest()) errors.value = e.response?.data?.errors || ['ファイルを確認できませんでした。もう一度確認してください。']
  } finally {
    if (isLatest()) loading.value = false
  }
}

async function runImport() {
  if (!file.value || !importableCount.value || loading.value || importing.value) return
  errors.value = []
  importing.value = true
  try {
    const res = await api.post('/calibration_imports', payload())
    imported.value = res.data.data.inspections
    preview.value = null
    file.value = null
    inputKey.value++
    emit('imported')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['取り込みに失敗しました']
    // 確認のあとに計器・基準器が変わったときは、最新の確認の結果を出す
    if (e.response?.data?.data) preview.value = e.response.data.data
  } finally {
    importing.value = false
  }
}

async function downloadSample() {
  try {
    const res = await api.get('/calibration_imports/sample')
    downloadBlob('calibration-sample.json', new globalThis.Blob([JSON.stringify(res.data, null, 2)], { type: 'application/json' }))
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['見本のファイルを作れませんでした']
  }
}

function formatDateTime(dt: string | null) {
  if (!dt) return '—'
  return new Date(dt).toLocaleString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

function resultLabel(result: CalibrationResult | null) {
  return result ? RESULT_LABEL[result] : '—'
}
</script>

<template>
  <v-dialog v-model="open" max-width="800" scrollable :persistent="importing" aria-labelledby="calibration-import-title">
    <v-card data-testid="calibration-import">
      <v-card-title id="calibration-import-title">校正結果の取り込み</v-card-title>
      <v-card-text>
        <p class="text-body-2 mb-4">校正ソフトの測定結果から、5点校正の点検記録をまとめて作れます。数値を1点ずつ転記する手間を省きます。</p>
        <ol class="import-steps mb-5" aria-label="取り込みの手順">
          <li :aria-current="!preview && !imported.length ? 'step' : undefined">1 ファイルを選ぶ</li>
          <li :aria-current="preview ? 'step' : undefined">2 内容を確認</li>
          <li :aria-current="imported.length ? 'step' : undefined">3 下書きを開く</li>
        </ol>
        <v-alert v-if="errors.length" type="error" variant="tonal" class="mb-4" role="alert">
          <div v-for="err in errors" :key="err">{{ err }}</div>
          <v-btn v-if="file && content && !importing" variant="text" :disabled="loading" @click="loadPreview">もう一度確認</v-btn>
        </v-alert>

        <section v-if="imported.length" data-testid="calibration-import-result" aria-live="polite">
          <h2 class="text-subtitle-1 font-weight-bold mb-2">{{ imported.length }}件を下書きとして取り込みました</h2>
          <p class="text-body-2 mb-3">取り込みは完了です。次に各記録を開き、測定値・使用した基準器・使用前の1点チェックを確認して提出してください。</p>
          <v-list lines="two" class="import-results">
            <v-list-item v-for="inspection in imported" :key="inspection.id" :to="`/inspections/${inspection.id}`" :title="inspection.tag_number" subtitle="下書きを確認する" append-icon="mdi-chevron-right" @click="open = false" />
          </v-list>
        </section>
        <template v-else>
          <h2 class="text-subtitle-1 font-weight-bold mb-2">校正結果のファイル</h2>
          <p class="text-body-2 text-medium-emphasis mb-3">PlantKeeper用のJSON形式に対応しています。Excel・CSVや、校正ソフト独自のファイルはそのまま取り込めません。</p>
          <v-file-input
            :key="inputKey" label="校正結果のファイル（JSON）" accept=".json,application/json"
            prepend-icon="" prepend-inner-icon="mdi-file-upload-outline" :disabled="loading || importing"
            @update:model-value="chooseFile"
          />
          <v-select
            v-if="needsDepartment" v-model="departmentId" :items="departments" item-title="full_path" item-value="id"
            label="記録する部署 *" hint="所属部署がないため、作業を依頼した部署を選んでください。" persistent-hint
            :disabled="loading || importing" class="mb-3" @update:model-value="loadPreview"
          />
          <p v-else class="text-body-2 text-medium-emphasis mb-3">記録する部署は、あなたの所属部署になります。</p>
          <details class="import-help mb-4">
            <summary>初めて使う方へ・ファイルの用意</summary>
            <div class="pt-3 text-body-2">
              <p>ファイルには計器のタグ番号、実施日時、5点の測定値、使用した基準器を含めます。校正ソフト側で対応形式に変換して用意してください。</p>
              <v-btn variant="outlined" size="small" prepend-icon="mdi-download" class="my-3" :disabled="importing" @click="downloadSample">見本のファイル</v-btn>
              <p>予定された校正は「計画 → 点検の期限順 → 校正の作業指示」から書き出せます。結果に計画のIDを含めると、その計画の点検になります。計画のIDがなければ、予定外の点検として記録します。</p>
              <p class="mt-2">見本も実際の下書きとして保存されます。形式の確認だけなら、ファイルを選んだ後の確認画面までで閉じてください。</p>
            </div>
          </details>
          <div v-if="loading" role="status" class="mb-4">
            <v-progress-linear indeterminate class="mb-2" />ファイルを確認しています。まだ記録は作成していません。
          </div>
          <section v-if="preview" aria-labelledby="import-preview-title" :aria-busy="importing">
            <h2 id="import-preview-title" class="text-subtitle-1 font-weight-bold">{{ preview.rows.length }}件中、{{ importableCount }}件を取り込めます</h2>
            <p v-if="preview.rows.length > importableCount" class="text-body-2 mb-3">{{ preview.rows.length - importableCount }}件は取り込みません。理由を確認してください。</p>
            <p v-else class="text-body-2 mb-3">すべての記録を下書きとして取り込めます。</p>
            <p v-if="preview.calibrator?.model" class="text-caption mb-3">キャリブレータ：{{ [preview.calibrator.model, preview.calibrator.serial_number].filter(Boolean).join(' / ') }}</p>
            <v-table density="compact" class="calibration-import-rows" data-testid="calibration-import-rows">
              <thead><tr><th>計器・実施日時</th><th>基準器</th><th>校正の判定</th><th>取り込み</th></tr></thead>
              <tbody>
                <tr v-for="row in preview.rows" :key="row.index">
                  <td>
                    <strong>{{ row.tag_number || 'タグ番号なし' }}</strong>
                    <div class="text-caption text-medium-emphasis">{{ row.instrument?.equipment_name || row.site_name }} ／ {{ row.index }}行目</div>
                    <div class="text-caption">{{ formatDateTime(row.performed_at) }}</div>
                    <div v-if="row.inspection_plan" class="text-caption" data-testid="calibration-import-plan">計画: {{ row.inspection_plan.name }}</div>
                    <div v-else class="text-caption">予定外の点検（計画の期限更新なし）</div>
                  </td>
                  <td data-label="基準器">{{ row.reference_standards.map((s: any) => s.management_number).join('、') || '—' }}</td>
                  <td data-label="校正の判定">
                    <StatusChip v-if="row.result" :label="resultLabel(row.result)" :color="RESULT_COLOR[row.result as CalibrationResult]" />
                    <span v-else>—</span>
                    <div v-if="row.adjusted" class="text-caption text-medium-emphasis">調整後</div>
                  </td>
                  <td data-label="取り込み">
                    <StatusChip v-if="row.importable" label="取り込む" color="primary" />
                    <template v-else>
                      <StatusChip label="取り込まない" color="grey" />
                      <ul class="text-caption text-error pl-4 mt-1"><li v-for="reason in row.reasons" :key="reason">{{ reason }}</li></ul>
                    </template>
                  </td>
                </tr>
              </tbody>
            </v-table>
          </section>
          <p class="text-body-2 mt-4">保存されるのは下書きです。計画の期限が進むのは、その点検を提出したときです。</p>
        </template>
      </v-card-text>
      <v-divider />
      <v-card-actions class="import-actions">
        <v-spacer />
        <v-btn :disabled="importing" @click="open = false">閉じる</v-btn>
        <v-btn v-if="!imported.length" color="primary" variant="flat" :disabled="!importableCount || loading" :loading="importing" @click="runImport">
          {{ importableCount ? `${importableCount}件を下書きとして取り込む` : '下書きとして取り込む' }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<style scoped>
.import-steps { display: flex; flex-wrap: wrap; gap: 8px 20px; list-style: none; padding: 0; color: var(--pk-muted); font-size: .8125rem; }
.import-steps [aria-current="step"] { color: rgb(var(--v-theme-primary)); font-weight: 700; }
.import-help { border: 1px solid var(--pk-line); border-radius: 8px; padding: 12px; }
.import-help summary { cursor: pointer; font-size: .875rem; font-weight: 600; }
.import-results { border: 1px solid var(--pk-line); border-radius: 8px; }
.calibration-import-rows td { padding-top: 12px !important; padding-bottom: 12px !important; overflow-wrap: anywhere; }
.import-actions { flex-wrap: wrap; padding: 12px 16px; }
@media (max-width: 600px) {
  .calibration-import-rows :deep(thead) { display: none; }
  .calibration-import-rows :deep(tr) { display: block; border-bottom: 1px solid var(--pk-line); padding: 8px 0; }
  .calibration-import-rows :deep(td) { display: block; height: auto !important; border: 0 !important; padding: 6px 0 !important; }
  .calibration-import-rows td[data-label]::before { content: attr(data-label); display: block; color: var(--pk-muted); font-size: .75rem; margin-bottom: 4px; }
}
</style>
