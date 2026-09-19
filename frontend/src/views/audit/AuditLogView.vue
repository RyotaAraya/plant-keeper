<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { useAuthStore } from '@/stores/auth'
import { downloadCsv } from '@/utils/csv'
import { monthsAgoForInput, todayForInput } from '@/utils/datetime'
import { latestGuard } from '@/utils/latestGuard'

const authStore = useAuthStore()

const logs = ref<any[]>([])
const loading = ref(false)
const exporting = ref(false)
const totalCount = ref(0)
const apiError = ref<string | null>(null)

// 一覧の表示は新しい順に最大1000件。CSV出力は条件に合う全件
const LIST_LIMIT = 1000

// 通常業務では自拠点の変更だけ見ればよいため、自分の所属拠点を初期値にする（空は全拠点）。期間は直近1か月
const filters = ref({
  site_ids: (authStore.user?.site_id ? [authStore.user.site_id] : []) as number[],
  from: monthsAgoForInput(1),
  to: todayForInput(),
  action: null as string | null,
  auditable_type: null as string | null,
})

const headers = [
  { title: '日時', key: 'performed_at', width: '160px' },
  { title: 'ユーザ', key: 'user.name', width: '130px' },
  { title: '操作', key: 'action', width: '90px' },
  { title: '対象', key: 'auditable_type', width: '120px' },
  { title: '対象ID', key: 'auditable_id', width: '80px' },
  { title: '拠点', key: 'site.name', width: '120px' },
  { title: '変更内容', key: 'changes_json' },
  { title: 'IP', key: 'ip_address', width: '130px' },
]

const actionLabel: Record<string, string> = {
  create: '作成', update: '更新', delete: '削除', login: 'ログイン', logout: 'ログアウト', approval_request: '承認依頼'
}
const actionColor: Record<string, string> = {
  create: 'success', update: 'info', delete: 'error', login: 'grey', logout: 'grey', approval_request: 'warning'
}
const actionOptions = Object.entries(actionLabel).map(([value, title]) => ({ title, value }))

// 記録される対象の種類。画面には日本語の呼び名だけを出す（クラス名は出さない）
const typeLabel: Record<string, string> = {
  Site: '拠点', Department: '部署', DepartmentHistory: '部署の所属', User: 'ユーザ',
  Equipment: '設備', EquipmentAssignment: '設備担当', Instrument: '計器',
  InspectionPlan: '点検計画', Inspection: '点検', InspectionItem: '点検項目', ChecklistTemplate: 'チェックリスト',
  Trouble: 'トラブル', TroubleResponse: 'トラブル対応',
  ScheduledMaintenance: '定期整備', MaintenanceAssignment: '整備担当',
  Material: '資材', Manufacturer: 'メーカー', Warehouse: '倉庫', Stock: '在庫', StockTransaction: '在庫操作',
  Order: '発注', Repair: '修理', Service: '流体', LineClass: 'ラインクラス',
}
const typeOptions = Object.entries(typeLabel).map(([value, title]) => ({ title, value }))

const fetchLogsGuard = latestGuard()

function buildParams() {
  const params: any = {}
  if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
  if (filters.value.from) params.from = filters.value.from
  if (filters.value.to) params.to = filters.value.to
  if (filters.value.action) params.log_action = filters.value.action
  if (filters.value.auditable_type) params.auditable_type = filters.value.auditable_type
  return params
}

async function fetchLogs() {
  const isLatest = fetchLogsGuard()
  loading.value = true
  apiError.value = null
  try {
    const res = await api.get('/audit_logs', { params: { ...buildParams(), per_page: LIST_LIMIT } })
    if (!isLatest()) return
    logs.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } catch (e: any) {
    if (!isLatest()) return
    apiError.value = e.response?.data?.error || e.response?.data?.errors?.join('、') || 'ログの取得に失敗しました'
    logs.value = []
    totalCount.value = 0
  } finally {
    if (isLatest()) loading.value = false
  }
}

const DATE_TIME_FORMAT: Intl.DateTimeFormatOptions = {
  timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', DATE_TIME_FORMAT)
}

// changes_json の各エントリを "フィールド: 旧 → 新" 形式に整形
function parseChanges(changes: any): { key: string; from: string; to: string }[] {
  if (!changes || typeof changes !== 'object') return []
  return Object.entries(changes)
    .filter(([k]) => !['id', 'created_at', 'updated_at'].includes(k))
    .map(([k, v]) => {
      const arr = Array.isArray(v) ? v : [null, v]
      return { key: k, from: arr[0] != null ? String(arr[0]) : '—', to: arr[1] != null ? String(arr[1]) : '—' }
    })
}

function hasChanges(changes: any): boolean {
  return parseChanges(changes).length > 0
}

// 条件に合う全件をページごとに取得してCSVにする（画面の表示は先頭1000件まで）
async function exportCsv() {
  exporting.value = true
  apiError.value = null
  try {
    const all: any[] = []
    for (let page = 1; ; page++) {
      const res = await api.get('/audit_logs', { params: { ...buildParams(), per_page: LIST_LIMIT, page } })
      all.push(...res.data.data)
      if (!res.data.data.length || all.length >= res.data.meta.total_count) break
    }
    const rows = [
      ['日時', 'ユーザ', '操作', '対象', '対象ID', '拠点', '変更内容', 'IP'],
      ...all.map((log) => [
        formatDate(log.performed_at),
        log.user?.name ?? '',
        actionLabel[log.action] ?? log.action,
        typeLabel[log.auditable_type] ?? log.auditable_type,
        log.auditable_id,
        log.site?.name ?? '',
        parseChanges(log.changes_json).map((c) => `${c.key}: ${c.from} → ${c.to}`).join('\n'),
        log.ip_address ?? '',
      ]),
    ]
    const period = [filters.value.from, filters.value.to].filter(Boolean).join('_') || '全期間'
    downloadCsv(`監査ログ_${period}.csv`, rows)
  } catch (e: any) {
    apiError.value = e.response?.data?.error || e.response?.data?.errors?.join('、') || 'CSVの出力に失敗しました'
  } finally {
    exporting.value = false
  }
}

onMounted(fetchLogs)
watch(filters, fetchLogs, { deep: true })
</script>

<template>
  <MainLayout>
    <PageHeader title="監査ログ" description="誰がいつ何を変更したかの記録です。期間・拠点などで絞り込み、CSVで出力できます。">
      <v-btn variant="outlined" prepend-icon="mdi-download" :loading="exporting" @click="exportCsv">CSV出力</v-btn>
    </PageHeader>

    <div class="pk-filters">
      <SiteScopeTag v-model="filters.site_ids" />
      <v-divider vertical class="pk-scope-divider" />
      <v-text-field
        v-model="filters.from"
        type="date"
        label="開始日"
        density="compact"
        hide-details
        style="max-width: 170px"
      />
      <span class="text-medium-emphasis" aria-hidden="true">〜</span>
      <v-text-field
        v-model="filters.to"
        type="date"
        label="終了日"
        density="compact"
        hide-details
        style="max-width: 170px"
      />
      <v-select
        v-model="filters.action"
        :items="actionOptions"
        item-title="title"
        item-value="value"
        label="操作"
        clearable
        density="compact"
        hide-details
        style="max-width: 160px"
      />
      <v-select
        v-model="filters.auditable_type"
        :items="typeOptions"
        item-title="title"
        item-value="value"
        label="対象"
        clearable
        density="compact"
        hide-details
        style="max-width: 200px"
      />
    </div>

    <v-alert v-if="apiError" type="error" density="compact" class="mb-4">{{ apiError }}</v-alert>
    <v-alert v-else-if="totalCount > logs.length" type="info" variant="tonal" density="compact" class="mb-4">
      条件に合う記録は{{ totalCount }}件あります。新しい順に{{ logs.length }}件を表示しています。期間などで絞り込むか、CSVで全件を出力してください。
    </v-alert>

    <v-data-table
      :headers="headers"
      :items="logs"
      :loading="loading"
      density="compact"
    >
      <template #item.performed_at="{ item }">
        {{ formatDate(item.performed_at) }}
      </template>
      <template #item.action="{ item }">
        <v-chip :color="actionColor[item.action] || 'grey'" size="x-small">
          {{ actionLabel[item.action] || item.action }}
        </v-chip>
      </template>
      <template #item.auditable_type="{ item }">
        {{ typeLabel[item.auditable_type] || item.auditable_type }}
      </template>
      <template #item.changes_json="{ item }">
        <template v-if="hasChanges(item.changes_json)">
          <div v-for="c in parseChanges(item.changes_json)" :key="c.key" class="text-caption">
            <span class="text-grey">{{ c.key }}:</span>
            <span class="text-error mx-1">{{ c.from }}</span>
            <v-icon size="x-small">mdi-arrow-right</v-icon>
            <span class="text-success ml-1">{{ c.to }}</span>
          </div>
        </template>
        <span v-else class="text-caption text-grey">—</span>
      </template>
    </v-data-table>
  </MainLayout>
</template>
