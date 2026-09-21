<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import DashboardOrganizationScope from '@/components/DashboardOrganizationScope.vue'
import { latestGuard } from '@/utils/latestGuard'
import { useAuthStore } from '@/stores/auth'
import { siteIdsToQuery } from '@/utils/listQuery'
import type { DashboardScope, DashboardSummary } from '@/types/models'

const authStore = useAuthStore()
const dashboard = ref<DashboardSummary | null>(null)
const loading = ref(true)
const error = ref('')
const scope = ref<DashboardScope>({
  siteId: authStore.user?.site_id ?? null,
  departmentId: authStore.user?.department_id ?? null,
})
const fetchDashboardGuard = latestGuard()
const scopeName = computed(() => dashboard.value?.scope.department_name ?? '拠点全体')
const siteName = computed(() => dashboard.value?.scope.site_name ?? '全拠点')
const maintenanceStats = computed(() => dashboard.value ? [
  { label: '計画・準備中', value: dashboard.value.maintenances.planned, icon: 'mdi-calendar-outline' },
  { label: '実施・検収中', value: dashboard.value.maintenances.in_progress, icon: 'mdi-wrench-outline' },
  { label: '30日以内に開始', value: dashboard.value.maintenances.upcoming_count, icon: 'mdi-calendar-clock-outline' },
] : [])

async function fetchDashboard() {
  const isLatest = fetchDashboardGuard()
  loading.value = true
  error.value = ''
  try {
    const params: Record<string, number> = {}
    if (scope.value.siteId) params.site_id = scope.value.siteId
    if (scope.value.departmentId) params.department_id = scope.value.departmentId
    const res = await api.get<{ data: DashboardSummary }>('/dashboard', { params })
    if (isLatest()) dashboard.value = res.data.data
  } catch {
    if (isLatest()) error.value = 'ダッシュボードを読み込めませんでした。再読み込みしてください。'
  } finally {
    if (isLatest()) loading.value = false
  }
}

function listLink(path: string, filters: Record<string, string> = {}, includeDepartment = true) {
  const query: Record<string, string> = {
    ...filters,
    site_ids: siteIdsToQuery(scope.value.siteId ? [scope.value.siteId] : []),
  }
  if (includeDepartment && scope.value.departmentId) query.department_id = String(scope.value.departmentId)
  return { path, query }
}

function formatDate(date: string) {
  return new Date(date + 'T00:00:00+09:00').toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', timeZone: 'Asia/Tokyo' })
}

watch(scope, fetchDashboard, { deep: true, immediate: true })
</script>

<template>
  <MainLayout>
    <div class="pk-dashboard">
      <PageHeader title="ダッシュボード" description="担当する組織の状況と、拠点の整備予定を確認できます。" />
      <DashboardOrganizationScope v-model="scope" />

      <div v-if="error" class="mt-5">
        <v-alert type="error" variant="tonal" role="alert">{{ error }}</v-alert>
        <v-btn class="mt-3" variant="outlined" @click="fetchDashboard">再読み込み</v-btn>
      </div>
      <div v-else-if="loading" class="pk-dashboard-loading" role="status" aria-label="ダッシュボードを読み込み中">
        <v-progress-linear indeterminate color="primary" />
        <p>選択した組織の状況を確認しています</p>
      </div>
      <template v-else-if="dashboard">
        <section class="pk-attention" aria-labelledby="action-summary-title">
          <div class="pk-section-heading">
            <h2 id="action-summary-title">{{ scopeName }}の要対応</h2>
            <router-link
              v-if="dashboard.troubles.critical"
              class="pk-critical-link"
              :to="listLink('/troubles', { priority: 'critical', status: 'open,in_progress,deferred,resolved' })"
            >
              <v-icon size="16" aria-hidden="true">mdi-alert-circle-outline</v-icon>
              緊急 {{ dashboard.troubles.critical }}件
              <v-icon size="16" aria-hidden="true">mdi-chevron-right</v-icon>
            </router-link>
          </div>
          <div class="pk-attention__grid">
            <router-link class="pk-kpi" :to="listLink('/troubles', { status: 'open' })">
              <span class="pk-kpi__top"><v-icon size="20" :color="dashboard.troubles.open ? 'error' : 'secondary'" aria-hidden="true">mdi-alert-circle-outline</v-icon><span>未対応トラブル</span></span>
              <span class="pk-kpi__bottom"><span><strong class="pk-kpi__value">{{ dashboard.troubles.open }}</strong><small>件</small></span><v-icon size="19" aria-hidden="true">mdi-arrow-right</v-icon></span>
            </router-link>
            <router-link class="pk-kpi" :to="listLink('/troubles', { status: 'in_progress' })">
              <span class="pk-kpi__top"><v-icon size="20" color="secondary" aria-hidden="true">mdi-progress-wrench</v-icon><span>対応中トラブル</span></span>
              <span class="pk-kpi__bottom"><span><strong class="pk-kpi__value">{{ dashboard.troubles.in_progress }}</strong><small>件</small></span><v-icon size="19" aria-hidden="true">mdi-arrow-right</v-icon></span>
            </router-link>
            <router-link class="pk-kpi" :to="listLink('/inspections', { status: 'approval_requested' })">
              <span class="pk-kpi__top"><v-icon size="20" color="primary" aria-hidden="true">mdi-clipboard-check-outline</v-icon><span>承認待ち点検</span></span>
              <span class="pk-kpi__bottom"><span><strong class="pk-kpi__value">{{ dashboard.inspections.pending_approval }}</strong><small>件</small></span><v-icon size="19" aria-hidden="true">mdi-arrow-right</v-icon></span>
            </router-link>
          </div>
          <p class="pk-scope-note">選択した組織と配下を集計。トラブルは報告者・担当者の所属、点検は記録の部署が対象です。</p>
        </section>

        <section class="pk-maintenance" aria-labelledby="site-maintenance-title">
          <header class="pk-maintenance__header">
            <div>
              <h2 id="site-maintenance-title">拠点の定期整備</h2>
              <p>{{ scope.siteId ? `${siteName}全体` : '全拠点' }}の予定です。部署の選択にかかわらず表示します。</p>
            </div>
            <v-btn variant="text" color="primary" size="small" :to="listLink('/maintenances', {}, false)" append-icon="mdi-chevron-right">すべて見る</v-btn>
          </header>
          <div class="pk-maintenance__body">
            <dl class="pk-maintenance__stats">
              <div v-for="stat in maintenanceStats" :key="stat.label">
                <dt><v-icon size="18" aria-hidden="true">{{ stat.icon }}</v-icon>{{ stat.label }}</dt>
                <dd>{{ stat.value }}<small>件</small></dd>
              </div>
            </dl>
            <div class="pk-maintenance__schedule">
              <h3>これから30日間の予定</h3>
              <ul v-if="dashboard.maintenances.upcoming.length" class="pk-schedule">
                <li v-for="maintenance in dashboard.maintenances.upcoming.slice(0, 3)" :key="maintenance.id">
                  <router-link :to="`/maintenances/${maintenance.id}`">
                    <time :datetime="maintenance.planned_start_on">{{ formatDate(maintenance.planned_start_on) }}<small>開始</small></time>
                    <span class="pk-schedule__copy">
                      <strong>{{ maintenance.title }}</strong>
                      <span>{{ maintenance.equipments.map((equipment) => equipment.name).join('・') }}</span>
                    </span>
                    <v-icon size="18" aria-hidden="true">mdi-chevron-right</v-icon>
                  </router-link>
                </li>
              </ul>
              <div v-else class="pk-schedule-empty">
                <v-icon size="24" aria-hidden="true">mdi-calendar-check-outline</v-icon>
                <p>30日以内に開始する定期整備はありません。</p>
                <router-link :to="listLink('/maintenances', {}, false)">先の予定を確認する</router-link>
              </div>
            </div>
          </div>
        </section>
      </template>
    </div>
  </MainLayout>
</template>

<style scoped>
.pk-dashboard { max-width: 1240px; margin-inline: auto; }
.pk-dashboard-loading { margin-top: 28px; min-height: 320px; color: var(--pk-muted); }
.pk-dashboard-loading p { padding-top: 16px; font-size: 0.875rem; }
.pk-attention { margin-block: 28px; }
.pk-section-heading { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 12px; }
h2 { font-family: var(--pk-font-display); font-size: 1.125rem; line-height: 1.5; text-wrap: balance; }
.pk-critical-link { display: inline-flex; align-items: center; gap: 4px; color: rgb(var(--v-theme-error)); font-size: 0.8125rem; text-decoration: none; }
.pk-critical-link:hover { text-decoration: underline; }
.pk-attention__grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
.pk-kpi { display: grid; gap: 14px; padding: 20px 24px; border: 1px solid var(--pk-line); border-radius: 14px; background: #fff; color: var(--pk-ink); text-decoration: none; }
.pk-kpi:hover { border-color: var(--pk-steel); background: var(--pk-soft-blue); }
.pk-kpi__top, .pk-kpi__bottom { display: flex; align-items: center; gap: 10px; }
.pk-kpi__top { font-size: 0.875rem; color: var(--pk-steel-dark); }
.pk-kpi__bottom { justify-content: space-between; }
.pk-kpi__bottom > .v-icon { color: var(--pk-steel); }
.pk-kpi__value { font-size: 2rem; font-weight: 600; line-height: 1; font-variant-numeric: tabular-nums; }
.pk-kpi small { margin-left: 8px; color: var(--pk-muted); font-size: 0.75rem; }
.pk-scope-note { margin: 10px 0 0; color: var(--pk-muted); font-size: 0.75rem; line-height: 1.6; text-wrap: pretty; }
.pk-maintenance { overflow: hidden; border: 1px solid var(--pk-line); border-radius: 16px; background: #fff; }
.pk-maintenance__header { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 20px 24px; border-bottom: 1px solid var(--pk-line); }
.pk-maintenance__header p { margin-top: 4px; color: var(--pk-muted); font-size: 0.8125rem; line-height: 1.6; text-wrap: pretty; }
.pk-maintenance__header > .v-btn { flex: none; }
.pk-maintenance__body { display: grid; grid-template-columns: 260px minmax(0, 1fr); }
.pk-maintenance__stats { display: flex; flex-direction: column; justify-content: center; gap: 24px; padding: 28px 24px; background: var(--pk-soft-blue); }
.pk-maintenance__stats > div { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.pk-maintenance__stats dt { display: flex; align-items: center; gap: 8px; font-size: 0.8125rem; color: var(--pk-steel-dark); }
.pk-maintenance__stats dd { font-size: 1.5rem; font-weight: 600; font-variant-numeric: tabular-nums; }
.pk-maintenance__stats small { margin-left: 4px; font-size: 0.6875rem; font-weight: 400; color: var(--pk-muted); }
.pk-maintenance__schedule { min-width: 0; padding: 20px 24px 12px; }
.pk-maintenance__schedule h3 { margin-bottom: 8px; font-size: 0.8125rem; color: var(--pk-muted); }
.pk-schedule { padding: 0; list-style: none; }
.pk-schedule li + li { border-top: 1px solid var(--pk-line); }
.pk-schedule a { display: flex; align-items: center; gap: 16px; padding: 14px 0; color: var(--pk-ink); text-decoration: none; }
.pk-schedule a:hover strong { color: var(--pk-steel); text-decoration: underline; }
.pk-schedule time { min-width: 52px; color: var(--pk-steel-dark); font-size: 1rem; font-weight: 700; font-variant-numeric: tabular-nums; }
.pk-schedule time small { display: block; margin-top: 2px; color: var(--pk-muted); font-size: 0.625rem; font-weight: 400; }
.pk-schedule__copy { display: grid; min-width: 0; flex: 1; gap: 4px; }
.pk-schedule__copy strong { font-size: 0.875rem; font-weight: 500; overflow-wrap: anywhere; }
.pk-schedule__copy > span { color: var(--pk-muted); font-size: 0.75rem; }
.pk-schedule a > .v-icon { color: var(--pk-muted); flex: none; }
.pk-schedule-empty { padding-block: 20px; color: var(--pk-muted); font-size: 0.875rem; line-height: 1.8; }
.pk-schedule-empty a { color: var(--pk-steel); }
a:focus-visible { outline: 2px solid var(--pk-steel); outline-offset: 4px; }
@media (max-width: 960px) {
  .pk-attention__grid { grid-template-columns: 1fr; gap: 8px; }
  .pk-kpi { display: flex; justify-content: space-between; align-items: center; padding: 16px; gap: 12px; }
  .pk-kpi__bottom { gap: 16px; }
  .pk-maintenance__body { grid-template-columns: 1fr; }
  .pk-maintenance__stats { flex-direction: row; padding: 20px; gap: 16px; justify-content: space-between; }
  .pk-maintenance__stats > div { flex-direction: column; align-items: start; gap: 8px; }
  .pk-kpi { padding: 16px; }
}
@media (max-width: 600px) {
  .pk-attention { margin-block: 24px; }
  .pk-kpi__value { font-size: 1.5rem; }
  .pk-kpi__top { gap: 8px; font-size: 0.8125rem; }
  .pk-maintenance__header { padding: 16px; align-items: start; flex-wrap: wrap; gap: 8px; }
  .pk-maintenance__header > .v-btn { margin-left: -8px; }
  .pk-maintenance__stats { padding: 16px; gap: 8px; }
  .pk-maintenance__stats dt { gap: 4px; font-size: 0.6875rem; }
  .pk-maintenance__stats dt .v-icon { display: none; }
  .pk-maintenance__schedule { padding: 16px; }
  .pk-schedule a { gap: 12px; }
}
</style>
