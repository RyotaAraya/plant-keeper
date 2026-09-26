<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
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
import { inspectionStatusColor, inspectionStatusLabel, priorityColor, priorityLabel, responseTypeLabel, troubleStatusColor, troubleStatusLabel } from '@/constants/recordLabels'
import { TASK_KIND_LABEL, TASK_STATUS_COLOR, TASK_STATUS_LABEL, periodLabel } from '@/constants/maintenanceStatus'
import type { DashboardScope, MeetingBoard, MeetingBoardInspection, MeetingBoardPlan } from '@/types/models'

// 朝会・夕会ボード: 今日・明日の予定を、拠点・部署で絞って1枚にまとめる（要求仕様書 2.8）。
// 範囲の選び方はダッシュボードと同じ（初期値は本人の所属。部署のない人は拠点全体）。
// 朝会（今日・明日の予定）と夕会（今日の実績と積み残し）は、URLの ?mode=evening で切り替える（再読み込み・印刷でも保つ）
const route = useRoute()
const router = useRouter()
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
    { key: 'today', label: evening.value ? '今日が期限（未実施）' : '今日が期限', plans: plans.filter((p) => p.days_until_due === 0) },
    { key: 'tomorrow', label: '明日が期限', plans: plans.filter((p) => p.days_until_due === 1) },
  ]
})
const openTaskCount = computed(() => board.value?.maintenances.reduce((sum, m) => sum + m.open_tasks.length, 0) ?? 0)

type Mode = 'morning' | 'evening'
const mode = computed<Mode>(() => (route.query.mode === 'evening' ? 'evening' : 'morning'))
const evening = computed(() => mode.value === 'evening')
function setMode(value: Mode) {
  void router.replace({ query: { ...route.query, mode: value === 'evening' ? 'evening' : undefined } })
}

// 夕会: 点検日が今日の点検を、提出したもの（実績）と下書きのまま（積み残し）に分ける
const submittedInspections = computed(() => board.value?.results.inspections.filter((i) => i.status !== 'draft') ?? [])
const draftInspections = computed(() => board.value?.results.inspections.filter((i) => i.status === 'draft') ?? [])

function inspectionTarget(inspection: MeetingBoardInspection) {
  const names = equipmentNames(inspection)
  return inspection.instrument ? `${names} ／ ${inspection.instrument.tag_number}` : names
}

// 「14:05」
function timeLabel(value: string) {
  return new Date(value).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })
}

// 紙に出した時刻（印刷のときだけ見せる。いつ時点の内容かを紙で分かるように）。
// ボタンだけでなくブラウザの印刷（Ctrl+P）でも入るよう、beforeprint で決める
const printedAt = ref('')
function stampPrintedAt() {
  printedAt.value = new Date().toLocaleString('ja-JP', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })
}
onMounted(() => window.addEventListener('beforeprint', stampPrintedAt))
onUnmounted(() => window.removeEventListener('beforeprint', stampPrintedAt))
function printBoard() {
  window.print()
}

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
      <PageHeader title="朝会・夕会ボード" description="今日・明日の予定と、進んでいる作業を1枚で確認します。夕会では、今日の実績と積み残しを出します。">
        <v-btn class="pk-no-print" variant="outlined" prepend-icon="mdi-printer-outline" :disabled="!board" data-testid="board-print" @click="printBoard">印刷</v-btn>
      </PageHeader>
      <v-btn-toggle
        :model-value="mode"
        class="pk-board__modes pk-no-print"
        color="primary"
        variant="outlined"
        density="comfortable"
        mandatory
        divided
        aria-label="朝会と夕会の切り替え"
        @update:model-value="setMode"
      >
        <v-btn value="morning" data-testid="board-mode-morning">朝会（今日・明日の予定）</v-btn>
        <v-btn value="evening" data-testid="board-mode-evening">夕会（今日の実績と積み残し）</v-btn>
      </v-btn-toggle>
      <DashboardOrganizationScope v-model="scope" class="pk-no-print" />

      <div v-if="error" class="mt-5">
        <v-alert type="error" variant="tonal" role="alert">{{ error }}</v-alert>
        <v-btn class="mt-3" variant="outlined" @click="fetchBoard">再読み込み</v-btn>
      </div>
      <div v-else-if="loading && !board" class="pk-board-loading" role="status" aria-label="ボードを読み込み中">
        <v-progress-linear indeterminate color="primary" />
      </div>
      <template v-else-if="board">
        <div class="pk-board__day" data-testid="board-day">
          <p class="pk-board__mode"><strong>{{ evening ? '夕会' : '朝会' }}</strong></p>
          <p><span>今日</span><strong>{{ dayLabel(board.today) }}</strong></p>
          <p><span>明日</span><strong>{{ dayLabel(board.tomorrow) }}</strong></p>
          <p class="pk-board__scope"><span>範囲</span><strong>{{ board.scope.site_name ?? '全拠点' }} {{ scopeName }}</strong></p>
          <v-progress-circular v-if="loading" indeterminate size="18" width="2" color="primary" aria-label="更新中" />
          <p class="pk-board__printed"><span>出力</span><strong>{{ printedAt }}</strong></p>
        </div>

        <!-- 安全に関わるため先頭。部署で絞らず拠点全体 -->
        <section class="pk-board-section" aria-labelledby="board-bypass-title" data-testid="board-bypasses">
          <header class="pk-board-section__header">
            <div>
              <h2 id="board-bypass-title">インターロックのバイパス<small>{{ board.interlock_bypasses.length }}件</small></h2>
              <p>{{ siteName }}の、バイパス中と復帰確認待ちです。安全に関わるため、部署の選択にかかわらず表示します。<template v-if="evening">戻していないものは、次の直へ引き継ぎます。</template></p>
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

        <!-- 夕会: 今日の実績。下書きのままの点検は積み残しとして分ける -->
        <section v-if="evening" class="pk-board-section" aria-labelledby="board-result-title" data-testid="board-results">
          <header class="pk-board-section__header">
            <div>
              <h2 id="board-result-title">今日の実績<small>{{ submittedInspections.length + board.results.trouble_responses.length + board.results.completed_tasks.length }}件</small></h2>
              <p>点検日が今日で提出した点検（提出した日時は記録していないため、点検日で数えます）、今日記録された対応記録、今日完了した定期整備の作業です。点検は記録の部署、対応記録は記録した人の所属（どちらも配下を含む）、作業は作業の部署（上位の部署を含む）で絞ります。</p>
            </div>
          </header>
          <div class="pk-board-plans">
            <div class="pk-board-plans__group" data-testid="board-results-inspections">
              <h3>提出した点検<small>{{ submittedInspections.length }}件</small></h3>
              <ul v-if="submittedInspections.length" class="pk-board-plans__items">
                <li v-for="inspection in submittedInspections" :key="inspection.id" :data-testid="`board-result-inspection-${inspection.id}`">
                  <div class="pk-board-plans__copy">
                    <strong><router-link :to="`/inspections/${inspection.id}`">{{ inspection.checklist_template?.name ?? '点検' }}</router-link></strong>
                    <span>{{ inspectionTarget(inspection) }}</span>
                    <span>{{ inspection.user.name }} ／ {{ inspection.department.name }} ／ {{ timeLabel(inspection.inspected_at) }}</span>
                  </div>
                  <v-chip :color="inspectionStatusColor[inspection.status]" size="small" label variant="tonal">{{ inspectionStatusLabel[inspection.status] }}</v-chip>
                </li>
              </ul>
              <p v-else class="pk-board-empty">ありません。</p>
            </div>
            <div class="pk-board-plans__group" data-testid="board-results-responses">
              <h3>記録した対応<small>{{ board.results.trouble_responses.length }}件</small></h3>
              <ul v-if="board.results.trouble_responses.length" class="pk-board-plans__items">
                <li v-for="response in board.results.trouble_responses" :key="response.id" :data-testid="`board-result-response-${response.id}`">
                  <div class="pk-board-plans__copy">
                    <strong><router-link :to="`/troubles/${response.trouble.id}`">{{ response.trouble.title }}</router-link></strong>
                    <span>{{ responseTypeLabel[response.response_type] ?? response.response_type }}：{{ response.description }}</span>
                    <span>{{ response.user.name }} ／ {{ timeLabel(response.responded_at) }} ／ トラブルは{{ troubleStatusLabel[response.trouble.status] }}</span>
                  </div>
                </li>
              </ul>
              <p v-else class="pk-board-empty">ありません。</p>
            </div>
            <div class="pk-board-plans__group" data-testid="board-results-tasks">
              <h3>完了した作業<small>{{ board.results.completed_tasks.length }}件</small></h3>
              <ul v-if="board.results.completed_tasks.length" class="pk-board-plans__items">
                <li v-for="task in board.results.completed_tasks" :key="task.id" :data-testid="`board-result-task-${task.id}`">
                  <div class="pk-board-plans__copy">
                    <strong>{{ task.title }}</strong>
                    <span><router-link :to="`/maintenances/${task.scheduled_maintenance.id}`">{{ task.scheduled_maintenance.title }}</router-link></span>
                    <span>{{ task.department?.name ?? '部署未定' }} ／ {{ task.assigned_to?.name ?? '担当未定' }}</span>
                  </div>
                </li>
              </ul>
              <p v-else class="pk-board-empty">ありません。</p>
            </div>
          </div>
          <div v-if="draftInspections.length" class="pk-board-drafts" data-testid="board-results-drafts">
            <h3><v-icon size="18" aria-hidden="true">mdi-alert-outline</v-icon>提出していない点検（下書きのまま）<small>{{ draftInspections.length }}件</small></h3>
            <ul class="pk-board-plans__items">
              <li v-for="inspection in draftInspections" :key="inspection.id" :data-testid="`board-draft-inspection-${inspection.id}`">
                <div class="pk-board-plans__copy">
                  <strong>{{ inspection.checklist_template?.name ?? '点検' }}</strong>
                  <span>{{ inspectionTarget(inspection) }} ／ {{ inspection.user.name }} ／ {{ inspection.department.name }}</span>
                </div>
                <v-btn size="small" variant="outlined" :to="`/inspections/${inspection.id}/edit`">開く</v-btn>
              </li>
            </ul>
          </div>
        </section>

        <section class="pk-board-section" aria-labelledby="board-plan-title" data-testid="board-plans">
          <header class="pk-board-section__header">
            <div>
              <h2 id="board-plan-title">{{ evening ? '点検計画（積み残しと明日の予定）' : '点検計画' }}<small>{{ board.inspection_plans.length }}件</small></h2>
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
              <h2 id="board-task-title">{{ evening ? '積み残しの作業（実施中の定期整備）' : '実施中の定期整備の作業' }}<small>残り{{ openTaskCount }}件</small></h2>
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
              <h2 id="board-trouble-title">{{ evening ? '積み残しのトラブル（未対応・対応中）' : '未対応・対応中のトラブル' }}<small>{{ board.troubles.total_count }}件</small></h2>
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
.pk-board__modes { margin-bottom: 16px; flex-wrap: wrap; height: auto !important; }
.pk-board__mode strong { padding: 2px 10px; border-radius: 6px; background: var(--pk-soft-blue); color: var(--pk-steel-dark); font-size: 0.9375rem !important; }
.pk-board-drafts { margin: 0 20px 16px; padding: 12px 16px 4px; border: 1px solid rgb(var(--v-theme-warning)); border-radius: 12px; background: rgba(var(--v-theme-warning), 0.06); }
.pk-board-drafts h3 { display: flex; align-items: center; gap: 6px; font-size: 0.8125rem; color: var(--pk-ink); }
.pk-board-drafts .v-icon { color: rgb(var(--v-theme-warning)); }
.pk-board-plans__copy a { color: var(--pk-ink); }
.pk-board__day { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 28px; margin: 20px 0 16px; }
.pk-board__day p { display: flex; align-items: baseline; gap: 8px; }
.pk-board__day span { color: var(--pk-muted); font-size: 0.75rem; }
.pk-board__day strong { font-family: var(--pk-font-display); font-size: 1.125rem; font-variant-numeric: tabular-nums; }
.pk-board__scope strong { font-size: 0.9375rem; }
.pk-board__printed { display: none !important; }
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
/* 印刷（会議で紙に出す）: 操作と長い説明を消し、行の途中でページを分けない。表は横スクロールさせず紙の幅に収める */
@media print {
  .pk-board { max-width: none; }
  .pk-board :deep(.pk-page-header__desc), .pk-board-section__header p, .pk-board-section__header > .v-btn,
  .pk-board-plans__items .v-btn, .pk-board-drafts .v-btn, .pk-board-list a > .v-icon { display: none !important; }
  .pk-board__day { margin: 0 0 8px; }
  .pk-board__printed { display: flex !important; }
  /* 紙の幅（A4）では画面の狭い幅の1列になるため、3列に戻して紙を節約する */
  .pk-board-plans { grid-template-columns: repeat(3, minmax(0, 1fr)) !important; }
  .pk-board-plans__group + .pk-board-plans__group { border-top: 0 !important; border-left: 1px solid var(--pk-line) !important; }
  .pk-board-section { margin-bottom: 10px; border-radius: 6px; break-inside: auto; }
  .pk-board-section__header { padding: 6px 12px; break-after: avoid; }
  .pk-board-list, .pk-board-empty, .pk-board-more { padding-inline: 12px; }
  .pk-board-list a { padding: 4px 0; }
  .pk-board-plans__group { padding: 6px 12px 4px; }
  .pk-board-plans__items li { padding: 4px 0; }
  .pk-board-maintenance__head { padding: 6px 12px 2px; }
  .pk-board-table { overflow: visible; padding: 0 4px 4px; }
  .pk-board-table :deep(table) { min-width: 0; }
  .pk-board-table :deep(td), .pk-board-table :deep(th) { height: auto !important; padding: 3px 6px !important; font-size: 0.75rem; }
  .pk-board-table__notes { min-width: 0; }
  li, tr, .pk-board-maintenance__head { break-inside: avoid; }
  a { color: inherit !important; text-decoration: none !important; }
}
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
