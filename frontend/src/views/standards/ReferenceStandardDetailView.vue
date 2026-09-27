<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import CalibrationStateChip from '@/components/CalibrationStateChip.vue'
import DetailHeader from '@/components/layout/DetailHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import ReferenceStandardFormDialog from '@/components/ReferenceStandardFormDialog.vue'
import ResourceHistory from '@/components/ResourceHistory.vue'
import { usePermissions } from '@/composables/usePermissions'
import { todayForInput } from '@/utils/datetime'
import { intervalLabel } from '@/utils/interval'
import {
  CALIBRATION_RESULT_LABEL,
  CATEGORY_LABEL,
  DEFAULT_INTERVAL_DAYS,
  STATUS_COLOR,
  STATUS_LABEL,
  addDays,
} from '@/utils/referenceStandard'

const route = useRoute()
const router = useRouter()
const { canManageReferenceStandard } = usePermissions()

const standard = ref<any>(null)
const loading = ref(false)
const tab = ref('calibrations')

async function fetchStandard() {
  loading.value = true
  try {
    const res = await api.get(`/reference_standards/${route.params.id}`)
    standard.value = res.data.data
  } finally {
    loading.value = false
  }
}

// --- 編集（ダイアログは一覧と共通） ---
const editDialog = ref(false)

// --- 校正の記録 ---
const calibrationDialog = ref(false)
const calibrationErrors = ref<string[]>([])
const calibrationForm = ref({ performed_on: todayForInput(), performed_by: '', certificate_number: '', result: 'pass', traceable: true, valid_until: '', notes: '' })
// 有効期限は、実施日から標準の周期（1年）先を初期値にする。手で直したら、実施日を変えても上書きしない
const validUntilEdited = ref(false)

watch(() => calibrationForm.value.performed_on, (date) => {
  if (!validUntilEdited.value && date) calibrationForm.value.valid_until = addDays(date, DEFAULT_INTERVAL_DAYS)
})

function openCalibrationDialog() {
  const last = standard.value.calibrations[0]
  validUntilEdited.value = false
  calibrationForm.value = {
    performed_on: todayForInput(), performed_by: last?.performed_by ?? '', certificate_number: '', result: 'pass',
    traceable: last?.traceable ?? true, valid_until: addDays(todayForInput(), DEFAULT_INTERVAL_DAYS), notes: '',
  }
  calibrationErrors.value = []
  calibrationDialog.value = true
}

async function saveCalibration() {
  calibrationErrors.value = []
  try {
    await api.post(`/reference_standards/${standard.value.id}/calibrations`, { calibration: calibrationForm.value })
    calibrationDialog.value = false
    await fetchStandard()
  } catch (e: any) {
    calibrationErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

const inspectionStatusLabel: Record<string, string> = { draft: '下書き', submitted: '提出済', approval_requested: '承認依頼中', approved: '承認済' }
const preCheckLabel = (v: boolean | null) => (v === null ? '未確認' : v ? 'OK' : 'NG')
const preCheckColor = (v: boolean | null) => (v === null ? 'grey' : v ? 'success' : 'error')

// 最新の校正が不合格のとき、前回の合格した校正以降に使った点検は、影響を確認する
const isAffected = (use: any) => !!standard.value?.impact && (!standard.value.impact.since || use.inspected_at.slice(0, 10) >= standard.value.impact.since)
const planDueColor = (plan: any) => (plan.overdue ? 'error' : plan.days_until_due <= 30 ? 'warning' : 'success')
const canRecord = computed(() => canManageReferenceStandard.value && !!standard.value)

onMounted(async () => {
  await fetchStandard()
  // 点検計画の「校正を記録」から来たときは、校正の記録ダイアログを開く
  if (route.query.record === '1' && canRecord.value) openCalibrationDialog()
})
</script>

<template>
  <MainLayout>
    <v-skeleton-loader v-if="loading && !standard" type="card" />

    <template v-else-if="standard">
      <DetailHeader
        back-to="/reference-standards"
        back-label="基準器"
        kind="基準器"
        :title="standard.name"
        :subtitle="`${standard.management_number} ・ ${standard.site?.name ?? ''} ／ ${CATEGORY_LABEL[standard.category]}`"
      >
        <template #status>
          <StatusChip :label="STATUS_LABEL[standard.status]" :color="STATUS_COLOR[standard.status]" />
          <CalibrationStateChip :state="standard.calibration_state" :next-due-on="standard.next_due_on" data-testid="calibration-state" />
        </template>
        <template #actions>
          <v-btn v-if="canRecord" color="primary" prepend-icon="mdi-certificate-outline" @click="openCalibrationDialog">校正を記録</v-btn>
          <v-btn v-if="canRecord" variant="outlined" prepend-icon="mdi-pencil" @click="editDialog = true">編集</v-btn>
        </template>
      </DetailHeader>
      <v-card class="mb-4" data-testid="detail-summary">
        <v-card-text>
          <v-row>
            <v-col cols="6" md="3"><strong>型式:</strong> {{ standard.model_number || '—' }}</v-col>
            <v-col cols="6" md="3"><strong>製造番号:</strong> {{ standard.serial_number || '—' }}</v-col>
            <v-col cols="6" md="3"><strong>測定範囲:</strong> {{ standard.measuring_range || '—' }}</v-col>
            <v-col cols="6" md="3"><strong>精度:</strong> {{ standard.accuracy || '—' }}</v-col>
            <v-col cols="12" md="6"><strong>保管場所:</strong> {{ standard.location || '—' }}</v-col>
          </v-row>
          <p v-if="standard.notes" class="mt-2"><strong>備考:</strong> {{ standard.notes }}</p>
        </v-card-text>
      </v-card>

      <v-alert v-if="standard.impact" type="error" variant="tonal" class="mb-4" data-testid="calibration-impact">
        最新の校正が不合格です。{{ standard.impact.since ? `前回の合格した校正（${standard.impact.since}）以降に` : '' }}この基準器を使った点検が
        <strong>{{ standard.impact.count }}件</strong>あります。使った点検（「使った点検」タブの「影響あり」）の校正結果を確認してください。
      </v-alert>

      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="calibrations">校正の履歴</v-tab>
        <v-tab value="inspections">使った点検</v-tab>
        <v-tab value="plans">点検計画</v-tab>
        <v-tab value="history">変更履歴</v-tab>
      </v-tabs>

      <v-window v-model="tab">
        <v-window-item value="calibrations">
          <v-table density="compact">
            <thead>
              <tr>
                <th>実施日</th>
                <th>校正した機関</th>
                <th>証明書番号</th>
                <th>結果</th>
                <th>トレーサビリティ</th>
                <th>有効期限</th>
                <th>備考</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!standard.calibrations.length">
                <td colspan="7" class="text-center text-grey py-4">校正の記録はありません</td>
              </tr>
              <tr v-for="c in standard.calibrations" :key="c.id">
                <td class="text-no-wrap">{{ c.performed_on }}</td>
                <td>{{ c.performed_by }}</td>
                <td>{{ c.certificate_number || '—' }}</td>
                <td><v-chip :color="c.result === 'pass' ? 'success' : 'error'" size="x-small" label variant="tonal">{{ CALIBRATION_RESULT_LABEL[c.result] }}</v-chip></td>
                <td>{{ c.traceable ? 'あり' : 'なし' }}</td>
                <td class="text-no-wrap">{{ c.valid_until }}</td>
                <td>{{ c.notes || '' }}</td>
              </tr>
            </tbody>
          </v-table>
        </v-window-item>

        <v-window-item value="inspections">
          <v-table density="compact">
            <thead>
              <tr>
                <th>点検日</th>
                <th>設備</th>
                <th>計器</th>
                <th>ステータス</th>
                <th>使用前の1点チェック</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <tr v-if="!standard.inspections_using.length">
                <td colspan="6" class="text-center text-grey py-4">この基準器を使った点検はありません</td>
              </tr>
              <tr v-for="use in standard.inspections_using" :key="use.inspection_id" style="cursor: pointer" @click="router.push(`/inspections/${use.inspection_id}`)">
                <td class="text-no-wrap">{{ use.inspected_at?.slice(0, 10) }}</td>
                <td>{{ use.equipment?.name }}</td>
                <td>{{ use.instrument?.tag_number || '—' }}</td>
                <td>{{ inspectionStatusLabel[use.status] || use.status }}</td>
                <td>
                  <v-chip :color="preCheckColor(use.pre_check_passed)" size="x-small" label variant="tonal">{{ preCheckLabel(use.pre_check_passed) }}</v-chip>
                  <span v-if="use.pre_check_note" class="ml-2 text-caption">{{ use.pre_check_note }}</span>
                </td>
                <td><v-chip v-if="isAffected(use)" color="error" size="x-small" label>影響あり</v-chip></td>
              </tr>
            </tbody>
          </v-table>
        </v-window-item>

        <v-window-item value="plans">
          <v-list v-if="standard.inspection_plans.length">
            <v-list-item v-for="plan in standard.inspection_plans" :key="plan.id" :title="plan.name" :subtitle="`${intervalLabel(plan.interval_days)}ごと${plan.is_active ? '' : '（停止中）'}`">
              <template #append>
                <v-chip :color="planDueColor(plan)" size="small" label variant="tonal">次回 {{ plan.next_due_on }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
          <p v-else class="text-body-2 text-grey ml-4">点検計画はありません</p>
        </v-window-item>

        <v-window-item value="history">
          <ResourceHistory auditable-type="ReferenceStandard" :auditable-id="standard.id" />
        </v-window-item>
      </v-window>
    </template>

    <ReferenceStandardFormDialog v-model="editDialog" :standard="standard" @saved="fetchStandard" />

    <v-dialog v-model="calibrationDialog" max-width="560" scrollable>
      <v-card>
        <v-card-title>校正を記録</v-card-title>
        <v-card-text>
          <div class="text-caption text-medium-emphasis mb-3">メーカーに校正を出したときの、実施日・校正した機関・証明書番号などを記録します。記録すると、年次校正の点検計画の次回期限が有効期限に進みます。</div>
          <v-alert v-if="calibrationErrors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in calibrationErrors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="calibrationForm.performed_on" label="実施日 *" type="date" class="mb-2" />
          <v-text-field v-model="calibrationForm.performed_by" label="校正した機関（メーカー）*" class="mb-2" />
          <v-text-field v-model="calibrationForm.certificate_number" label="証明書番号" class="mb-2" />
          <v-select
            v-model="calibrationForm.result"
            :items="[{ title: '合格（メーカー点検済み）', value: 'pass' }, { title: '不合格', value: 'fail' }]"
            item-title="title"
            item-value="value"
            label="結果"
            class="mb-2"
          />
          <v-switch v-model="calibrationForm.traceable" label="トレーサビリティあり（校正証明書に、上位の標準までの連鎖が示されている）" color="primary" density="compact" hide-details class="mb-2" />
          <v-text-field v-model="calibrationForm.valid_until" label="有効期限 *" type="date" hint="実施日の1年後が初期値です" persistent-hint class="mb-2" @update:model-value="validUntilEdited = true" />
          <v-textarea v-model="calibrationForm.notes" label="備考" rows="2" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="calibrationDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveCalibration">記録</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>
