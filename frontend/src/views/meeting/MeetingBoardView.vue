<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import DashboardOrganizationScope from '@/components/DashboardOrganizationScope.vue'
import { useAuthStore } from '@/stores/auth'
import { usePermissions } from '@/composables/usePermissions'
import { latestGuard } from '@/utils/latestGuard'
import { siteIdsToQuery } from '@/utils/listQuery'
import { equipmentNames } from '@/utils/equipment'
import { inspectionFromPlan, referenceStandardFromPlan } from '@/utils/inspectionPlan'
import { bypassColor, bypassLabel, formatHours, restoreDueLabel } from '@/utils/interlock'
import { priorityColor, priorityLabel, troubleStatusColor, troubleStatusLabel } from '@/constants/recordLabels'
import { TASK_KIND_LABEL, TASK_STATUS_COLOR, TASK_STATUS_LABEL, periodLabel } from '@/constants/maintenanceStatus'
import type { DashboardScope, MeetingBoard, MeetingBoardPlan } from '@/types/models'

// 朝会・夕会ボード: 今日・明日の予定を、拠点・部署で絞って1枚にまとめる（要求仕様書 2.8）。
// 範囲の選び方はダッシュボードと同じ（初期値は本人の所属。部署のない人は拠点全体）
const authStore = useAuthStore()
const { canManageReferenceStandard } = usePermissions()
const board = ref<MeetingBoard | null>(null)
const loading = ref(true)
const error = ref('')
const scope = ref<DashboardScope>({
  siteId: authStore.user?.site_id ?? null,
  departmentId: authStore.user?.department_id ?? null,
})
const fetchGuard = latestGuard()

const scopeName = computed(() => board.value?.scope.department_name ?? (scope.value.siteId ? '拠点全体' : '全拠点'))
const siteName = computed(() => (scope.value.siteId ? `${board.value?.scope.site_name ?? ''}全体` : '全拠点'))

// 点検計画を、期限超過・今日・明日に分ける
const planGroups = computed(() => {
  const plans = board.value?.inspection_plans ?? []
  return [
    { key: 'overdue', label: '期限超過', plans: plans.filter((p) => p.days_until_due < 0) },
    { key: 'today', label: '今日が期限', plans: plans.filter((p) => p.days_until_due === 0) },
    { key: 'tomorrow', label: '明日が期限', plans: plans.filter((p) => p.days_until_due === 1) },
  ]
})
const openTaskCount = computed(() => board.value?.maintenances.reduce((sum, m) => sum + m.open_tasks.length, 0) ?? 0)

async function fetchBoard() {
  const isLatest = fetchGuard()
  loading.value = true
  error.value = ''
  try {
    const params: Record<string, number> = {}
    if (scope.value.siteId) params.site_id = scope.value.siteId
    if (scope.value.departmentId) params.department_id = scope.value.departmentId
    const res = await api.get<{ data: MeetingBoard }>('/meeting_board', { params })
    if (isLatest()) board.value = res.data.data
  } catch {
    if (isLatest()) error.value = 'ボードを読み込めませんでした。再読み込みしてください。'
  } finally {
    if (isLatest()) loading.value = false
  }
}

// 一覧へ、表示中の拠点（と部署）を引き継ぐ
function listLink(path: string, filters: Record<string, string> = {}, includeDepartment = true) {
  const query: Record<string, string> = { ...filters, site_ids: siteIdsToQuery(scope.value.siteId ? [scope.value.siteId] : []) }
  if (includeDepartment && scope.value.departmentId) query.department_id = String(scope.value.departmentId)
  return { path, query }
}

// 「9月26日（土）」
function dayLabel(date: string | undefined) {
  if (!date) return ''
  return new Date(`${date}T00:00:00+09:00`).toLocaleDateString('ja-JP', { month: 'long', day: 'numeric', weekday: 'short', timeZone: 'Asia/Tokyo' })
    .replace(/\((.)\)/, '（$1）')
}

// 「9/20」
function shortDate(value: string) {
  return new Date(value).toLocaleDateString('ja-JP', { month: 'numeric', day: 'numeric', timeZone: 'Asia/Tokyo' })
}

function dueLabel(plan: MeetingBoardPlan) {
  if (plan.days_until_due < 0) return `${-plan.days_until_due}日超過`
  return plan.days_until_due === 0 ? '今日' : '明日'
}

function planTarget(plan: MeetingBoardPlan) {
  if (plan.reference_standard) return plan.reference_standard.name
  const names = equipmentNames(plan)
  return plan.instrument ? `${names} ／ ${plan.instrument.tag_number}` : names
}

watch(scope, fetchBoard, { deep: true, immediate: true })
</script>

<template>
  <MainLayout>
    <div class="pk-board">
      <PageHeader title="朝会・夕会ボード" description="今日・明日の予定と、進んでいる作業を1枚で確認します。" />
      <DashboardOrganizationScope v-model="scope" />

      <div v-if="error" class="mt-5">
        <v-alert type="error" variant="tonal" role="alert">{{ error }}</v-alert>
        <v-btn class="mt-3" variant="outlined" @click="fetchBoard">再読み込み</v-btn>
      </div>
      <div v-else-if="loading && !board" class="pk-board-loading" role="status" aria-label="ボードを読み込み中">
        <v-progress-linear indeterminate color="primary" />
      </div>
      <template v-else-if="board">
        <div class="pk-board__day" data-testid="board-day">
          <p><span>今日</span><strong>{{ dayLabel(board.today) }}</strong></p>
          <p><span>明日</span><strong>{{ dayLabel(board.tomorrow) }}</strong></p>
          <p class="pk-board__scope"><span>範囲</span><strong>{{ scopeName }}</strong></p>
          <v-progress-circular v-if="loading" indeterminate size="18" width="2" color="primary" aria-label="更新中" />
        </div>

        <!-- 安全に関わるため先頭。部署で絞らず拠点全体 -->
        <section class="pk-board-section" aria-labelledby="board-bypass-title" data-testid="board-bypasses">
          <header class="pk-board-section__header">
            <div>
              <h2 id="board-bypass-title">インターロックのバイパス<small>{{ board.interlock_bypasses.length }}件</small></h2>
              <p>{{ siteName }}の、バイパス中と復帰確認待ちです。安全に関わるため、部署の選択にかかわらず表示します。</p>
            </div>
            <v-btn variant="text" color="primary" size="small" :to="listLink('/interlocks', { bypass_state: 'open' }, false)" append-icon="mdi-chevron-right">台帳を開く</v-btn>
          </header>
          <ul v-if="board.interlock_bypasses.length" class="pk-board-list">
            <li v-for="bypass in board.interlock_bypasses" :key="bypass.id" :class="{ 'pk-board-list__alert': bypass.overdue }">
              <router-link :to="`/interlocks/${bypass.interlock.id}`">
                <v-chip :color="bypassColor(bypass)" size="small" label variant="flat">{{ bypassLabel(bypass) }}</v-chip>
                <span class="pk-board-list__copy">
                  <strong>{{ bypass.interlock.tag_number }} {{ bypass.interlock.name }}</strong>
                  <span v-if="bypass.status === 'bypassed'">{{ bypass.interlock.equipment.name }} ／ {{ formatHours(bypass.bypassed_hours) }}経過 ／ 予定の復帰まで{{ restoreDueLabel(bypass) }}</span>
                  <span v-else>{{ bypass.interlock.equipment.name }} ／ {{ bypass.restored_by?.name ?? '—' }}が復帰。別の人の確認を待っています</span>
                </span>
                <v-icon size="18" aria-hidden="true">mdi-chevron-right</v-icon>
              </router-link>
            </li>
          </ul>
          <p v-else class="pk-board-empty">バイパス中・復帰確認待ちのインターロックはありません。</p>
        </section>

        <section class="pk-board-section" aria-labelledby="board-plan-title" data-testid="board-plans">
          <header class="pk-board-section__header">
            <div>
              <h2 id="board-plan-title">点検計画<small>{{ board.inspection_plans.length }}件</small></h2>
              <p>期限を過ぎたものと、今日・明日が期限のものです。部署はチェックリストの部署で、上位の部署（課・部）のものも含みます。</p>
            </div>
            <v-btn variant="text" color="primary" size="small" :to="listLink('/inspection-plans', {}, false)" append-icon="mdi-chevron-right">計画の一覧</v-btn>
          </header>
          <div class="pk-board-plans">
            <div v-for="group in planGroups" :key="group.key" class="pk-board-plans__group" :data-testid="`board-plans-${group.key}`">
              <h3 :class="{ 'pk-board-plans__alert': group.key === 'overdue' && group.plans.length }">{{ group.label }}<small>{{ group.plans.length }}件</small></h3>
              <ul v-if="group.plans.length" class="pk-board-plans__items">
                <li v-for="plan in group.plans" :key="plan.id" :data-testid="`board-plan-${plan.id}`">
                  <div class="pk-board-plans__copy">
                    <strong>{{ plan.name }}</strong>
                    <span>{{ planTarget(plan) }}</span>
                    <span>{{ plan.checklist_template?.department.name ?? '部署なし' }} ／ {{ plan.next_due_on }}<template v-if="group.key === 'overdue'">（{{ dueLabel(plan) }}）</template></span>
                  </div>
                  <v-btn v-if="plan.reference_standard" size="small" variant="outlined" :to="referenceStandardFromPlan(plan, canManageReferenceStandard)">
                    {{ canManageReferenceStandard ? '校正を記録' : '基準器を見る' }}
                  </v-btn>
                  <v-btn v-else size="small" variant="outlined" :to="inspectionFromPlan(plan)">点検を実施</v-btn>
                </li>
              </ul>
              <p v-else class="pk-board-empty">ありません。</p>
            </div>
          </div>
        </section>

        <section class="pk-board-section" aria-labelledby="board-task-title" data-testid="board-maintenances">
          <header class="pk-board-section__header">
            <div>
              <h2 id="board-task-title">実施中の定期整備の作業<small>残り{{ openTaskCount }}件</small></h2>
              <p>未着手・実施中の作業です。進み具合は、範囲の作業（見送りを除く）のうち完了した数です。部署は作業の部署で、上位の部署のものも含みます。部署を選ぶと、部署が未定の作業は出ません。</p>
            </div>
            <v-btn variant="text" color="primary" size="small" :to="listLink('/maintenances', { status: 'in_progress' }, false)" append-icon="mdi-chevron-right">定期整備の一覧</v-btn>
          </header>
          <template v-if="board.maintenances.length">
            <article v-for="maintenance in board.maintenances" :key="maintenance.id" class="pk-board-maintenance" :data-testid="`board-maintenance-${maintenance.id}`">
              <div class="pk-board-maintenance__head">
                <router-link :to="`/maintenances/${maintenance.id}`"><strong>{{ maintenance.title }}</strong></router-link>
                <span>{{ maintenance.site.name }} ／ 予定 {{ periodLabel(maintenance.planned_start_on, maintenance.planned_end_on) }}</span>
                <span class="pk-board-maintenance__progress">
                  完了 {{ maintenance.completed_count }} / {{ maintenance.task_count }}
                  <v-progress-linear :model-value="maintenance.task_count ? (maintenance.completed_count / maintenance.task_count) * 100 : 0" color="success" height="6" rounded aria-hidden="true" />
                </span>
              </div>
              <div v-if="maintenance.open_tasks.length" class="pk-board-table">
                <v-table density="compact">
                  <thead>
                    <tr><th>部署</th><th>作業</th><th>担当</th><th>状態</th><th>備考</th></tr>
                  </thead>
                  <tbody>
                    <tr v-for="task in maintenance.open_tasks" :key="task.id" :data-testid="`board-task-${task.id}`">
                      <td class="text-no-wrap">{{ task.department?.name ?? '未定' }}</td>
                      <td><v-chip size="x-small" label variant="tonal" class="mr-1">{{ TASK_KIND_LABEL[task.kind] }}</v-chip>{{ task.title }}</td>
                      <td class="text-no-wrap">{{ task.assigned_to?.name ?? '—' }}</td>
                      <td><v-chip :color="TASK_STATUS_COLOR[task.status]" size="small" label variant="flat">{{ TASK_STATUS_LABEL[task.status] }}</v-chip></td>
                      <td class="pk-board-table__notes">{{ task.notes ?? '' }}</td>
                    </tr>
                  </tbody>
                </v-table>
              </div>
              <p v-else class="pk-board-empty">範囲の作業はすべて済んでいます。</p>
            </article>
          </template>
          <p v-else class="pk-board-empty">実施中の定期整備に、範囲の作業はありません。</p>
        </section>

        <section class="pk-board-section" aria-labelledby="board-trouble-title" data-testid="board-troubles">
          <header class="pk-board-section__header">
            <div>
              <h2 id="board-trouble-title">未対応・対応中のトラブル<small>{{ board.troubles.total_count }}件</small></h2>
              <p>緊急を先頭に優先度の順、同じ優先度は報告の古い順です。部署は報告者・担当者の所属で、配下を含みます。</p>
            </div>
            <v-btn variant="text" color="primary" size="small" :to="listLink('/troubles', { status: 'open,in_progress' })" append-icon="mdi-chevron-right">トラブルの一覧</v-btn>
          </header>
          <div v-if="board.troubles.items.length" class="pk-board-table">
            <v-table density="compact">
              <thead>
                <tr><th>優先度</th><th>状態</th><th>トラブル</th><th>設備・計器</th><th>担当</th><th>報告</th></tr>
              </thead>
              <tbody>
                <tr v-for="trouble in board.troubles.items" :key="trouble.id" :data-testid="`board-trouble-${trouble.id}`">
                  <td><v-chip :color="priorityColor[trouble.priority]" size="small" label variant="flat">{{ priorityLabel[trouble.priority] }}</v-chip></td>
                  <td><v-chip :color="troubleStatusColor[trouble.status]" size="small" label variant="tonal">{{ troubleStatusLabel[trouble.status] }}</v-chip></td>
                  <td><router-link :to="`/troubles/${trouble.id}`">{{ trouble.title }}</router-link></td>
                  <td>{{ trouble.equipment.name }}<template v-if="trouble.instrument"> ／ {{ trouble.instrument.tag_number }}</template></td>
                  <td class="text-no-wrap">{{ trouble.assigned_to?.name ?? '未定' }}</td>
                  <td class="text-no-wrap">{{ shortDate(trouble.reported_at) }}</td>
                </tr>
              </tbody>
            </v-table>
          </div>
          <p v-else class="pk-board-empty">未対応・対応中のトラブルはありません。</p>
          <p v-if="board.troubles.total_count > board.troubles.items.length" class="pk-board-more">
            ほか{{ board.troubles.total_count - board.troubles.items.length }}件は、トラブルの一覧で確認してください。
          </p>
        </section>
      </template>
    </div>
  </MainLayout>
</template>

<style scoped>
.pk-board { max-width: 1240px; margin-inline: auto; }
.pk-board-loading { margin-top: 28px; min-height: 240px; }
.pk-board__day { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 28px; margin: 20px 0 16px; }
.pk-board__day p { display: flex; align-items: baseline; gap: 8px; }
.pk-board__day span { color: var(--pk-muted); font-size: 0.75rem; }
.pk-board__day strong { font-family: var(--pk-font-display); font-size: 1.125rem; font-variant-numeric: tabular-nums; }
.pk-board__scope strong { font-size: 0.9375rem; }
.pk-board-section { margin-bottom: 20px; overflow: hidden; border: 1px solid var(--pk-line); border-radius: 16px; background: #fff; }
.pk-board-section__header { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 16px 24px; border-bottom: 1px solid var(--pk-line); }
.pk-board-section__header > .v-btn { flex: none; }
h2 { font-family: var(--pk-font-display); font-size: 1.0625rem; line-height: 1.5; }
h2 small, h3 small { margin-left: 8px; color: var(--pk-muted); font-size: 0.75rem; font-weight: 400; font-variant-numeric: tabular-nums; }
.pk-board-section__header p { max-width: 60em; margin-top: 4px; color: var(--pk-muted); font-size: 0.75rem; line-height: 1.6; text-wrap: pretty; }
.pk-board-empty { padding: 16px 24px; color: var(--pk-muted); font-size: 0.8125rem; }
.pk-board-more { padding: 0 24px 16px; color: var(--pk-muted); font-size: 0.75rem; }
.pk-board-list { padding: 0 24px; list-style: none; }
.pk-board-list li + li { border-top: 1px solid var(--pk-line); }
.pk-board-list a { display: flex; align-items: center; gap: 16px; padding: 12px 0; color: var(--pk-ink); text-decoration: none; }
.pk-board-list a:hover strong { color: var(--pk-steel); text-decoration: underline; }
.pk-board-list a > .v-icon { flex: none; color: var(--pk-muted); }
.pk-board-list__copy { display: grid; flex: 1; min-width: 0; gap: 2px; }
.pk-board-list__copy strong { font-size: 0.875rem; font-weight: 500; overflow-wrap: anywhere; }
.pk-board-list__copy > span { color: var(--pk-muted); font-size: 0.75rem; }
.pk-board-list__alert .pk-board-list__copy > span { color: rgb(var(--v-theme-error)); }
.pk-board-plans { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); }
.pk-board-plans__group { min-width: 0; padding: 12px 20px 8px; }
.pk-board-plans__group + .pk-board-plans__group { border-left: 1px solid var(--pk-line); }
.pk-board-plans__group h3 { font-size: 0.8125rem; color: var(--pk-steel-dark); }
.pk-board-plans__alert { color: rgb(var(--v-theme-error)) !important; }
.pk-board-plans__group .pk-board-empty { padding: 8px 0; }
.pk-board-plans__items { padding: 0; list-style: none; }
.pk-board-plans__items li { display: flex; align-items: center; gap: 12px; padding: 10px 0; }
.pk-board-plans__items li + li { border-top: 1px solid var(--pk-line); }
.pk-board-plans__items .v-btn { flex: none; }
.pk-board-plans__copy { display: grid; flex: 1; min-width: 0; gap: 2px; }
.pk-board-plans__copy strong { font-size: 0.875rem; font-weight: 500; overflow-wrap: anywhere; }
.pk-board-plans__copy span { color: var(--pk-muted); font-size: 0.75rem; overflow-wrap: anywhere; }
.pk-board-maintenance + .pk-board-maintenance { border-top: 1px solid var(--pk-line); }
.pk-board-maintenance__head { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 16px; padding: 12px 24px 4px; font-size: 0.8125rem; }
.pk-board-maintenance__head a { color: var(--pk-ink); }
.pk-board-maintenance__head > span { color: var(--pk-muted); }
.pk-board-maintenance__progress { display: grid; gap: 4px; min-width: 140px; margin-left: auto; font-variant-numeric: tabular-nums; }
.pk-board-table { overflow-x: auto; padding: 0 12px 8px; }
.pk-board-table :deep(td), .pk-board-table :deep(th) { font-size: 0.8125rem; }
.pk-board-table :deep(th) { white-space: nowrap; }
/* 狭い画面では列を潰さず、表の中だけを横にスクロールする（デザインガイド） */
.pk-board-table :deep(table) { min-width: 720px; }
.pk-board-table a { color: var(--pk-steel); }
.pk-board-table__notes { min-width: 200px; color: var(--pk-muted); }
a:focus-visible { outline: 2px solid var(--pk-steel); outline-offset: 2px; }
@media (max-width: 960px) {
  .pk-board-plans { grid-template-columns: 1fr; }
  .pk-board-plans__group + .pk-board-plans__group { border-left: 0; border-top: 1px solid var(--pk-line); }
}
@media (max-width: 600px) {
  .pk-board-section__header { flex-wrap: wrap; align-items: start; gap: 8px; padding: 14px 16px; }
  .pk-board-section__header > .v-btn { margin-left: -8px; }
  .pk-board-list, .pk-board-empty { padding-inline: 16px; }
  .pk-board-plans__group { padding-inline: 16px; }
  .pk-board-plans__items li { flex-wrap: wrap; }
  .pk-board-maintenance__head { padding-inline: 16px; }
  .pk-board-maintenance__progress { margin-left: 0; width: 100%; }
  .pk-board-table { padding-inline: 4px; }
}
</style>
