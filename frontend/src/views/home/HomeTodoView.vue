<script setup lang="ts">
// ホーム（やること）: ログインした人の所属のチーム → 課 → 部ごとに、今日やることを1本のリストで出す（要求仕様書 2.8）。
// 各エリアには、その部署に直接割り当てたものだけが出る（配下・上位を混ぜない）。バイパスは拠点全体として先頭。
// 管理者・マネージャーは承認待ちを先頭に、運転員は不具合の報告と自分の報告の状況を出す。
// 朝会（今日・明日）と夕会（今日の実績と積み残し）は、URLの ?mode=evening で切り替える（再読み込み・印刷でも保つ）
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import StatusChip from '@/components/StatusChip.vue'
import { usePermissions } from '@/composables/usePermissions'
import { TASK_KIND_LABEL } from '@/constants/maintenanceStatus'
import { responseTypeLabel, troubleStatusLabel } from '@/constants/recordLabels'
import { useAuthStore } from '@/stores/auth'
import type { HomeArea, HomeBoard, HomeInspection, HomePlan, HomeTask, HomeTrouble } from '@/types/models'
import { equipmentNames } from '@/utils/equipment'
import { inspectionFromPlan, referenceStandardFromPlan } from '@/utils/inspectionPlan'
import { bypassColor, bypassLabel, formatHours, restoreDueLabel } from '@/utils/interlock'
import { latestGuard } from '@/utils/latestGuard'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { canManageReferenceStandard } = usePermissions()

const board = ref<HomeBoard | null>(null)
const loading = ref(true)
const error = ref('')
const siteId = ref<number | null>(authStore.user?.site_id ?? null)
const fetchGuard = latestGuard()

const evening = computed(() => route.query.mode === 'evening')
function setMode(value: string) {
  void router.replace({ query: { ...route.query, mode: value === 'evening' ? 'evening' : undefined } })
}

// --- やること（1本のリスト） ---
// 並び: 期限超過・緊急 → 今日・高・実施中 → そのほか → 明日が期限
type Todo =
  | { key: string; kind: 'plan'; rank: number; plan: HomePlan }
  | { key: string; kind: 'task'; rank: number; task: HomeTask }
  | { key: string; kind: 'trouble'; rank: number; trouble: HomeTrouble }
const TODO_LABEL = { plan: '点検', task: '作業', trouble: 'トラブル' } as const
const TODO_COLOR = { plan: 'primary', task: 'deep-purple', trouble: 'error' } as const

function planRank(plan: HomePlan) {
  if (plan.days_until_due < 0) return 0
  return plan.days_until_due === 0 ? 1 : 3
}
function troubleRank(trouble: HomeTrouble) {
  if (trouble.priority === 'critical') return 0
  return trouble.priority === 'high' ? 1 : 2
}

function todosOf(area: HomeArea): Todo[] {
  const todos: Todo[] = [
    ...area.inspection_plans.map((plan) => ({ key: `plan-${plan.id}`, kind: 'plan' as const, rank: planRank(plan), plan })),
    ...area.maintenance_tasks.map((task) => ({ key: `task-${task.id}`, kind: 'task' as const, rank: task.status === 'in_progress' ? 1 : 2, task })),
    ...area.troubles.items.map((trouble) => ({ key: `trouble-${trouble.id}`, kind: 'trouble' as const, rank: troubleRank(trouble), trouble })),
  ]
  return todos.sort((a, b) => a.rank - b.rank)
}

// 夕会: 明日が期限の計画は「明日の予定」として分け、残りを積み残しにする
const areas = computed(() =>
  (board.value?.areas ?? []).map((area) => {
    const todos = todosOf(area)
    const inspections = area.results.inspections
    return {
      area,
      key: area.department ? `department-${area.department.id}` : 'site',
      todos,
      remaining: todos.filter((todo) => todo.rank < 3),
      tomorrow: todos.filter((todo) => todo.rank === 3),
      submitted: inspections.filter((i) => i.status !== 'draft'),
      drafts: inspections.filter((i) => i.status === 'draft'),
    }
  }),
)

const LEVEL_LABEL: Record<string, string> = { team: 'チーム', section: '課', division: '部' }
function areaTitle(area: HomeArea) {
  return area.department ? area.department.name : `${board.value?.site.name ?? ''}全体`
}

function planTarget(plan: HomePlan) {
  if (plan.reference_standard) return plan.reference_standard.name
  const names = equipmentNames(plan)
  return plan.instrument ? `${names} ／ ${plan.instrument.tag_number}` : names
}
function dueText(plan: HomePlan) {
  if (plan.days_until_due < 0) return `${-plan.days_until_due}日超過`
  return plan.days_until_due === 0 ? '今日' : '明日'
}
function inspectionTarget(inspection: HomeInspection) {
  const names = equipmentNames(inspection)
  return inspection.instrument ? `${names} ／ ${inspection.instrument.tag_number}` : names
}
function troubleTarget(trouble: HomeTrouble) {
  return trouble.instrument ? `${trouble.equipment.name} ／ ${trouble.instrument.tag_number}` : trouble.equipment.name
}

// 「14:05」
function timeLabel(value: string) {
  return new Date(value).toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })
}
// 「9月26日（土）」
function dayLabel(date: string | undefined) {
  if (!date) return ''
  return new Date(`${date}T00:00:00+09:00`).toLocaleDateString('ja-JP', { month: 'long', day: 'numeric', weekday: 'short', timeZone: 'Asia/Tokyo' })
    .replace(/\((.)\)/, '（$1）')
}

// 紙に出した時刻（印刷のときだけ見せる）。ボタンだけでなくブラウザの印刷（Ctrl+P）でも入るよう、beforeprint で決める
const printedAt = ref('')
function stampPrintedAt() {
  printedAt.value = new Date().toLocaleString('ja-JP', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })
}
onMounted(() => window.addEventListener('beforeprint', stampPrintedAt))
function printHome() {
  window.print()
}
onUnmounted(() => window.removeEventListener('beforeprint', stampPrintedAt))

async function fetchBoard() {
  const isLatest = fetchGuard()
  loading.value = true
  error.value = ''
  try {
    const res = await api.get<{ data: HomeBoard }>('/home', { params: siteId.value ? { site_id: siteId.value } : {} })
    if (isLatest()) board.value = res.data.data
  } catch {
    if (isLatest()) error.value = 'ホームを読み込めませんでした。再読み込みしてください。'
  } finally {
    if (isLatest()) loading.value = false
  }
}

watch(siteId, fetchBoard, { immediate: true })
</script>

<template>
  <MainLayout>
    <div class="pk-home">
      <PageHeader title="ホーム" :description="evening ? '今日の実績と積み残しです。' : '今日やることです。'">
        <v-btn class="pk-no-print" variant="text" color="primary" prepend-icon="mdi-robot-happy-outline" to="/plana">プラナを開く</v-btn>
        <v-btn class="pk-no-print" variant="outlined" prepend-icon="mdi-printer-outline" :disabled="!board" data-testid="home-print" @click="printHome">印刷</v-btn>
      </PageHeader>

      <!-- 一覧と同じ絞り込みの行: 左端に拠点（1つだけ選ぶ。協力会社は所属拠点の表示だけ）、朝会・夕会の切り替え -->
      <div class="pk-filters">
        <SiteScopeTag :model-value="siteId ? [siteId] : []" single class="pk-no-print" @update:model-value="siteId = $event[0] ?? null" />
        <v-divider vertical class="pk-scope-divider pk-no-print" />
        <v-btn-toggle
          :model-value="evening ? 'evening' : 'morning'"
          class="pk-no-print"
          color="primary"
          variant="outlined"
          density="compact"
          mandatory
          divided
          aria-label="朝会と夕会の切り替え"
          @update:model-value="setMode"
        >
          <v-btn value="morning" data-testid="home-mode-morning">朝会</v-btn>
          <v-btn value="evening" data-testid="home-mode-evening">夕会</v-btn>
        </v-btn-toggle>
        <v-spacer />
        <p class="pk-home__day" data-testid="home-day">
          <strong>{{ evening ? '夕会' : '朝会' }}</strong>
          <span>{{ board?.site.name }}</span>
          <span>{{ dayLabel(board?.today) }}</span>
          <span class="pk-home__printed">出力 {{ printedAt }}</span>
          <v-progress-circular v-if="loading && board" indeterminate size="16" width="2" color="primary" aria-label="更新中" />
        </p>
      </div>

      <div v-if="error" class="mt-4">
        <v-alert type="error" variant="tonal" role="alert">{{ error }}</v-alert>
        <v-btn class="mt-3" variant="outlined" @click="fetchBoard">再読み込み</v-btn>
      </div>
      <v-progress-linear v-else-if="loading && !board" indeterminate color="primary" class="mt-6" aria-label="ホームを読み込み中" />
      <template v-else-if="board">
        <!-- 運転員: 不具合の報告（点検フォームの不具合欄から報告すると、トラブルに自動で登録される） -->
        <section v-if="board.kind === 'operator'" class="pk-home-report pk-no-print" data-testid="home-report">
          <v-btn color="error" size="large" prepend-icon="mdi-alert-plus-outline" :to="{ path: '/inspections/new', query: { inspection_type: 'operation_check' } }">不具合を報告する</v-btn>
          <v-btn variant="text" color="primary" :to="{ path: '/plana', query: { task: 'defect-draft' } }">プラナに整えてもらう</v-btn>
        </section>

        <!-- 管理者・マネージャー: 承認待ち -->
        <section v-if="board.approvals" class="pk-home-section" aria-labelledby="home-approvals-title" data-testid="home-approvals">
          <h2 id="home-approvals-title">承認待ち<small>{{ board.approvals.inspections.length + board.approvals.interlock_bypasses.length }}件</small></h2>
          <ul v-if="board.approvals.inspections.length || board.approvals.interlock_bypasses.length" class="pk-home-list">
            <li v-for="bypass in board.approvals.interlock_bypasses" :key="`bypass-${bypass.id}`">
              <v-chip size="x-small" label color="warning" variant="tonal">バイパス申請</v-chip>
              <div class="pk-home-list__copy">
                <router-link :to="`/interlocks/${bypass.interlock.id}`"><strong>{{ bypass.interlock.tag_number }} {{ bypass.interlock.name }}</strong></router-link>
                <span>{{ bypass.interlock.equipment.name }} ／ {{ bypass.requested_by?.name ?? '—' }}の申請 ／ {{ bypass.reason }}</span>
              </div>
            </li>
            <li v-for="inspection in board.approvals.inspections" :key="`inspection-${inspection.id}`">
              <v-chip size="x-small" label color="warning" variant="tonal">点検の承認</v-chip>
              <div class="pk-home-list__copy">
                <router-link :to="`/inspections/${inspection.id}`"><strong>{{ inspection.checklist_template?.name ?? '点検' }}</strong></router-link>
                <span>{{ inspectionTarget(inspection) }} ／ {{ inspection.user.name }}</span>
              </div>
            </li>
          </ul>
          <p v-else class="pk-home-empty">承認待ちはありません。</p>
        </section>

        <!-- インターロックのバイパス（安全に関わるため、エリアに分けず拠点全体。バイパスがなければ出さない） -->
        <section v-if="board.interlock_bypasses.length" class="pk-home-section pk-home-section--alert" aria-labelledby="home-bypass-title" data-testid="home-bypasses">
          <h2 id="home-bypass-title">インターロックのバイパス<small>{{ board.site.name }}全体・{{ board.interlock_bypasses.length }}件</small></h2>
          <ul class="pk-home-list">
            <li v-for="bypass in board.interlock_bypasses" :key="bypass.id" :class="{ 'pk-home-list__alert': bypass.overdue }">
              <StatusChip :label="bypassLabel(bypass)" :color="bypassColor(bypass)" :alert="bypass.overdue" />
              <div class="pk-home-list__copy">
                <router-link :to="`/interlocks/${bypass.interlock.id}`"><strong>{{ bypass.interlock.tag_number }} {{ bypass.interlock.name }}</strong></router-link>
                <span v-if="bypass.status === 'bypassed'">{{ bypass.interlock.equipment.name }} ／ {{ formatHours(bypass.bypassed_hours) }}経過 ／ 予定の復帰まで{{ restoreDueLabel(bypass) }}</span>
                <span v-else>{{ bypass.interlock.equipment.name }} ／ {{ bypass.restored_by?.name ?? '—' }}が復帰。別の人の確認待ち</span>
              </div>
            </li>
          </ul>
        </section>

        <!-- 運転員: 自分が報告したトラブル -->
        <section v-if="board.my_troubles" class="pk-home-section" aria-labelledby="home-my-troubles-title" data-testid="home-my-troubles">
          <h2 id="home-my-troubles-title">自分が報告したトラブル<small>{{ board.my_troubles.length }}件</small></h2>
          <ul v-if="board.my_troubles.length" class="pk-home-list">
            <li v-for="trouble in board.my_troubles" :key="trouble.id">
              <StatusChip kind="trouble" :value="trouble.status" />
              <div class="pk-home-list__copy">
                <router-link :to="`/troubles/${trouble.id}`"><strong>{{ trouble.title }}</strong></router-link>
                <span>{{ troubleTarget(trouble) }} ／ 担当 {{ trouble.assigned_to?.name ?? '未定' }}</span>
              </div>
            </li>
          </ul>
          <p v-else class="pk-home-empty">完了していない報告はありません。</p>
        </section>

        <!-- 所属のエリア（チーム → 課 → 部。部署のない人は拠点全体） -->
        <section
          v-for="entry in areas"
          :key="entry.key"
          class="pk-home-section"
          :aria-labelledby="`home-area-${entry.key}`"
          :data-testid="`home-area-${entry.area.department?.name ?? 'site'}`"
        >
          <h2 :id="`home-area-${entry.key}`">
            {{ areaTitle(entry.area) }}
            <v-chip v-if="entry.area.department" size="x-small" label variant="tonal" class="ml-2">{{ LEVEL_LABEL[entry.area.department.level] }}</v-chip>
            <small>{{ evening ? `積み残し ${entry.remaining.length + entry.drafts.length}件` : `${entry.todos.length}件` }}</small>
          </h2>

          <!-- 夕会: 今日の実績 -->
          <div v-if="evening" class="pk-home-results" data-testid="home-results">
            <h3>今日の実績<small>{{ entry.submitted.length + entry.area.results.trouble_responses.length + entry.area.results.completed_tasks.length }}件</small></h3>
            <ul v-if="entry.submitted.length || entry.area.results.trouble_responses.length || entry.area.results.completed_tasks.length" class="pk-home-list">
              <li v-for="inspection in entry.submitted" :key="`i-${inspection.id}`" :data-testid="`home-result-inspection-${inspection.id}`">
                <StatusChip kind="inspection" :value="inspection.status" />
                <div class="pk-home-list__copy">
                  <router-link :to="`/inspections/${inspection.id}`"><strong>{{ inspection.checklist_template?.name ?? '点検' }}</strong></router-link>
                  <span>{{ inspectionTarget(inspection) }} ／ {{ inspection.user.name }} ／ {{ timeLabel(inspection.inspected_at) }}</span>
                </div>
              </li>
              <li v-for="response in entry.area.results.trouble_responses" :key="`r-${response.id}`" :data-testid="`home-result-response-${response.id}`">
                <v-chip size="x-small" label variant="tonal">対応記録</v-chip>
                <div class="pk-home-list__copy">
                  <router-link :to="`/troubles/${response.trouble.id}`"><strong>{{ response.trouble.title }}</strong></router-link>
                  <span>{{ responseTypeLabel[response.response_type] ?? response.response_type }}：{{ response.description }} ／ {{ response.user.name }}</span>
                </div>
              </li>
              <li v-for="task in entry.area.results.completed_tasks" :key="`t-${task.id}`" :data-testid="`home-result-task-${task.id}`">
                <v-chip size="x-small" label color="success" variant="tonal">作業完了</v-chip>
                <div class="pk-home-list__copy">
                  <strong>{{ task.title }}</strong>
                  <span><router-link :to="`/maintenances/${task.scheduled_maintenance.id}`">{{ task.scheduled_maintenance.title }}</router-link> ／ {{ task.assigned_to?.name ?? '担当未定' }}</span>
                </div>
              </li>
            </ul>
            <p v-else class="pk-home-empty">ありません。</p>
            <h3>積み残し</h3>
          </div>

          <ul v-if="(evening ? entry.remaining : entry.todos).length || (evening && entry.drafts.length)" class="pk-home-list">
            <template v-if="evening">
              <li v-for="inspection in entry.drafts" :key="`d-${inspection.id}`" :data-testid="`home-draft-inspection-${inspection.id}`">
                <v-chip size="x-small" label color="warning" variant="flat">未提出</v-chip>
                <div class="pk-home-list__copy">
                  <strong>{{ inspection.checklist_template?.name ?? '点検' }}</strong>
                  <span>{{ inspectionTarget(inspection) }} ／ {{ inspection.user.name }}（下書きのまま）</span>
                </div>
                <!-- 編集できるのは作成者本人と管理者・マネージャーだけのため、誰でも見られる詳細へ -->
                <v-btn size="small" variant="outlined" :to="`/inspections/${inspection.id}`">開く</v-btn>
              </li>
            </template>
            <li
              v-for="todo in evening ? entry.remaining : entry.todos"
              :key="todo.key"
              :class="{ 'pk-home-list__alert': todo.rank === 0 }"
              :data-testid="`home-todo-${todo.key}`"
            >
              <v-chip size="x-small" label :color="TODO_COLOR[todo.kind]" variant="tonal">{{ TODO_LABEL[todo.kind] }}</v-chip>
              <template v-if="todo.kind === 'plan'">
                <div class="pk-home-list__copy">
                  <strong>{{ todo.plan.name }}</strong>
                  <span>{{ planTarget(todo.plan) }} ／ {{ todo.plan.inspection_plan_group.name }}</span>
                </div>
                <span class="pk-home-list__due">{{ dueText(todo.plan) }}</span>
                <v-btn v-if="todo.plan.reference_standard" size="small" variant="outlined" :to="referenceStandardFromPlan(todo.plan, canManageReferenceStandard)">
                  {{ canManageReferenceStandard ? '校正を記録' : '基準器を見る' }}
                </v-btn>
                <v-btn v-else size="small" variant="outlined" :to="inspectionFromPlan(todo.plan)">点検を実施</v-btn>
              </template>
              <template v-else-if="todo.kind === 'task'">
                <div class="pk-home-list__copy">
                  <strong>{{ todo.task.title }}</strong>
                  <span>{{ TASK_KIND_LABEL[todo.task.kind] }} ／ {{ todo.task.scheduled_maintenance.title }} ／ 担当 {{ todo.task.assigned_to?.name ?? '未定' }}</span>
                </div>
                <span class="pk-home-list__due">{{ todo.task.status === 'in_progress' ? '実施中' : '未着手' }}</span>
                <v-btn size="small" variant="outlined" :to="`/maintenances/${todo.task.scheduled_maintenance.id}`">開く</v-btn>
              </template>
              <template v-else>
                <div class="pk-home-list__copy">
                  <strong>{{ todo.trouble.title }}</strong>
                  <span>{{ troubleTarget(todo.trouble) }} ／ {{ troubleStatusLabel[todo.trouble.status] }} ／ 担当 {{ todo.trouble.assigned_to?.name ?? '未定' }}</span>
                </div>
                <StatusChip kind="priority" :value="todo.trouble.priority" />
                <v-btn size="small" variant="outlined" :to="`/troubles/${todo.trouble.id}`">開く</v-btn>
              </template>
            </li>
          </ul>
          <p v-else class="pk-home-empty">{{ evening ? '積み残しはありません。' : 'やることはありません。' }}</p>
          <p v-if="entry.area.troubles.total_count > entry.area.troubles.items.length" class="pk-home-empty">
            ほかのトラブル{{ entry.area.troubles.total_count - entry.area.troubles.items.length }}件は、トラブルの一覧で確認してください。
          </p>

          <!-- 夕会: 明日が期限の計画 -->
          <template v-if="evening && entry.tomorrow.length">
            <h3 class="pk-home-sub">明日の予定<small>{{ entry.tomorrow.length }}件</small></h3>
            <ul class="pk-home-list">
              <li v-for="todo in entry.tomorrow" :key="todo.key">
                <v-chip size="x-small" label color="primary" variant="tonal">点検</v-chip>
                <div v-if="todo.kind === 'plan'" class="pk-home-list__copy">
                  <strong>{{ todo.plan.name }}</strong>
                  <span>{{ planTarget(todo.plan) }}</span>
                </div>
              </li>
            </ul>
          </template>
        </section>
      </template>
    </div>
  </MainLayout>
</template>

<style scoped>
.pk-home__day { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 12px; color: var(--pk-muted); font-size: 0.875rem; }
.pk-home__day strong { padding: 2px 10px; border-radius: 6px; background: var(--pk-soft-blue); color: var(--pk-steel-dark); }
.pk-home__printed { display: none; }
.pk-home-report { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; margin-bottom: 16px; }
.pk-home-section { margin-bottom: 16px; padding: 12px 20px; border: 1px solid var(--pk-line); border-radius: 16px; background: #fff; }
.pk-home-section--alert { border-color: rgb(var(--v-theme-warning)); }
h2 { display: flex; align-items: center; font-family: var(--pk-font-display); font-size: 1.0625rem; line-height: 1.6; }
h2 small, h3 small { margin-left: 8px; color: var(--pk-muted); font-size: 0.75rem; font-weight: 400; font-variant-numeric: tabular-nums; }
h3 { margin-top: 8px; color: var(--pk-steel-dark); font-size: 0.8125rem; }
.pk-home-sub { margin-top: 12px; }
.pk-home-empty { padding: 8px 0; color: var(--pk-muted); font-size: 0.8125rem; }
.pk-home-list { padding: 0; list-style: none; }
.pk-home-list li { display: flex; align-items: center; gap: 12px; padding: 10px 0; }
.pk-home-list li + li { border-top: 1px solid var(--pk-line); }
.pk-home-list li > .v-chip:first-child { flex: none; min-width: 64px; justify-content: center; }
.pk-home-list .v-btn { flex: none; }
.pk-home-list__copy { display: grid; flex: 1; min-width: 0; gap: 2px; }
.pk-home-list__copy strong { font-size: 0.875rem; font-weight: 500; overflow-wrap: anywhere; }
.pk-home-list__copy a { color: var(--pk-ink); }
.pk-home-list__copy span { color: var(--pk-muted); font-size: 0.75rem; overflow-wrap: anywhere; }
.pk-home-list__due { flex: none; color: var(--pk-muted); font-size: 0.75rem; }
.pk-home-list__alert .pk-home-list__due, .pk-home-list__alert .pk-home-list__copy span { color: rgb(var(--v-theme-error)); }
a:focus-visible { outline: 2px solid var(--pk-steel); outline-offset: 2px; }
@media (max-width: 600px) {
  .pk-home-section { padding: 12px 14px; }
  .pk-home-list li { flex-wrap: wrap; }
}
/* 印刷（会議で紙に出す）: 操作を消し、行の途中でページを分けない */
@media print {
  .pk-home :deep(.pk-page-header__desc), .pk-home-list .v-btn { display: none !important; }
  .pk-home__printed { display: inline; }
  .pk-home-section { margin-bottom: 8px; padding: 6px 12px; border-radius: 6px; break-inside: auto; }
  .pk-home-list li { padding: 4px 0; break-inside: avoid; }
  h2 { break-after: avoid; }
  a { color: inherit !important; text-decoration: none !important; }
}
</style>
