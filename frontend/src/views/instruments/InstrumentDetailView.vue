<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import DetailHeader from '@/components/layout/DetailHeader.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import { useDetailTab } from '@/composables/useDetailTab'
import { usePermissions } from '@/composables/usePermissions'
import InstrumentCalibrationFields from '@/components/InstrumentCalibrationFields.vue'
import InstrumentHistoryList from '@/components/InstrumentHistoryList.vue'
import CalibrationTrendChart from '@/components/CalibrationTrendChart.vue'
import InterlockChips from '@/components/InterlockChips.vue'
import ResourceHistory from '@/components/ResourceHistory.vue'
import DiagnosticChip from '@/components/DiagnosticChip.vue'
import { DIAGNOSTIC_STATUS } from '@/constants/diagnostics'
import { formatDateTime } from '@/utils/interlock'
import {
  CHARACTERISTIC_LABEL,
  TOLERANCE_BASIS_LABEL,
  calibrationFieldsFrom,
  calibrationFieldsPayload,
  emptyCalibrationFields,
  type CalibrationFields,
} from '@/utils/calibration'
import type { CalibrationHistoryRow, InstrumentDiagnostic } from '@/types/models'

const route = useRoute()
const router = useRouter()
const { canManageEquipment } = usePermissions()

const instrument = ref<any>(null)
const loading = ref(false)
// 詳細の中身は「概要 → タブ」（校正の傾向・機器の診断は、あるときだけ）
const tab = useDetailTab(() => [
  'troubles',
  'inspections',
  ...(instrument.value?.calibratable || calibrationHistory.value.length ? ['calibration'] : []),
  ...(diagnostics.value.length ? ['diagnostics'] : []),
  'history',
])

// --- 編集 ---
const editDialog = ref(false)
const editErrors = ref<string[]>([])
const editForm = ref({
  equipment_id: null as number | null,
  tag_number: '',
  instrument_type: '',
  service_id: null as number | null,
  line_class_id: null as number | null,
  location: '',
  notes: '',
  seal_fluid: '',
})
const calibrationForm = ref<CalibrationFields>(emptyCalibrationFields())
const equipments = ref<any[]>([])
const services = ref<any[]>([])
const lineClasses = ref<any[]>([])

async function openEditInstrument() {
  if (!equipments.value.length) {
    const [eqRes, svcRes, lcRes] = await Promise.all([
      api.get('/equipments', { params: { per_page: 100 } }),
      api.get('/services'),
      api.get('/line_classes'),
    ])
    equipments.value = eqRes.data.data
    services.value = svcRes.data.data
    lineClasses.value = lcRes.data.data
  }
  editForm.value = {
    equipment_id: instrument.value.equipment_id,
    tag_number: instrument.value.tag_number,
    instrument_type: instrument.value.instrument_type || '',
    service_id: instrument.value.service_id ?? null,
    line_class_id: instrument.value.line_class_id ?? null,
    location: instrument.value.location || '',
    notes: instrument.value.notes || '',
    seal_fluid: instrument.value.seal_fluid || '',
  }
  calibrationForm.value = calibrationFieldsFrom(instrument.value)
  editErrors.value = []
  editDialog.value = true
}

async function saveInstrument() {
  editErrors.value = []
  try {
    await api.patch(`/instruments/${route.params.id}`, { instrument: { ...editForm.value, ...calibrationFieldsPayload(calibrationForm.value) } })
    editDialog.value = false
    await fetchInstrument()
  } catch (e: any) {
    editErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

async function fetchInstrument() {
  loading.value = true
  try {
    const res = await api.get(`/instruments/${route.params.id}`)
    instrument.value = res.data.data
  } finally {
    loading.value = false
  }
}

// 5点校正の記録（古い順）。表は新しい順に出す
const calibrationHistory = computed<CalibrationHistoryRow[]>(() => instrument.value?.calibration_history ?? [])
// 機器の自己診断（NAMUR NE 107）の状態が変わった記録（新しい順）
const diagnostics = computed<InstrumentDiagnostic[]>(() => instrument.value?.diagnostics ?? [])
const calibrationRowsNewestFirst = computed(() => [...calibrationHistory.value].reverse())
const STAGE_RESULT_LABEL: Record<string, string> = { pass: '合格', fail: '不合格', incomplete: '未記入あり', empty: '—' }
const STAGE_RESULT_COLOR: Record<string, string> = { pass: 'success', fail: 'error', incomplete: 'warning', empty: 'grey' }
const formatError = (value: number | null | undefined) => (value == null ? '—' : `${value.toFixed(2)}%`)
const formatDate = (value: string) => new Date(value).toLocaleDateString('ja-JP', { timeZone: 'Asia/Tokyo' })

onMounted(fetchInstrument)
</script>

<template>
  <MainLayout>
    <v-skeleton-loader v-if="loading" type="card" />

    <template v-else-if="instrument">
      <DetailHeader
        back-to="/instruments"
        back-label="装置・計器"
        kind="計器"
        :title="instrument.tag_number"
        :subtitle="`${instrument.equipment?.name ?? ''} ／ ${instrument.equipment?.site?.name ?? ''}`"
      >
        <template #actions>
          <v-btn v-if="canManageEquipment" variant="outlined" prepend-icon="mdi-pencil" @click="openEditInstrument">編集</v-btn>
        </template>
      </DetailHeader>
      <!-- 概要: 常に見える基本情報 -->
      <v-card class="mb-4 pk-summary" data-testid="detail-summary">
        <v-card-text>
          <dl class="pk-summary__grid">
            <div><dt>種別</dt><dd>{{ instrument.instrument_type }}</dd></div>
            <div><dt>サービス</dt><dd>{{ instrument.service?.name || '—' }}</dd></div>
            <div><dt>ラインクラス</dt><dd>{{ instrument.line_class?.code || '—' }}</dd></div>
            <div><dt>設置場所</dt><dd>{{ instrument.location || '—' }}</dd></div>
            <div v-if="instrument.seal_fluid"><dt>シール液</dt><dd>{{ instrument.seal_fluid }}</dd></div>
            <template v-if="instrument.service">
              <div><dt>温度</dt><dd>{{ instrument.service.temperature }}</dd></div>
              <div><dt>圧力</dt><dd>{{ instrument.service.pressure }}</dd></div>
              <div>
                <dt>危険性</dt>
                <dd>
                  <v-chip :color="instrument.service.hazard_level === 'high' ? 'error' : instrument.service.hazard_level === 'medium' ? 'warning' : 'success'" size="small" label variant="tonal">
                    {{ { high: '高', medium: '中', low: '低' }[instrument.service.hazard_level as string] }}
                  </v-chip>
                </dd>
              </div>
            </template>
            <div v-if="instrument.notes" class="pk-summary__wide"><dt>備考</dt><dd style="white-space: pre-wrap">{{ instrument.notes }}</dd></div>
            <div class="pk-summary__wide" data-testid="diagnostic-current">
              <dt>機器の診断（NAMUR NE 107）</dt>
              <dd class="d-flex flex-wrap align-center ga-2">
                <DiagnosticChip :status="instrument.diagnostic_status" />
                <span v-if="instrument.diagnostic_status" class="text-body-2 text-medium-emphasis">
                  {{ formatDateTime(instrument.diagnostic_since) }} から ／ 最後に受け取った日時 {{ formatDateTime(instrument.diagnostic_received_at) }}
                </span>
                <span v-if="instrument.diagnostic_status && instrument.diagnostic_status !== 'good'" class="text-body-2">
                  — {{ DIAGNOSTIC_STATUS[instrument.diagnostic_status as keyof typeof DIAGNOSTIC_STATUS].hint }}
                </span>
              </dd>
            </div>
            <div class="pk-summary__wide" data-testid="calibration-conditions">
              <dt>校正の条件</dt>
              <dd>
                <template v-if="instrument.calibratable">
                  {{ Number(instrument.range_lower) }}〜{{ Number(instrument.range_upper) }} {{ instrument.range_unit }}、許容差 ±{{ Number(instrument.tolerance_percent) }}%スパン（{{ TOLERANCE_BASIS_LABEL[instrument.tolerance_basis] ?? '出所未設定' }}）
                  <template v-if="instrument.calibration_kind === 'transmitter'">
                    、出力 {{ CHARACTERISTIC_LABEL[instrument.output_characteristic] }}・DCS {{ CHARACTERISTIC_LABEL[instrument.dcs_characteristic] }}
                  </template>
                </template>
                <span v-else class="text-medium-emphasis">未設定（編集で校正範囲と許容差を設定すると、点検で5点校正を記録できます）</span>
                <v-chip v-if="instrument.telemetry" size="small" label color="indigo" variant="tonal" class="ml-2">テレメータ計器</v-chip>
                <v-chip v-if="instrument.custody_transfer" size="small" label color="brown" variant="tonal" class="ml-2">取引用</v-chip>
              </dd>
            </div>
            <div v-if="instrument.troubleshooting_checks?.length" class="pk-summary__wide" data-testid="troubleshooting-checks">
              <dt>一次点検の定型項目（参考。手順書・保全基準の代わりではありません）</dt>
              <dd>
                <ul class="ml-5">
                  <li v-for="c in instrument.troubleshooting_checks" :key="c">{{ c }}</li>
                </ul>
              </dd>
            </div>
          </dl>
          <InterlockChips :instrument-id="instrument.id" class="mt-3" />
        </v-card-text>
      </v-card>

      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="troubles">トラブル履歴</v-tab>
        <v-tab value="inspections">点検履歴</v-tab>
        <v-tab v-if="instrument.calibratable || calibrationHistory.length" value="calibration">校正の傾向</v-tab>
        <v-tab v-if="diagnostics.length" value="diagnostics">機器の診断</v-tab>
        <v-tab value="history">変更履歴</v-tab>
      </v-tabs>

      <v-window v-model="tab">
        <v-window-item value="troubles">
          <InstrumentHistoryList kind="troubles" :instrument-id="instrument.id" />
        </v-window-item>

        <v-window-item value="inspections">
          <InstrumentHistoryList kind="inspections" :instrument-id="instrument.id" />
        </v-window-item>

        <v-window-item value="calibration" data-testid="calibration-trend">
          <p v-if="!calibrationHistory.length" class="text-body-2 text-medium-emphasis ml-4">5点校正の記録はまだありません。</p>
          <template v-else>
            <p class="text-body-2 mb-2">
              調整前（as found）の最大誤差の推移です。前回の校正からどれだけずれたかを表し、ずれが年々大きくなる計器は周期の短縮や原因の調査を、
              調整の要らない状態が続く計器は周期の延長を検討する材料になります。
            </p>
            <CalibrationTrendChart :rows="calibrationHistory" class="mb-2" />
            <p class="text-caption text-medium-emphasis mb-4">●調整前（赤は不合格） ／ ○調整後（調整した回だけ） ／ 点線は許容差</p>
            <v-table density="compact">
              <thead>
                <tr class="text-no-wrap">
                  <th>点検日</th>
                  <th>調整前の最大誤差</th>
                  <th>調整前の結果</th>
                  <th>調整</th>
                  <th>調整後の最大誤差</th>
                  <th>ヒステリシス（最大）</th>
                  <th>許容差</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in calibrationRowsNewestFirst" :key="row.inspection_id" style="cursor: pointer" @click="router.push(`/inspections/${row.inspection_id}`)">
                  <td class="text-no-wrap">{{ formatDate(row.inspected_at) }}</td>
                  <td>{{ formatError(row.as_found.max_error) }}</td>
                  <td><v-chip :color="STAGE_RESULT_COLOR[row.as_found.result]" size="x-small" label variant="tonal">{{ STAGE_RESULT_LABEL[row.as_found.result] }}</v-chip></td>
                  <td>{{ row.adjusted ? 'あり' : 'なし' }}</td>
                  <td>{{ row.as_left ? formatError(row.as_left.max_error) : '—' }}</td>
                  <td>{{ formatError(row.as_left?.max_hysteresis ?? row.as_found.max_hysteresis) }}</td>
                  <td>±{{ row.tolerance_percent }}%</td>
                </tr>
              </tbody>
            </v-table>
          </template>
        </v-window-item>

        <v-window-item value="diagnostics" data-testid="diagnostic-history">
          <p class="text-body-2 mb-2">機器管理システムから受け取った、機器の自己診断の状態が変わった記録です（新しい順に20件）。同じ状態を受け取り続けても、記録は増えません。</p>
          <v-table density="compact">
            <thead>
              <tr class="text-no-wrap"><th>発生日時</th><th>状態</th><th>コード</th><th>内容</th><th>送ってきた連携</th></tr>
            </thead>
            <tbody>
              <tr v-for="d in diagnostics" :key="d.id">
                <td class="text-no-wrap">{{ formatDateTime(d.occurred_at) }}</td>
                <td><DiagnosticChip :status="d.status" size="x-small" /></td>
                <td class="text-no-wrap">{{ d.code ?? '—' }}</td>
                <td>{{ d.message ?? '—' }}</td>
                <td class="text-no-wrap">{{ d.source ?? '—' }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-window-item>

        <v-window-item value="history">
          <ResourceHistory auditable-type="Instrument" :auditable-id="instrument.id" />
        </v-window-item>
      </v-window>
    </template>

    <!-- 計器編集ダイアログ -->
    <v-dialog v-model="editDialog" max-width="720" scrollable>
      <v-card>
        <v-card-title>計器編集</v-card-title>
        <v-card-text>
          <v-alert v-if="editErrors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in editErrors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select v-model="editForm.equipment_id" :items="equipments" item-title="name" item-value="id" label="設備" class="mb-2" />
          <v-text-field v-model="editForm.tag_number" label="タグナンバー" class="mb-2" />
          <v-text-field v-model="editForm.instrument_type" label="種別" class="mb-2" />
          <v-select v-model="editForm.service_id" :items="services" item-title="name" item-value="id" label="サービス・流体" clearable class="mb-2" />
          <v-select v-model="editForm.line_class_id" :items="lineClasses" item-title="code" item-value="id" label="ラインクラス" clearable class="mb-2" />
          <v-text-field v-model="editForm.location" label="設置場所" class="mb-2" />
          <v-text-field v-model="editForm.seal_fluid" label="シール液（任意。ダイアフラムシール式などで使用）" class="mb-2" />
          <v-textarea v-model="editForm.notes" label="備考" rows="2" />
          <InstrumentCalibrationFields v-model="calibrationForm" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="editDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveInstrument">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>
