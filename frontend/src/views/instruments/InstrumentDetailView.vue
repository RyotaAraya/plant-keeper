<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'
import InstrumentCalibrationFields from '@/components/InstrumentCalibrationFields.vue'
import InstrumentHistoryList from '@/components/InstrumentHistoryList.vue'
import ResourceHistory from '@/components/ResourceHistory.vue'
import {
  CHARACTERISTIC_LABEL,
  TOLERANCE_BASIS_LABEL,
  calibrationFieldsFrom,
  calibrationFieldsPayload,
  emptyCalibrationFields,
  type CalibrationFields,
} from '@/utils/calibration'

const route = useRoute()
const router = useRouter()
const { canManageEquipment } = usePermissions()

const instrument = ref<any>(null)
const loading = ref(false)
const tab = ref('info')

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

onMounted(fetchInstrument)
</script>

<template>
  <MainLayout>
    <v-btn variant="text" prepend-icon="mdi-arrow-left" class="mb-2" @click="router.push('/instruments')">
      計器一覧に戻る
    </v-btn>

    <v-skeleton-loader v-if="loading" type="card" />

    <template v-else-if="instrument">
      <v-card class="mb-4">
        <v-card-title class="d-flex align-center">
          {{ instrument.tag_number }}
          <v-spacer />
          <v-btn v-if="canManageEquipment" variant="outlined" size="small" prepend-icon="mdi-pencil" @click="openEditInstrument">編集</v-btn>
        </v-card-title>
        <v-card-subtitle>
          {{ instrument.equipment?.name }} / {{ instrument.equipment?.site?.name }}
        </v-card-subtitle>
        <v-card-text>
          <v-row>
            <v-col cols="12" md="3"><strong>種別:</strong> {{ instrument.instrument_type }}</v-col>
            <v-col cols="12" md="3"><strong>サービス:</strong> {{ instrument.service?.name || '—' }}</v-col>
            <v-col cols="12" md="3"><strong>ラインクラス:</strong> {{ instrument.line_class?.code || '—' }}</v-col>
            <v-col cols="12" md="3"><strong>設置場所:</strong> {{ instrument.location || '—' }}</v-col>
            <v-col v-if="instrument.seal_fluid" cols="12" md="3"><strong>シール液:</strong> {{ instrument.seal_fluid }}</v-col>
          </v-row>
          <v-row v-if="instrument.service" class="mt-2">
            <v-col cols="12" md="3"><strong>温度:</strong> {{ instrument.service.temperature }}</v-col>
            <v-col cols="12" md="3"><strong>圧力:</strong> {{ instrument.service.pressure }}</v-col>
            <v-col cols="12" md="3">
              <strong>危険性:</strong>
              <v-chip :color="instrument.service.hazard_level === 'high' ? 'error' : instrument.service.hazard_level === 'medium' ? 'warning' : 'success'" size="small">
                {{ { high: '高', medium: '中', low: '低' }[instrument.service.hazard_level as string] }}
              </v-chip>
            </v-col>
          </v-row>
          <p v-if="instrument.notes" class="mt-3"><strong>備考:</strong> {{ instrument.notes }}</p>
          <div v-if="instrument.troubleshooting_checks?.length" class="mt-3" data-testid="troubleshooting-checks">
            <strong>一次点検の定型項目（参考。手順書・保全基準の代わりではありません）:</strong>
            <ul class="ml-5">
              <li v-for="c in instrument.troubleshooting_checks" :key="c">{{ c }}</li>
            </ul>
          </div>
          <div class="mt-3" data-testid="calibration-conditions">
            <strong>校正の条件:</strong>
            <template v-if="instrument.calibratable">
              {{ Number(instrument.range_lower) }}〜{{ Number(instrument.range_upper) }} {{ instrument.range_unit }}、許容差 ±{{ Number(instrument.tolerance_percent) }}%スパン（{{ TOLERANCE_BASIS_LABEL[instrument.tolerance_basis] ?? '出所未設定' }}）
              <template v-if="instrument.calibration_kind === 'transmitter'">
                、出力 {{ CHARACTERISTIC_LABEL[instrument.output_characteristic] }}・DCS {{ CHARACTERISTIC_LABEL[instrument.dcs_characteristic] }}
              </template>
            </template>
            <span v-else class="text-medium-emphasis">未設定（編集で校正範囲と許容差を設定すると、点検で5点校正を記録できます）</span>
            <v-chip v-if="instrument.telemetry" size="small" label color="indigo" variant="tonal" class="ml-2">テレメータ計器</v-chip>
            <v-chip v-if="instrument.custody_transfer" size="small" label color="brown" variant="tonal" class="ml-2">取引用</v-chip>
          </div>
        </v-card-text>
      </v-card>

      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="troubles">トラブル履歴</v-tab>
        <v-tab value="inspections">点検履歴</v-tab>
        <v-tab value="history">変更履歴</v-tab>
      </v-tabs>

      <v-window v-model="tab">
        <v-window-item value="troubles">
          <InstrumentHistoryList kind="troubles" :instrument-id="instrument.id" />
        </v-window-item>

        <v-window-item value="inspections">
          <InstrumentHistoryList kind="inspections" :instrument-id="instrument.id" />
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
