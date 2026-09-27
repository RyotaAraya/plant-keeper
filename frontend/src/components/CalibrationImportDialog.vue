<script setup lang="ts">
// キャリブレータ・校正管理ソフトの校正結果（JSON）を取り込む。ファイルを選ぶと、記録ごとに取り込めるかと理由を確認し（preview）、
// 取り込める記録だけを、5点校正の点検の下書きにする。提出は、各点検の内容を確かめてから人が行う
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import StatusChip from '@/components/StatusChip.vue'
import { useAuthStore } from '@/stores/auth'
import type { CalibrationResult } from '@/types/models'
import { RESULT_COLOR, RESULT_LABEL } from '@/utils/calibration'
import { downloadBlob } from '@/utils/download'

// 選んだファイル（使うのは名前と中身だけ）
type ChosenFile = { name: string; text: () => Promise<string> }

const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ imported: [] }>()
const authStore = useAuthStore()

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
  if (!isOpen) return
  file.value = null
  inputKey.value++
  content.value = ''
  preview.value = null
  imported.value = []
  errors.value = []
  departmentId.value = authStore.user?.department_id ?? null
  const siteId = authStore.user?.site_id
  const res = await api.get('/departments', { params: siteId ? { site_ids: [siteId] } : {} })
  departments.value = res.data.data
})

async function chooseFile(value: ChosenFile | ChosenFile[] | null) {
  const chosen = Array.isArray(value) ? value[0] : value
  file.value = chosen ?? null
  content.value = chosen ? await chosen.text() : ''
  imported.value = []
  await loadPreview()
}

async function loadPreview() {
  preview.value = null
  errors.value = []
  if (!file.value) return
  loading.value = true
  try {
    const res = await api.post('/calibration_imports/preview', { file_name: file.value.name, content: content.value, department_id: departmentId.value })
    preview.value = res.data.data
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['ファイルを確認できませんでした']
  } finally {
    loading.value = false
  }
}

async function runImport() {
  if (!file.value) return
  errors.value = []
  loading.value = true
  try {
    const res = await api.post('/calibration_imports', { file_name: file.value.name, content: content.value, department_id: departmentId.value })
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
    loading.value = false
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
  <v-dialog v-model="open" max-width="960" scrollable>
    <v-card data-testid="calibration-import">
      <v-card-title>校正結果の取り込み</v-card-title>
      <v-card-text>
        <div class="text-body-2 text-medium-emphasis mb-3">
          キャリブレータ・校正管理ソフトから書き出した5点校正の結果（JSON）を、計器ごとの点検の下書きにします。判定は手入力と同じです。
          取り込んだだけでは提出されないため、各点検の内容と使用前の1点チェックを確かめてから提出してください。
          <v-btn variant="text" size="small" density="compact" prepend-icon="mdi-download" class="ml-1" @click="downloadSample">見本のファイル</v-btn>
        </div>

        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-alert v-if="imported.length" type="success" variant="tonal" density="compact" class="mb-4" data-testid="calibration-import-result">
          {{ imported.length }}件を下書きとして取り込みました:
          <template v-for="(inspection, i) in imported" :key="inspection.id">
            <span v-if="i > 0">、</span>
            <router-link :to="`/inspections/${inspection.id}`" @click="open = false">{{ inspection.tag_number }}</router-link>
          </template>
        </v-alert>

        <div class="d-flex flex-wrap ga-3">
          <v-file-input
            :key="inputKey"
            label="校正結果のファイル（JSON）"
            accept=".json,application/json"
            prepend-icon=""
            prepend-inner-icon="mdi-file-upload-outline"
            density="compact"
            style="min-width: 280px; flex: 1"
            @update:model-value="chooseFile"
          />
          <v-select
            v-model="departmentId"
            :items="departments"
            item-title="full_path"
            item-value="id"
            label="取り込み先の部署 *"
            density="compact"
            style="min-width: 280px; flex: 1"
            @update:model-value="loadPreview"
          />
        </div>

        <template v-if="preview">
          <div class="text-body-2 mb-2">
            {{ preview.rows.length }}件のうち、<strong>{{ importableCount }}件</strong>を取り込めます
            <span v-if="preview.calibrator?.model" class="text-medium-emphasis">（キャリブレータ: {{ [preview.calibrator.model, preview.calibrator.serial_number].filter(Boolean).join(' / ') }}）</span>
          </div>
          <v-table density="compact" class="calibration-import-rows" data-testid="calibration-import-rows">
            <thead>
              <tr>
                <th style="width: 40px">行</th>
                <th>計器</th>
                <th>実施日時</th>
                <th>基準器</th>
                <th>判定</th>
                <th>取り込み</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in preview.rows" :key="row.index">
                <td>{{ row.index }}</td>
                <td>
                  <div class="font-weight-medium">{{ row.tag_number || '—' }}</div>
                  <div class="text-caption text-medium-emphasis">{{ row.instrument?.equipment_name || row.site_name }}</div>
                </td>
                <td>{{ formatDateTime(row.performed_at) }}</td>
                <td>{{ row.reference_standards.map((s: any) => s.management_number).join('、') || '—' }}</td>
                <td>
                  <StatusChip v-if="row.result" :label="resultLabel(row.result)" :color="RESULT_COLOR[row.result as CalibrationResult]" />
                  <span v-else>—</span>
                  <div v-if="row.adjusted" class="text-caption text-medium-emphasis">調整後</div>
                </td>
                <td>
                  <StatusChip v-if="row.importable" label="取り込む" color="primary" />
                  <template v-else>
                    <StatusChip label="取り込まない" color="grey" />
                    <ul class="text-caption text-error pl-4 mt-1">
                      <li v-for="reason in row.reasons" :key="reason">{{ reason }}</li>
                    </ul>
                  </template>
                </td>
              </tr>
            </tbody>
          </v-table>
        </template>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">閉じる</v-btn>
        <v-btn color="primary" :disabled="!importableCount" :loading="loading" @click="runImport">
          {{ importableCount }}件を下書きとして取り込む
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<style scoped>
/* 取り込みの理由以外は折り返さない（タグ番号・管理番号が途中で切れないように） */
.calibration-import-rows td:not(:last-child),
.calibration-import-rows th {
  white-space: nowrap;
}
</style>
