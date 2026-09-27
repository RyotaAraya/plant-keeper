<script setup lang="ts">
// 計画: 定期点検のまとまり（→ 設備・計器ごとの点検計画）と、定期整備の系列（→ 設備ごとの周期と各回）・単発の整備を1画面に並べる。
// 親の行を押すと、その場で子を開く。点検計画を期限順に見る表（周期の見直しの候補・期限超過の絞り込み）は「期限順」に切り替えて見る
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import FilterSelect from '@/components/FilterSelect.vue'
import MaintenanceSeriesDialog from '@/components/MaintenanceSeriesDialog.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import InspectionGroupPlans from '@/components/plans/InspectionGroupPlans.vue'
import InspectionPlanDueList from '@/components/plans/InspectionPlanDueList.vue'
import InspectionPlanGroupDialog from '@/components/plans/InspectionPlanGroupDialog.vue'
import MaintenanceCreateDialog from '@/components/plans/MaintenanceCreateDialog.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { MAINTENANCE_STATUS_COLOR, MAINTENANCE_STATUS_LABEL, periodLabel } from '@/constants/maintenanceStatus'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { InspectionPlanGroup } from '@/types/models'
import { groupLabel } from '@/utils/inspectionPlanGroup'
import { latestGuard } from '@/utils/latestGuard'
import { listFromQuery, siteIdsFromQuery } from '@/utils/listQuery'
import { regulationColor } from '@/utils/regulation'

type Tab = 'all' | 'inspection' | 'maintenance' | 'due'
const TABS: { value: Tab; title: string }[] = [
  { value: 'all', title: 'すべて' },
  { value: 'inspection', title: '定期点検' },
  { value: 'maintenance', title: '定期整備' },
  { value: 'due', title: '点検の期限順' },
]

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { canManageInspectionPlan, canManageMaintenance } = usePermissions()

const tabFromQuery = (): Tab => (TABS.some((t) => t.value === route.query.tab) ? (route.query.tab as Tab) : 'all')
const tab = ref<Tab>(tabFromQuery())
const showInspection = computed(() => tab.value === 'all' || tab.value === 'inspection')
const showMaintenance = computed(() => tab.value === 'all' || tab.value === 'maintenance')

function initialFilters() {
  return {
    // 通常業務では自拠点の計画だけ見ればよいため、自分の所属拠点を初期値にする
    site_ids: siteIdsFromQuery(route.query.site_ids, authStore.user?.site_id ? [authStore.user.site_id] : []),
    // 担当部署・法規区分は、点検のまとまりだけが持つ
    department_id: null as number | null,
    regulation_ids: [] as number[],
    // 定期整備の状態（朝会ボードなどから ?status=in_progress で引き継ぐ）
    statuses: listFromQuery(route.query.status),
  }
}
const filters = ref(initialFilters())
// 担当部署・法規区分で絞っている間は、それを持たない定期整備を出さない
const narrowedToGroups = computed(() => !!filters.value.department_id || filters.value.regulation_ids.length > 0)

const { equipments, departments, load: loadSiteOptions } = useSiteScopeOptions()
const regulations = ref<{ id: number; name: string }[]>([])

// --- 定期点検のまとまり ---
const groups = ref<InspectionPlanGroup[]>([])
const groupsLoading = ref(false)
const expandedGroups = ref<any[]>([]) // 開いているまとまりのID
const groupsGuard = latestGuard()
const multiSite = computed(() => filters.value.site_ids.length !== 1)

const groupHeaders = [
  { title: 'まとまり', key: 'name', sortable: false },
  { title: '担当部署', key: 'department', sortable: false, width: '200px' },
  { title: '計画', key: 'plans_count', sortable: false, width: '80px' },
  { title: '期限', key: 'next_due_on', sortable: false, width: '230px' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
  { title: '', key: 'data-table-expand', width: '48px' },
]

// 期限超過のあるまとまり → 次回期限の近い順
const sortedGroups = computed(() =>
  [...groups.value].sort((a, b) =>
    (b.overdue_count ?? 0) - (a.overdue_count ?? 0) || (a.next_due_on ?? '9999').localeCompare(b.next_due_on ?? '9999') || a.name.localeCompare(b.name, 'ja'),
  ),
)

async function loadGroups() {
  const isLatest = groupsGuard()
  groupsLoading.value = true
  try {
    const params: any = {}
    if (filters.value.site_ids.length) params.site_ids = filters.value.site_ids
    if (filters.value.department_id) params.department_id = filters.value.department_id
    if (filters.value.regulation_ids.length) params.regulation_ids = filters.value.regulation_ids
    const res = await api.get('/inspection_plan_groups', { params })
    if (isLatest()) groups.value = res.data.data
  } finally {
    if (isLatest()) groupsLoading.value = false
  }
}

// --- 定期整備（系列と単発） ---
type MaintenanceRow =
  | { key: string; kind: 'series'; series: any; maintenances: any[]; current: any | null }
  | { key: string; kind: 'single'; maintenance: any }
const series = ref<any[]>([])
const maintenances = ref<any[]>([])
const maintenanceLoading = ref(false)
const expandedMaintenance = ref<string[]>([])
const maintenanceGuard = latestGuard()
const statusOptions = Object.entries(MAINTENANCE_STATUS_LABEL).map(([value, title]) => ({ title, value }))

const maintenanceHeaders = [
  { title: '種類', key: 'kind', sortable: false, width: '80px' },
  { title: '名称', key: 'name', sortable: false },
  { title: '対象設備', key: 'equipments', sortable: false },
  { title: '予定期間', key: 'period', sortable: false, width: '190px' },
  { title: '作業', key: 'tasks', sortable: false, width: '80px' },
  { title: '状態', key: 'status', sortable: false, width: '100px' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
  { title: '', key: 'data-table-expand', width: '48px' },
]

// 系列の代表の回（「今の回」）は、終わっていない回のうち最も早いもの（なければ最後の回）
function currentOf(items: any[]) {
  const open = items.filter((m) => m.status !== 'completed').sort((a, b) => a.planned_start_on.localeCompare(b.planned_start_on))
  return open[0] ?? [...items].sort((a, b) => b.planned_start_on.localeCompare(a.planned_start_on))[0] ?? null
}

// 行の代表の回（系列は今の回、単発はその整備）。予定期間・作業・状態に使う
const roundOf = (row: MaintenanceRow) => (row.kind === 'series' ? row.current : row.maintenance)

const maintenanceRows = computed<MaintenanceRow[]>(() => {
  const matches = (m: any) => !filters.value.statuses.length || filters.value.statuses.includes(m.status)
  const seriesRows: MaintenanceRow[] = series.value
    .map((s) => {
      const items = maintenances.value.filter((m) => m.maintenance_series?.id === s.id)
      // 状態で絞っているときは、その状態の回を代表にする（「完了」で絞って、計画中の回が出ないように）
      return { key: `series-${s.id}`, kind: 'series' as const, series: s, maintenances: items, current: currentOf(items.filter(matches)) }
    })
    .filter((row) => !filters.value.statuses.length || row.maintenances.some(matches))
  const singles: MaintenanceRow[] = maintenances.value
    .filter((m) => !m.maintenance_series && matches(m))
    .map((m) => ({ key: `single-${m.id}`, kind: 'single' as const, maintenance: m }))
  // 系列（親）を先に、単発を後に。どちらも予定の新しい順（今までの定期整備の一覧と同じ）
  const byDateDesc = (a: MaintenanceRow, b: MaintenanceRow) => (roundOf(b)?.planned_start_on ?? '').localeCompare(roundOf(a)?.planned_start_on ?? '')
  return [...seriesRows.sort(byDateDesc), ...singles.sort(byDateDesc)]
})

async function loadMaintenance() {
  const isLatest = maintenanceGuard()
  maintenanceLoading.value = true
  try {
    const params: any = filters.value.site_ids.length ? { site_ids: filters.value.site_ids } : {}
    const [seriesRes, maintenanceRes] = await Promise.all([
      api.get('/maintenance_series', { params }),
      api.get('/scheduled_maintenances', { params: { ...params, per_page: 1000 } }),
    ])
    if (!isLatest()) return
    series.value = seriesRes.data.data
    maintenances.value = maintenanceRes.data.data
  } finally {
    if (isLatest()) maintenanceLoading.value = false
  }
}

function openMaintenanceRow(row: MaintenanceRow, toggleExpand: () => void) {
  if (row.kind === 'single') router.push(`/maintenances/${row.maintenance.id}`)
  else toggleExpand()
}

// --- 取得 ---
async function loadAll() {
  if (tab.value === 'due') return
  const tasks: Promise<unknown>[] = []
  if (showInspection.value) tasks.push(loadGroups())
  if (showMaintenance.value) tasks.push(loadMaintenance())
  await Promise.all(tasks)
}

// 拠点を変えたら、表示する拠点にない部署の絞り込みは外す
function changeSite(siteIds: number[]) {
  const shown = (id: number) => siteIds.length === 0 || siteIds.includes(id)
  const keepDepartment = departments.value.find((d) => d.id === filters.value.department_id && shown(d.site_id))
  filters.value = { ...filters.value, site_ids: siteIds, department_id: keepDepartment ? keepDepartment.id : null }
  loadSiteOptions(siteIds)
}

function changeTab(value: Tab) {
  router.replace({ path: '/plans', query: value === 'all' ? {} : { tab: value } })
}

// --- 追加・編集 ---
const dueList = ref<InstanceType<typeof InspectionPlanDueList> | null>(null)
const groupDialog = ref(false)
const editingGroup = ref<InspectionPlanGroup | null>(null)
const maintenanceDialog = ref(false)
const seriesDialog = ref(false)
const editingSeries = ref<any>(null)
const defaultSiteId = computed(() => (filters.value.site_ids.length === 1 ? filters.value.site_ids[0] : authStore.user?.site_id) ?? null)

function openGroupDialog(group: InspectionPlanGroup | null) {
  editingGroup.value = group
  groupDialog.value = true
}

function openSeriesDialog(item: any) {
  editingSeries.value = item
  seriesDialog.value = true
}

// サイドバーから開き直したとき・転送で来たときは、クエリに合わせ直す
watch(
  () => route.query,
  () => {
    if (route.path !== '/plans') return
    tab.value = tabFromQuery()
    filters.value = initialFilters()
    expandedGroups.value = []
    expandedMaintenance.value = []
  },
)
watch(filters, loadAll, { deep: true })
watch(tab, loadAll)

loadSiteOptions(filters.value.site_ids)
api.get('/regulations').then((res) => (regulations.value = res.data.data))
loadAll()
</script>

<template>
  <MainLayout>
    <PageHeader title="計画" description="定期点検のまとまりと、定期整備の系列・単発の整備です。行を押すと、設備・計器ごとの周期と次回期限を開きます。">
      <template v-if="tab === 'due'">
        <v-btn v-if="canManageInspectionPlan" color="primary" prepend-icon="mdi-plus" @click="dueList?.openCreate()">計画を追加</v-btn>
      </template>
      <template v-else>
        <v-btn v-if="canManageInspectionPlan && showInspection" color="primary" variant="outlined" prepend-icon="mdi-plus" class="mr-2" @click="openGroupDialog(null)">まとまりを追加</v-btn>
        <v-btn v-if="canManageMaintenance && showMaintenance" color="primary" prepend-icon="mdi-plus" @click="maintenanceDialog = true">定期整備を作成</v-btn>
      </template>
    </PageHeader>

    <div class="pk-plan-tabs mb-4">
      <v-btn-toggle :model-value="tab" mandatory density="compact" variant="outlined" color="primary" aria-label="表示する計画" @update:model-value="changeTab">
        <v-btn v-for="t in TABS" :key="t.value" :value="t.value">{{ t.title }}</v-btn>
      </v-btn-toggle>
    </div>

    <InspectionPlanDueList v-if="tab === 'due'" ref="dueList" :key="route.fullPath" />

    <template v-else>
      <div class="pk-filters">
        <SiteScopeTag :model-value="filters.site_ids" @update:model-value="changeSite" />
        <v-divider vertical class="pk-scope-divider" />
        <template v-if="showInspection">
          <v-select
            v-model="filters.department_id"
            :items="departments"
            item-title="display_name"
            item-value="id"
            label="担当部署"
            clearable
            density="compact"
            hide-details
            style="min-width: 200px; max-width: 280px"
          />
          <FilterSelect v-model="filters.regulation_ids" :items="regulations" item-title="name" item-value="id" label="法規区分" style="min-width: 180px; max-width: 220px" />
        </template>
        <FilterSelect v-if="showMaintenance" v-model="filters.statuses" :items="statusOptions" label="定期整備の状態" style="min-width: 180px; max-width: 220px" />
      </div>

      <section v-if="showInspection" class="mb-6" aria-labelledby="plan-inspection-heading">
        <h2 id="plan-inspection-heading" class="pk-plan-heading">定期点検<span>まとまり → 設備・計器ごとの点検計画</span></h2>
        <v-data-table
          v-model:expanded="expandedGroups"
          :headers="groupHeaders"
          :items="sortedGroups"
          :loading="groupsLoading"
          item-value="id"
          expand-on-click
          :items-per-page="-1"
          hide-default-footer
          hover
          class="pk-plan-table"
          data-testid="plan-groups"
        >
          <template #item.name="{ item }">
            <v-chip size="x-small" label color="primary" variant="tonal" class="mr-2">点検</v-chip>
            <strong>{{ groupLabel(item, multiSite) }}</strong>
            <v-chip v-if="item.regulation" size="x-small" label variant="tonal" :color="regulationColor(item.regulation.code)" class="ml-2">{{ item.regulation.name }}</v-chip>
          </template>
          <template #item.department="{ item }">{{ item.department?.name ?? '—' }}</template>
          <template #item.plans_count="{ item }">{{ item.plans_count }}件</template>
          <template #item.next_due_on="{ item }">
            <v-chip v-if="item.overdue_count" color="error" size="small" class="mr-1">超過 {{ item.overdue_count }}件</v-chip>
            <span v-if="item.next_due_on" class="text-no-wrap">次回 {{ item.next_due_on }}</span>
          </template>
          <template #item.actions="{ item }">
            <v-btn v-if="canManageInspectionPlan" icon="mdi-pencil-outline" size="small" variant="text" :aria-label="`${item.name}を編集`" @click.stop="openGroupDialog(item)" />
          </template>
          <template #expanded-row="{ columns, item }">
            <tr class="pk-plan-expanded">
              <td :colspan="columns.length">
                <InspectionGroupPlans :group="item" :equipments="equipments" @changed="loadGroups" />
              </td>
            </tr>
          </template>
          <template #no-data>該当するまとまりはありません。</template>
        </v-data-table>
      </section>

      <section v-if="showMaintenance" aria-labelledby="plan-maintenance-heading">
        <h2 id="plan-maintenance-heading" class="pk-plan-heading">定期整備<span>系列 → 設備ごとの周期と各回・単発の整備</span></h2>
        <p v-if="narrowedToGroups" class="text-body-2 text-medium-emphasis">担当部署・法規区分で絞り込んでいる間は、定期整備を表示しません（定期整備には担当部署・法規区分がないため）。</p>
        <v-data-table
          v-else
          v-model:expanded="expandedMaintenance"
          :headers="maintenanceHeaders"
          :items="maintenanceRows"
          :loading="maintenanceLoading"
          item-value="key"
          :items-per-page="25"
          hover
          class="pk-plan-table"
          data-testid="plan-maintenances"
          @click:row="(_e: any, { item, toggleExpand, internalItem }: any) => openMaintenanceRow(item, () => toggleExpand(internalItem))"
        >
          <template #item.kind="{ item }">
            <v-chip size="x-small" label :color="item.kind === 'series' ? 'deep-purple' : 'blue-grey'" variant="tonal">{{ item.kind === 'series' ? '系列' : '単発' }}</v-chip>
          </template>
          <template #item.name="{ item }">
            <template v-if="item.kind === 'series'">
              <strong>{{ item.series.name }}</strong>
              <div v-if="item.current" class="text-caption text-medium-emphasis">今の回: {{ item.current.title }}</div>
            </template>
            <template v-else>{{ item.maintenance.title }}</template>
          </template>
          <template #item.equipments="{ item }">
            <template v-if="item.kind === 'series'">
              <v-chip v-for="m in item.series.maintenance_series_equipments" :key="m.id" size="x-small" label variant="tonal" class="mr-1 my-1">
                {{ m.equipment?.name }}（{{ m.interval_months }}か月）
              </v-chip>
            </template>
            <template v-else>
              <v-chip v-for="equipment in item.maintenance.equipments" :key="equipment.id" size="x-small" label variant="tonal" class="mr-1 my-1">{{ equipment.name }}</v-chip>
            </template>
          </template>
          <template #item.period="{ item }">
            <span class="text-no-wrap">{{ roundOf(item) ? periodLabel(roundOf(item).planned_start_on, roundOf(item).planned_end_on) : '—' }}</span>
          </template>
          <template #item.tasks="{ item }">
            <span v-if="roundOf(item)?.tasks_summary?.total" class="text-no-wrap">{{ roundOf(item).tasks_summary.completed }} / {{ roundOf(item).tasks_summary.total }}</span>
            <span v-else class="text-medium-emphasis">—</span>
          </template>
          <template #item.status="{ item }">
            <v-chip v-if="roundOf(item)" :color="MAINTENANCE_STATUS_COLOR[roundOf(item).status]" size="small">{{ MAINTENANCE_STATUS_LABEL[roundOf(item).status] }}</v-chip>
          </template>
          <template #item.actions="{ item }">
            <v-btn v-if="item.kind === 'series' && canManageMaintenance" icon="mdi-pencil-outline" size="small" variant="text" :aria-label="`${item.series.name}を編集`" @click.stop="openSeriesDialog(item.series)" />
          </template>
          <template #item.data-table-expand="{ item, internalItem, isExpanded, toggleExpand }">
            <v-btn
              v-if="item.kind === 'series'"
              :icon="isExpanded(internalItem) ? 'mdi-chevron-up' : 'mdi-chevron-down'"
              size="small"
              variant="text"
              :aria-label="`${item.series.name}の各回を${isExpanded(internalItem) ? '閉じる' : '開く'}`"
              @click.stop="toggleExpand(internalItem)"
            />
            <v-icon v-else size="small" color="medium-emphasis">mdi-chevron-right</v-icon>
          </template>
          <template #expanded-row="{ columns, item }">
            <tr v-if="item.kind === 'series'" class="pk-plan-expanded">
              <td :colspan="columns.length">
                <div class="pk-series-rounds" :data-testid="`series-rounds-${item.series.id}`">
                  <router-link
                    v-for="m in [...item.maintenances].sort((a, b) => b.planned_start_on.localeCompare(a.planned_start_on))"
                    :key="m.id"
                    :to="`/maintenances/${m.id}`"
                    class="pk-series-round"
                  >
                    <span>{{ m.title }}</span>
                    <span class="text-medium-emphasis text-no-wrap">{{ periodLabel(m.planned_start_on, m.planned_end_on) }}</span>
                    <v-chip :color="MAINTENANCE_STATUS_COLOR[m.status]" size="x-small">{{ MAINTENANCE_STATUS_LABEL[m.status] }}</v-chip>
                  </router-link>
                  <div v-if="!item.maintenances.length" class="text-medium-emphasis text-body-2">この拠点の回はありません。</div>
                </div>
              </td>
            </tr>
          </template>
          <template #no-data>該当する定期整備はありません。</template>
        </v-data-table>
      </section>
    </template>

    <InspectionPlanGroupDialog v-model="groupDialog" :group="editingGroup" :default-site-id="defaultSiteId" @saved="loadGroups" />
    <MaintenanceCreateDialog v-model="maintenanceDialog" :default-site-id="defaultSiteId" @saved="loadMaintenance" />
    <!-- 常に置いておく（開いたときに系列を読み込むため。v-if で開くと同時に作ると、開いたことに気づかない） -->
    <MaintenanceSeriesDialog
      v-model="seriesDialog"
      :series="editingSeries"
      :maintenance="{ site_id: editingSeries?.site_id ?? null, title: '', equipments: [] }"
      @saved="loadMaintenance"
    />
  </MainLayout>
</template>

<style scoped>
/* 狭い画面では、切り替えだけを横にスクロールする（ボタンを潰さない） */
.pk-plan-tabs { overflow-x: auto; }
.pk-plan-heading { display: flex; align-items: baseline; gap: 12px; margin-bottom: 8px; font-size: 1rem; font-weight: 700; }
.pk-plan-heading span { color: var(--pk-muted); font-size: 0.8125rem; font-weight: 400; }
.pk-plan-table :deep(tbody tr.v-data-table__tr) { cursor: pointer; }
.pk-plan-expanded > td { background: rgb(var(--v-theme-surface-variant), 0.35); }
.pk-series-rounds { display: grid; gap: 4px; padding: 8px 0 8px 32px; }
.pk-series-round { display: grid; grid-template-columns: minmax(0, 1fr) auto auto; align-items: center; gap: 12px; padding: 6px 8px; border-radius: 8px; color: inherit; text-decoration: none; }
.pk-series-round:hover { background: rgb(var(--v-theme-primary), 0.06); }
</style>
