<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import FilterResetButton from '@/components/FilterResetButton.vue'
import FilterSelect from '@/components/FilterSelect.vue'
import InstrumentFilterChip from '@/components/InstrumentFilterChip.vue'
import StatusChip from '@/components/StatusChip.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { hasQueryConditions, useSavedFilters } from '@/composables/useSavedFilters'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { usePermissions } from '@/composables/usePermissions'
import { keepInSites, keepOneInSites, useSiteScope } from '@/composables/useSiteScope'
import { formatDate, nowForInput } from '@/utils/datetime'
import { idFromQuery, listFromQuery } from '@/utils/listQuery'
import { latestGuard } from '@/utils/latestGuard'

const route = useRoute()
const router = useRouter()
const { canCreateTrouble } = usePermissions()
const { initialSiteIds, savedSiteIds } = useSiteScope()

const troubles = ref<any[]>([])
const { equipments, departments, load: loadSiteOptions } = useSiteScopeOptions()
const loading = ref(false)
const totalCount = ref(0)
const dialog = ref(false)
const errors = ref<string[]>([])

const statusOptions = [
  { title: '未対応', value: 'open' },
  { title: '対応中', value: 'in_progress' },
  { title: '定修待ち', value: 'deferred' },
  { title: '完了', value: 'closed' },
]
const priorityOptions = [
  { title: '低', value: 'low' },
  { title: '中', value: 'medium' },
  { title: '高', value: 'high' },
  { title: '緊急', value: 'critical' },
]

type Filters = {
  site_ids: number[]
  q: string
  equipment_ids: number[]
  department_id: number | null
  statuses: string[]
  priorities: string[]
  // 計器の「すべて見る」から来たときだけの一時的な絞り込み（保存しない）
  instrument_id: number | null
}

const saved = useSavedFilters<Filters>('troubles', {
  site_ids: 'ids',
  q: { type: 'string' },
  equipment_ids: 'ids',
  department_id: 'id',
  statuses: { type: 'strings', values: statusOptions.map((o) => o.value) },
  priorities: { type: 'strings', values: priorityOptions.map((o) => o.value) },
}, { linkOnly: (): Record<string, string> => (filters.value.instrument_id ? { instrument_id: String(filters.value.instrument_id) } : {}) })

// 通常は既定（自拠点・完了を除くステータス）＋保存した条件。保存したステータスの全解除（空）は、全件の表示としてそのまま戻す。
// ほかの画面のリンクから検索条件付きで来たときは、保存した条件を混ぜず、その拠点・ステータス・優先度・部署・計器で開く。
// このときステータスを指定しなければ完了も含める（計器の「すべて見る」など）
function filtersForRoute(): Filters {
  if (hasQueryConditions(route.query)) {
    return {
      site_ids: initialSiteIds(route.query.site_ids),
      q: '',
      equipment_ids: [],
      department_id: idFromQuery(route.query.department_id),
      statuses: listFromQuery(route.query.status),
      priorities: listFromQuery(route.query.priority),
      instrument_id: idFromQuery(route.query.instrument_id),
    }
  }
  const stored = saved.load()
  return {
    q: '',
    equipment_ids: [],
    department_id: null,
    statuses: ['open', 'in_progress', 'deferred'],
    priorities: [],
    ...stored,
    site_ids: savedSiteIds(stored.site_ids),
    instrument_id: idFromQuery(route.query.instrument_id),
  }
}

const filters = ref<Filters>(filtersForRoute())
saved.hold(filters.value)

const form = ref({
  equipment_id: null as number | null,
  instrument_id: null as number | null,
  title: '',
  description: '',
  priority: 'medium',
  reported_at: nowForInput(),
})

const instruments = ref<any[]>([])

const headers = [
  { title: '優先度', key: 'priority', width: '70px' },
  { title: 'タイトル', key: 'title', minWidth: '300px' },
  { title: 'ステータス', key: 'status', width: '110px' },
  { title: '報告日', key: 'reported_at', width: '110px' },
  { title: '設備', key: 'equipment.name', width: '150px' },
  { title: '計器', key: 'instrument.tag_number', width: '90px' },
  { title: '担当者', key: 'assigned_to.name', width: '90px' },
  { title: '部署', key: 'department_display', width: '120px' },
]

const fetchTroublesGuard = latestGuard()

async function fetchTroubles() {
  const isLatest = fetchTroublesGuard()
  loading.value = true
  try {
    const params: any = { per_page: 1000 }
    if (filters.value.statuses.length) params.statuses = filters.value.statuses
    if (filters.value.priorities.length) params.priorities = filters.value.priorities
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.equipment_ids.length) params.equipment_ids = filters.value.equipment_ids
    if (filters.value.instrument_id) params.instrument_id = filters.value.instrument_id
    if (filters.value.department_id) params.department_id = filters.value.department_id
    if (filters.value.q) params.q = filters.value.q
    const res = await api.get('/troubles', { params })
    if (!isLatest()) return
    troubles.value = res.data.data
    totalCount.value = res.data.meta.total_count
  } finally {
    if (isLatest()) loading.value = false
  }
}

// 表示する拠点の設備・部署を取り直し、選択肢にない設備・部署の絞り込み（保存したあとに無効になったものなど）を外す。
// 取得に失敗したとき・取り直しが重なったときは、選択を外さない
async function loadOptions(siteIds: number[]) {
  if (!(await loadSiteOptions(siteIds).catch(() => false))) return
  const equipmentIds = keepInSites(filters.value.equipment_ids, equipments.value, siteIds)
  const departmentId = keepOneInSites(filters.value.department_id, departments.value, siteIds)
  if (equipmentIds.length !== filters.value.equipment_ids.length || departmentId !== filters.value.department_id) {
    filters.value = { ...filters.value, equipment_ids: equipmentIds, department_id: departmentId }
  }
}

// 拠点を変えたら、表示する拠点にない設備・部署の絞り込みは外す（1回の更新で、一覧の取得も1回で済む）
function changeSite(siteIds: number[]) {
  filters.value = {
    ...filters.value,
    site_ids: siteIds,
    equipment_ids: keepInSites(filters.value.equipment_ids, equipments.value, siteIds),
    department_id: keepOneInSites(filters.value.department_id, departments.value, siteIds),
  }
  void loadOptions(siteIds)
}

function applyRoute() {
  filters.value = filtersForRoute()
  saved.hold(filters.value)
  void loadOptions(filters.value.site_ids)
}

// 保存した条件とURLの検索条件を消し、既定（自拠点・完了を除くステータス）に戻す
// 表のページ（リセットで先頭に戻す）
const tablePage = ref(1)

function reset() {
  tablePage.value = 1
  saved.clear()
  if (!saved.clearQuery()) applyRoute()
}

async function fetchInstruments() {
  if (!form.value.equipment_id) { instruments.value = []; return }
  const res = await api.get('/instruments', { params: { equipment_id: form.value.equipment_id, per_page: 100 } })
  instruments.value = res.data.data
}

function openCreate() {
  form.value = {
    equipment_id: null,
    instrument_id: null,
    title: '',
    description: '',
    priority: 'medium',
    reported_at: nowForInput(),
  }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    await api.post('/troubles', { trouble: form.value })
    dialog.value = false
    await fetchTroubles()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

// 計器の一時的な絞り込みを外す（URL からも外し、ほかの条件はいまの値で保存する）
function clearInstrument() {
  filters.value = { ...filters.value, instrument_id: null }
  saved.save(filters.value, { force: true })
}

function goToDetail(row: any) {
  router.push(`/troubles/${row.id}`)
}

onMounted(() => {
  void loadOptions(filters.value.site_ids)
  void fetchTroubles()
})
watch(filters, (value) => {
  saved.save(value)
  void fetchTroubles()
}, { deep: true })

// 同じ一覧のままクエリだけが変わったとき（計器で絞り込み中に、サイドバーから開き直したときなど）は、
// 画面は使い回されるので、クエリの絞り込みに合わせ直す（クエリがなければ、既定＋保存した条件）
watch(() => route.query, (query) => {
  if (route.path !== '/troubles' || saved.isOwnReplace(query)) return
  applyRoute()
})
</script>

<template>
  <MainLayout>
    <PageHeader title="トラブル管理" description="設備の不具合・故障の報告と対応状況を記録します。点検で見つかった不具合も、トラブルとして自動で登録されます。">
      <v-btn v-if="canCreateTrouble" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規報告</v-btn>
    </PageHeader>

    <div class="pk-filters">
      <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
      <v-divider vertical class="pk-scope-divider" />
      <v-text-field
        v-model="filters.q"
        label="タイトル検索"
        prepend-inner-icon="mdi-magnify"
        clearable
        density="compact"
        hide-details
        style="max-width: 220px"
      />
      <FilterSelect v-model="filters.equipment_ids" :items="equipments" item-title="name" item-value="id" label="設備" searchable style="max-width: 240px" />
      <v-select
        v-model="filters.department_id"
        :items="departments"
        item-title="display_name"
        item-value="id"
        label="部署"
        clearable
        density="compact"
        hide-details
        style="max-width: 320px"
      />
      <FilterSelect v-model="filters.statuses" :items="statusOptions" label="ステータス" style="max-width: 200px" />
      <FilterSelect v-model="filters.priorities" :items="priorityOptions" label="優先度" style="max-width: 200px" />
      <InstrumentFilterChip v-if="filters.instrument_id" :instrument-id="filters.instrument_id" @clear="clearInstrument" />
      <FilterResetButton @reset="reset" />
    </div>

    <v-data-table
      v-model:page="tablePage"
      :headers="headers"
      :items="troubles"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.reported_at="{ item }">
        {{ formatDate(item.reported_at) }}
      </template>
      <template #item.priority="{ item }">
        <StatusChip kind="priority" :value="item.priority" />
      </template>
      <template #item.status="{ item }">
        <StatusChip kind="trouble" :value="item.status" />
      </template>
      <template #item.instrument.tag_number="{ item }">
        <!-- 計器の詳細（過去のトラブル・点検の履歴）へ。行のクリック（トラブルの詳細）とは別に動かす -->
        <router-link v-if="item.instrument" class="text-primary" :to="`/instruments/${item.instrument.id}`" @click.stop>{{ item.instrument.tag_number }}</router-link>
        <template v-else>—</template>
      </template>
      <template #item.assigned_to.name="{ item }">
        {{ item.assigned_to?.name || '未割当' }}
      </template>
      <template #item.title="{ item }">
        {{ item.title }}
        <v-chip v-if="item.source === 'device_diagnostic'" size="x-small" label variant="tonal" color="primary" class="ml-1">機器の診断</v-chip>
      </template>
      <template #item.department_display="{ item }">
        <!-- 機器の診断から作ったトラブルの報告者は連携用のトークンを発行した人のため、報告者の部署は出さない -->
        {{ item.assigned_to?.department?.name || (item.source === 'device_diagnostic' ? '' : item.reported_by?.department?.name) || '—' }}
      </template>
    </v-data-table>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>トラブル報告</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="form.title" label="タイトル *" class="mb-2" />
          <v-select
            v-model="form.equipment_id"
            :items="equipments"
            item-title="name"
            item-value="id"
            label="設備 *"
            class="mb-2"
            @update:model-value="fetchInstruments"
          />
          <v-select
            v-model="form.instrument_id"
            :items="instruments"
            item-title="tag_number"
            item-value="id"
            label="計器"
            clearable
            class="mb-2"
          />
          <v-select
            v-model="form.priority"
            :items="priorityOptions"
            item-title="title"
            item-value="value"
            label="優先度"
            class="mb-2"
          />
          <v-text-field v-model="form.reported_at" label="報告日時" type="datetime-local" class="mb-2" />
          <v-textarea v-model="form.description" label="詳細説明" rows="3" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="save">報告</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
