<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import CalibrationTable from '@/components/CalibrationTable.vue'
import DetailHeader from '@/components/layout/DetailHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import { useAuthStore } from '@/stores/auth'
import { useDetailTab } from '@/composables/useDetailTab'
import { usePermissions } from '@/composables/usePermissions'
import { RESULT_COLOR, RESULT_LABEL, calibrationInputFrom } from '@/utils/calibration'
import { RESULT_COLOR as ITEM_RESULT_COLOR, RESULT_LABEL as ITEM_RESULT_LABEL, isJudgedType, limitStatus, limitsText, startsSection, type ItemResult } from '@/utils/checklistCriteria'
import { inspectionName, inspectionReturn, inspectionReturnLabel } from '@/utils/inspectionWorkflow'
import { coveredEquipments } from '@/utils/equipment'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { isAdmin, isManager, canApproveInspection } = usePermissions()
const inspection = ref<any>(null)
const loading = ref(true)
const actionError = ref('')
const returnTo = computed(() => inspectionReturn(route.query.return_to))

// バックエンドの InspectionPolicy#update? に対応（承認済みは誰も変更不可。作成者本人か管理者/マネージャーのみ）
const canEdit = computed(
  () =>
    !!inspection.value &&
    inspection.value.status !== 'approved' &&
    (isAdmin.value || isManager.value || authStore.user?.id === inspection.value.user_id)
)

const inspectionTypeLabel: Record<string, string> = {
  routine: '日常点検', periodic: '定期点検', telemetry: 'テレメトリ', operation_check: '運転チェック'
}

// 点検で見た設備。代表の設備が先頭（複数の設備をまとめて点検した記録は、2つ以上になる）
const inspectionEquipments = computed(() => coveredEquipments(inspection.value))

const defectItems = computed(() => {
  if (!inspection.value?.inspection_items) return []
  return inspection.value.inspection_items.filter((i: any) => i.has_defect)
})

// 詳細の中身は「概要 → タブ」（不具合・使用した基準器は、あるときだけ）
const tab = useDetailTab(() => [
  'items',
  ...(defectItems.value.length ? ['defects'] : []),
  ...(inspection.value?.inspection_reference_standards?.length ? ['standards'] : []),
])

async function fetchInspection() {
  loading.value = true
  try {
    const res = await api.get(`/inspections/${route.params.id}`)
    inspection.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function updateStatus(status: string) {
  actionError.value = ''
  try {
    await api.patch(`/inspections/${route.params.id}`, { inspection: { status } })
  } catch (e: any) {
    actionError.value = e.response?.data?.errors?.join('、') || e.response?.data?.error || '更新に失敗しました'
  }
  await fetchInspection()
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

onMounted(fetchInspection)
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="inspection">
      <DetailHeader
        :back-to="returnTo"
        :back-label="inspectionReturnLabel(returnTo)"
        kind="点検記録"
        :title="inspectionName(inspection)"
        :subtitle="`${inspection.equipment?.name ?? ''} ・ ${formatDate(inspection.inspected_at)}`"
      >
        <template #status><StatusChip kind="inspection" :value="inspection.status" /></template>
        <template #actions>
          <v-btn v-if="inspection.status === 'draft' && canEdit" variant="outlined" prepend-icon="mdi-pencil" :to="{ path: `/inspections/${inspection.id}/edit`, query: { return_to: returnTo } }">編集</v-btn>
          <v-btn v-if="inspection.status === 'draft' && canEdit" color="primary" @click="updateStatus('submitted')">提出</v-btn>
          <v-btn v-if="inspection.status === 'submitted' && canEdit" color="warning" @click="updateStatus('approval_requested')">承認依頼</v-btn>
          <v-btn v-if="inspection.status === 'approval_requested' && canApproveInspection" variant="outlined" @click="updateStatus('submitted')">差し戻し</v-btn>
          <v-btn v-if="inspection.status === 'approval_requested' && canApproveInspection" color="success" @click="updateStatus('approved')">承認</v-btn>
        </template>
      </DetailHeader>
      <v-alert v-if="actionError" type="error" variant="tonal" closable class="mb-4" @click:close="actionError = ''">{{ actionError }}</v-alert>

      <v-alert v-if="route.query.saved === inspection.status && ['draft', 'submitted'].includes(inspection.status)" type="success" variant="tonal" class="mb-4" role="status" data-testid="inspection-saved">
        {{ inspection.status === 'draft' ? '下書きを保存しました。入力は「編集」から再開できます。' : '点検を提出しました。' }}
        <v-btn variant="text" :to="returnTo">{{ inspectionReturnLabel(returnTo) }}に戻る</v-btn>
      </v-alert>
      <v-alert v-if="inspection.inspection_plan" type="info" variant="tonal" class="mb-4" data-testid="inspection-plan-context">
        <strong>{{ inspection.inspection_plan.name }}</strong> ／ 現在の次回期限 {{ inspection.inspection_plan.next_due_on }}
        <p>{{ inspection.status === 'draft' ? '下書き保存では計画の期限は更新しません。提出すると、実施日をもとに次回期限を更新します。' : 'この点検は計画にひもづいています。表示は計画の現在の期限です。' }}</p>
      </v-alert>
      <v-alert v-else-if="!inspection.maintenance_task" type="info" variant="tonal" class="mb-4">予定外の点検です。点検計画の期限は更新しません。</v-alert>
      <v-alert v-else type="info" variant="tonal" class="mb-4">
        定期整備の作業「{{ inspection.maintenance_task.title }}」の点検です。
        {{ inspection.status === 'draft' ? '提出すると作業が完了になります。' : '作業の状態は定期整備で確認できます。' }}
        <v-btn variant="text" :to="`/maintenances/${inspection.maintenance_task.scheduled_maintenance_id}`">定期整備の作業を開く</v-btn>
      </v-alert>

      <!-- 概要: 常に見える基本情報 -->
      <v-card class="mb-4 pk-summary" data-testid="detail-summary">
        <v-card-text>
          <dl class="pk-summary__grid">
            <div><dt>点検日時</dt><dd>{{ formatDate(inspection.inspected_at) }}</dd></div>
            <div><dt>種別</dt><dd>{{ inspectionTypeLabel[inspection.inspection_type] }}</dd></div>
            <div><dt>実施者</dt><dd>{{ inspection.user?.name }}</dd></div>
            <div>
              <dt>設備</dt>
              <dd>
                <div v-for="equipment in inspectionEquipments" :key="equipment.id" data-testid="inspection-equipment">
                  <router-link class="text-primary" :to="`/equipments/${equipment.id}`">{{ equipment.name }}</router-link>
                </div>
              </dd>
            </div>
            <div><dt>計器</dt><dd>{{ inspection.instrument?.tag_number || '—' }}</dd></div>
            <div><dt>部署</dt><dd>{{ inspection.department?.name }}</dd></div>
            <div><dt>テンプレート</dt><dd>{{ inspection.checklist_template?.name || '—' }}</dd></div>
            <div v-if="inspection.maintenance_task">
              <dt>定期整備の作業</dt>
              <dd>
                <router-link class="text-primary" data-testid="maintenance-task-link" :to="`/maintenances/${inspection.maintenance_task.scheduled_maintenance_id}`">
                  {{ inspection.maintenance_task.title }}
                </router-link>
              </dd>
            </div>
            <div v-if="inspection.import_source" class="pk-summary__wide" data-testid="import-source">
              <dt>取り込み元</dt>
              <dd>
                校正結果のファイル「{{ inspection.import_source.file_name }}」（{{ inspection.import_source.record_index }}件目）
                <span v-if="inspection.import_source.performed_by">・校正の実施者: {{ inspection.import_source.performed_by }}</span>
                <span v-if="inspection.import_source.calibrator?.model">・キャリブレータ: {{ [inspection.import_source.calibrator.model, inspection.import_source.calibrator.serial_number].filter(Boolean).join(' / ') }}</span>
              </dd>
            </div>
            <div v-if="inspection.notes" class="pk-summary__wide"><dt>備考</dt><dd style="white-space: pre-wrap">{{ inspection.notes }}</dd></div>
          </dl>
        </v-card-text>
      </v-card>

      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="items">点検項目（{{ inspection.inspection_items?.length ?? 0 }}）</v-tab>
        <v-tab v-if="defectItems.length" value="defects">不具合 → トラブル（{{ defectItems.length }}）</v-tab>
        <v-tab v-if="inspection.inspection_reference_standards?.length" value="standards">使用した基準器</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item v-if="inspection.inspection_reference_standards?.length" value="standards">
          <v-table density="compact" data-testid="reference-standards-used">
            <thead>
              <tr>
                <th>基準器</th>
                <th>点検日時点の校正</th>
                <th>使用前の1点チェック</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="link in inspection.inspection_reference_standards" :key="link.id">
                <td>
                  <a class="text-primary" style="cursor: pointer" @click="router.push(`/reference-standards/${link.reference_standard_id}`)">
                    {{ link.reference_standard?.management_number }} {{ link.reference_standard?.name }}
                  </a>
                </td>
                <td class="text-caption">
                  <template v-if="link.calibration_at_inspection">
                    {{ link.calibration_at_inspection.performed_on }} 実施・{{ link.calibration_at_inspection.performed_by }}・
                    {{ link.calibration_at_inspection.certificate_number || '証明書番号なし' }}・{{ link.calibration_at_inspection.valid_until }}まで有効・
                    トレーサビリティ{{ link.calibration_at_inspection.traceable ? 'あり' : 'なし' }}
                  </template>
                  <template v-else>—</template>
                </td>
                <td>
                  <v-chip :color="link.pre_check_passed === null ? 'grey' : link.pre_check_passed ? 'success' : 'error'" size="x-small" label variant="tonal">
                    {{ link.pre_check_passed === null ? '未確認' : link.pre_check_passed ? 'OK' : 'NG' }}
                  </v-chip>
                  <span v-if="link.pre_check_note" class="ml-2 text-caption">{{ link.pre_check_note }}</span>
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-window-item>

        <v-window-item value="items">
          <v-table density="compact">
            <thead>
              <tr>
                <th width="40">#</th>
                <th>項目・判定基準</th>
                <th width="180">記録</th>
                <th width="110">判定</th>
                <th width="120">計器</th>
              </tr>
            </thead>
            <tbody v-if="!inspection.inspection_items?.length">
              <tr>
                <td colspan="5" class="text-center text-grey py-4">
                  <template v-if="inspection.status === 'draft'">
                    点検項目が未入力です。
                    <router-link
                      class="text-primary"
                      :to="{ path: `/inspections/${inspection.id}/edit`, query: { return_to: returnTo } }"
                    >
                      編集画面
                    </router-link>から入力してください。
                  </template>
                  <template v-else>点検項目が未入力です。</template>
                </td>
              </tr>
            </tbody>
            <tbody v-else>
              <template v-for="(item, idx) in inspection.inspection_items" :key="item.id">
                <tr v-if="startsSection(inspection.inspection_items, Number(idx))" class="pk-detail-section">
                  <th colspan="5">{{ item.section }}</th>
                </tr>
                <tr :class="{ 'bg-red-lighten-5': item.has_defect }">
                  <td>{{ item.position }}</td>
                  <td class="py-2">
                    <div>{{ item.content }}</div>
                    <div v-if="item.criterion || limitsText(item)" class="text-caption text-medium-emphasis">
                      {{ item.criterion }}<span v-if="limitsText(item)" class="ml-2 text-no-wrap">（許容範囲 {{ limitsText(item) }}）</span>
                    </div>
                  </td>
                  <td>
                    <template v-if="item.item_type === 'measurement'">
                      <span :class="{ 'text-error font-weight-bold': ['below', 'above'].includes(limitStatus(item, item.measured_value) ?? '') }">
                        {{ item.measured_value ? `${item.measured_value}${item.unit ? ` ${item.unit}` : ''}` : '—' }}
                      </span>
                    </template>
                    <template v-else-if="item.item_type === 'calibration'">
                      <v-chip v-if="item.calibration_result" :color="RESULT_COLOR[item.calibration_result as keyof typeof RESULT_COLOR]" size="x-small" label>
                        {{ RESULT_LABEL[item.calibration_result as keyof typeof RESULT_LABEL] }}
                      </v-chip>
                      <template v-else>—</template>
                    </template>
                    <template v-else-if="item.item_type === 'check'">—</template>
                    <template v-else>
                      {{ item.text_value || '—' }}
                    </template>
                  </td>
                  <td>
                    <v-chip v-if="item.result" :color="ITEM_RESULT_COLOR[item.result as ItemResult]" size="small" label variant="tonal">
                      <v-icon v-if="item.result === 'defect'" start size="x-small">mdi-alert</v-icon>{{ item.result === 'na' ? '－（該当なし）' : ITEM_RESULT_LABEL[item.result as ItemResult] }}
                    </v-chip>
                    <span v-else-if="isJudgedType(item.item_type)" class="text-caption text-medium-emphasis">未判定</span>
                  </td>
                  <td>
                    <div>{{ item.instrument?.tag_number || '' }}</div>
                    <div v-if="item.equipment" class="text-caption text-medium-emphasis">{{ item.equipment.name }}</div>
                  </td>
                </tr>
                <tr v-if="item.item_type === 'calibration' && item.calibration_data">
                  <td />
                  <td colspan="4" class="py-2" style="overflow-x: auto">
                    <CalibrationTable readonly :model-value="calibrationInputFrom(item.calibration_data)" :snapshot="item.calibration_data.snapshot" />
                  </td>
                </tr>
              </template>
            </tbody>
          </v-table>
        </v-window-item>

        <v-window-item v-if="defectItems.length" value="defects">
          <v-list>
            <v-list-item
              v-for="item in defectItems"
              :key="item.id"
              :title="item.trouble?.title || `不具合（項目${item.position}）`"
              :subtitle="item.equipment ? `${item.equipment.name}: ${item.content}` : item.content"
              @click="item.trouble && router.push(`/troubles/${item.trouble.id}`)"
            >
              <template #prepend>
                <v-icon color="error">mdi-alert-circle</v-icon>
              </template>
              <template v-if="item.trouble" #append>
                <v-chip size="x-small" color="primary">トラブル #{{ item.trouble.id }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
        </v-window-item>
      </v-window>
    </template>
  </MainLayout>
</template>

<style scoped>
.pk-detail-section th { background: var(--pk-mist); color: var(--pk-ink) !important; font-weight: 700; font-size: .8125rem; }
</style>
