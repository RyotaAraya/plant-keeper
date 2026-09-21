<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import SimilarTroubleList from '@/components/SimilarTroubleList.vue'
import { planaCapabilities } from '@/constants/planaCapabilities'
import { useAuthStore } from '@/stores/auth'
import { usePermissions } from '@/composables/usePermissions'
import { useSiteScopeOptions } from '@/composables/useSiteScopeOptions'
import { useSimilarTroubles } from '@/composables/useSimilarTroubles'
import { latestGuard } from '@/utils/latestGuard'
import type { AiStatus } from '@/types/models'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const { canCreateTroubleResponse } = usePermissions()
const tasks = computed(() => planaCapabilities.filter((task) => task.key !== 'response-draft' || canCreateTroubleResponse.value))
const activeTask = computed(() => tasks.value.find((task) => task.key === route.query.task) ?? tasks.value[1]!)
const unavailableTask = computed(() => route.query.task === 'response-draft' && !canCreateTroubleResponse.value)
const siteIds = ref<number[]>(auth.user?.site_id ? [auth.user.site_id] : [])
const { equipments, load } = useSiteScopeOptions({ withDepartments: false })
const equipmentId = ref<number | null>(null)
const instrumentId = ref<number | null>(null)
const instruments = ref<{ id: number; tag_number: string }[]>([])
const memo = ref('')
const optionsLoading = ref(false)
const optionsError = ref('')
const instrumentLoading = ref(false)
const instrumentError = ref('')
const optionsGuard = latestGuard()
const instrumentGuard = latestGuard()
const status = ref<AiStatus | null>(null)
const statusLoading = ref(true)
const statusError = ref(false)
const similar = useSimilarTroubles((count) => { if (status.value) status.value.remaining_today = count })
const searchButton = ref<{ $el: { focus(): void } } | null>(null)
function closeSimilar() {
  similar.clear()
  searchButton.value?.$el.focus()
}
const canSearch = computed(() => !!equipmentId.value && !!memo.value.trim() && !!status.value?.enabled && status.value.remaining_today > 0 && !optionsLoading.value && !optionsError.value && !instrumentLoading.value && !instrumentError.value)
const equipmentOptions = computed(() => equipments.value.map((equipment) => ({ ...equipment, label: siteIds.value.length === 1 ? equipment.name : `${equipment.site?.name ?? ''} ${equipment.name}` })))

async function fetchStatus() {
  statusLoading.value = true
  statusError.value = false
  try { status.value = (await api.get('/ai/status')).data.data }
  catch { status.value = null; statusError.value = true }
  finally { statusLoading.value = false }
}

async function fetchOptions() {
  const isLatest = optionsGuard()
  optionsLoading.value = true
  optionsError.value = ''
  equipmentId.value = null
  instruments.value = []
  try { await load(siteIds.value) }
  catch { if (isLatest()) optionsError.value = '設備を読み込めませんでした。もう一度お試しください。' }
  finally { if (isLatest()) optionsLoading.value = false }
}

async function fetchInstruments() {
  const isLatest = instrumentGuard()
  instrumentId.value = null
  instruments.value = []
  instrumentError.value = ''
  instrumentLoading.value = !!equipmentId.value
  if (!equipmentId.value) return
  try {
    const res = await api.get('/instruments', { params: { equipment_id: equipmentId.value, per_page: 1000 } })
    if (isLatest()) instruments.value = res.data.data
  } catch { if (isLatest()) instrumentError.value = '計器を読み込めませんでした。もう一度お試しください。' }
  finally { if (isLatest()) instrumentLoading.value = false }
}

function search() {
  if (!canSearch.value || similar.loading.value) return
  void similar.search({ equipmentId: equipmentId.value, instrumentId: instrumentId.value, memo: memo.value.trim() })
}
function startInspection() {
  if (!equipmentId.value || optionsLoading.value || optionsError.value || instrumentLoading.value || instrumentError.value) return
  void router.push({ path: '/inspections/new', query: { plana: 'defect-draft', equipment_id: String(equipmentId.value), ...(instrumentId.value ? { instrument_id: String(instrumentId.value) } : {}) } })
}

// 対応記録の対象はサーバー検索・ページ送りで選ぶ。先頭数件だけに限定しない。
interface TroubleOption { id: number; title: string; equipment: { name: string }; instrument?: { tag_number: string } }
const troubleQuery = ref('')
const submittedQuery = ref('')
const troublePage = ref(1)
const troubles = ref<TroubleOption[]>([])
const troubleTotal = ref(0)
const troubleLoading = ref(false)
const troubleError = ref('')
const troubleGuard = latestGuard()
async function fetchTroubles() {
  const isLatest = troubleGuard()
  troubleLoading.value = true
  troubleError.value = ''
  troubles.value = []
  try {
    const res = await api.get('/troubles', { params: { ...(siteIds.value.length ? { site_ids: siteIds.value } : {}), q: submittedQuery.value, page: troublePage.value, per_page: 5 } })
    if (!isLatest()) return
    troubles.value = res.data.data
    troubleTotal.value = res.data.meta.total_count
  } catch { if (isLatest()) troubleError.value = 'トラブルを読み込めませんでした。もう一度お試しください。' }
  finally { if (isLatest()) troubleLoading.value = false }
}
function findTroubles() {
  submittedQuery.value = (troubleQuery.value ?? '').trim()
  if (troublePage.value !== 1) troublePage.value = 1
  else void fetchTroubles()
}

watch(siteIds, () => {
  void fetchOptions()
  troublePage.value = 1
  if (activeTask.value.key === 'response-draft') void fetchTroubles()
}, { deep: true })
watch(equipmentId, fetchInstruments)
watch([memo, equipmentId, instrumentId, () => activeTask.value.key], () => similar.clear(), { flush: 'sync' })
watch(() => activeTask.value.key, (key) => { if (key === 'response-draft') void fetchTroubles() })
watch(troublePage, fetchTroubles)
onBeforeRouteLeave(() => !auth.isLoggedIn || !memo.value.trim() || window.confirm('入力した症状のメモを破棄して、別の画面へ移動しますか？'))
function warnBeforeUnload(event: BeforeUnloadEvent) {
  if (!memo.value.trim()) return
  event.preventDefault()
  event.returnValue = ''
}
onMounted(() => {
  void fetchStatus()
  void fetchOptions()
  if (activeTask.value.key === 'response-draft') void fetchTroubles()
  window.addEventListener('beforeunload', warnBeforeUnload)
})
onUnmounted(() => {
  similar.clear()
  optionsGuard(); instrumentGuard(); troubleGuard()
  window.removeEventListener('beforeunload', warnBeforeUnload)
})
</script>

<template>
  <MainLayout>
    <div class="plana-workspace">
      <header class="plana-heading">
        <div>
          <h1>今日は、何から始めますか？</h1>
          <p>現場の記録を整える。過去の事例を手がかりにする。</p>
        </div>
      </header>
      <v-alert v-if="unavailableTask" type="info" variant="tonal" class="mb-4" role="status">この権限では対応記録を作成できません。不具合報告と類似事例の検索を利用できます。</v-alert>
      <div class="plana-desk">
        <nav class="plana-tasks" aria-label="仕事を選ぶ">
          <h2>仕事を選ぶ</h2>
          <router-link v-for="task in tasks" :key="task.key" :to="task.to" :aria-current="activeTask.key === task.key ? 'page' : undefined" :class="{ selected: activeTask.key === task.key }" data-testid="plana-task">
            <v-icon size="22" aria-hidden="true">{{ task.icon }}</v-icon>
            <span><strong>{{ task.title }}</strong><small>{{ task.summary }}</small></span>
          </router-link>
          <div class="plana-help">
            <p>AIは提案まで。<br />記録する内容は、あなたが確認して決めます。</p>
            <p v-if="status?.enabled" data-testid="plana-remaining">今日の残り {{ status.remaining_today }} / {{ status.daily_limit }} 回</p>
          </div>
        </nav>
        <section class="plana-task-body" :aria-label="activeTask.title">
          <div class="plana-task-heading">
            <h2>{{ activeTask.title }}</h2>
            <SiteScopeTag v-model="siteIds" />
          </div>
          <p v-if="statusLoading" role="status" class="plana-state">AIの利用状況を確認しています。</p>
          <v-alert v-else-if="statusError" type="info" variant="tonal" class="mb-4" role="status">
            AIの利用状況を確認できません。通常の記録入力と履歴の参照は利用できます。
            <v-btn variant="text" size="small" @click="fetchStatus">利用状況を再確認</v-btn>
          </v-alert>
          <v-alert v-else-if="status && !status.enabled" type="info" variant="tonal" class="mb-4" data-testid="plana-disabled">この環境ではAI機能は無効です。記録の入力と過去のトラブルの参照は利用できます。</v-alert>
          <v-alert v-else-if="status?.remaining_today === 0" type="info" variant="tonal" class="mb-4">今日のAI利用回数の上限に達しました。記録の入力と過去のトラブルの参照は続けられます。</v-alert>

          <template v-if="activeTask.key !== 'response-draft'">
            <p class="plana-instruction">{{ activeTask.key === 'defect-draft' ? '不具合が見つかった設備を選んでください。点検の不具合欄で、メモから報告を整えます。' : '設備と症状を教えてください。関連する過去のトラブルから、似た事例と対応記録を探します。' }}</p>
            <v-alert v-if="optionsError" type="error" variant="tonal" class="mb-3" role="alert">{{ optionsError }} <v-btn variant="text" @click="fetchOptions">設備を再読み込み</v-btn></v-alert>
            <div class="plana-targets">
              <v-autocomplete v-model="equipmentId" :items="equipmentOptions" item-title="label" item-value="id" label="対象の設備" :loading="optionsLoading" :disabled="optionsLoading || !!optionsError" clearable no-data-text="選択できる設備がありません" />
              <v-autocomplete v-model="instrumentId" :items="instruments" item-title="tag_number" item-value="id" label="対象の計器（任意）" :loading="instrumentLoading" :disabled="!equipmentId || instrumentLoading || !!instrumentError" clearable no-data-text="計器がありません" />
            </div>
            <v-alert v-if="instrumentError" type="error" variant="tonal" class="mb-3" role="alert">{{ instrumentError }} <v-btn variant="text" @click="fetchInstruments">計器を再読み込み</v-btn></v-alert>
            <template v-if="activeTask.key === 'defect-draft'">
              <div class="plana-next-step"><h3>点検の記録につなげます</h3><p>設備・計器を引き継いで、不具合の入力欄を開きます。下書きを確認し、必要な情報を補って点検を保存してください。</p></div>
              <v-btn color="primary" :disabled="!equipmentId || optionsLoading || !!optionsError || instrumentLoading || !!instrumentError" @click="startInspection">不具合の記録を始める</v-btn>
            </template>
            <form v-else @submit.prevent="search">
              <v-textarea v-model="memo" label="いま起きている症状" placeholder="例：流量の指示が低い。導圧管のつまりが疑われる。" rows="4" auto-grow :maxlength="status?.max_memo_length ?? 1000" :counter="status?.max_memo_length ?? 1000" hint="設備と症状を入力すると検索できます。結果は提案として表示され、記録は変更されません。" persistent-hint />
              <div class="plana-actions">
                <v-btn ref="searchButton" type="submit" color="primary" :disabled="!canSearch" :loading="similar.loading.value" data-testid="plana-search">似た事例を探す</v-btn>
                <v-btn variant="text" :to="{ path: '/troubles', query: { site_ids: siteIds.length ? siteIds.join(',') : 'all', ...(equipmentId ? { equipment_id: String(equipmentId) } : {}) } }">記録を自分で探す</v-btn>
              </div>
              <p v-if="similar.loading.value" role="status" class="plana-state">過去の記録を確認しています。</p>
              <v-alert v-if="similar.error.value" type="warning" variant="tonal" role="alert" class="mt-4">{{ similar.error.value }}</v-alert>
              <div aria-live="polite"><SimilarTroubleList v-if="similar.result.value" :result="similar.result.value" @close="closeSimilar" /></div>
            </form>
          </template>
          <template v-else>
            <p class="plana-instruction">対応したトラブルを選んでください。対応メモを下書きに整え、確認して記録できます。</p>
            <form class="plana-trouble-search" @submit.prevent="findTroubles">
              <v-text-field v-model="troubleQuery" label="トラブルのタイトルで検索" hide-details clearable />
              <v-btn type="submit" variant="outlined" :loading="troubleLoading">検索</v-btn>
            </form>
            <v-alert v-if="troubleError" type="error" variant="tonal" role="alert">{{ troubleError }} <v-btn variant="text" @click="fetchTroubles">再読み込み</v-btn></v-alert>
            <p v-else-if="troubleLoading" role="status" class="plana-state">トラブルを読み込んでいます。</p>
            <template v-else>
              <ul class="plana-records">
                <li v-for="trouble in troubles" :key="trouble.id"><router-link :to="{ path: `/troubles/${trouble.id}`, query: { plana: 'response-draft' } }"><span><strong>{{ trouble.title }}</strong><small>{{ trouble.equipment.name }}<template v-if="trouble.instrument"> / {{ trouble.instrument.tag_number }}</template></small></span><v-icon aria-hidden="true">mdi-chevron-right</v-icon></router-link></li>
              </ul>
              <p v-if="!troubles.length" class="plana-state">該当するトラブルがありません。検索する言葉や拠点を変更してください。</p>
              <v-pagination v-if="troubleTotal > 5" v-model="troublePage" :length="Math.ceil(troubleTotal / 5)" :total-visible="3" aria-label="トラブルのページ" />
            </template>
          </template>
        </section>
      </div>
      <footer class="plana-work-links"><span>組織の状況や予定を確認する</span><router-link to="/dashboard">ダッシュボードを開く <v-icon size="18" aria-hidden="true">mdi-arrow-right</v-icon></router-link></footer>
    </div>
  </MainLayout>
</template>

<style scoped>
.plana-workspace { max-width: 1200px; margin: 0 auto; }
.plana-heading { display: flex; gap: 20px; align-items: center; margin: 8px 0 32px; }
.plana-heading h1 { font-size: clamp(1.6rem, 3vw, 2.1rem); line-height: 1.45; margin: 3px 0 8px; }
.plana-heading p { color: var(--pk-muted); font-size: .9rem; }
.plana-desk { display: grid; grid-template-columns: 280px minmax(0, 1fr); border: 1px solid var(--pk-line); border-radius: 20px; overflow: hidden; background: white; }
.plana-tasks { padding: 28px 16px; background: var(--pk-soft-blue); border-right: 1px solid var(--pk-line); }
.plana-tasks h2 { font-size: .875rem; padding: 0 12px 16px; }
.plana-tasks a { display: flex; gap: 12px; padding: 16px 12px; border-radius: 12px; text-decoration: none; color: var(--pk-ink); border: 1px solid transparent; margin-bottom: 8px; }
.plana-tasks a.selected { background: #fff; border-color: var(--pk-steel); }
.plana-tasks a:hover { background: #fff; }
.plana-tasks a > .v-icon { color: var(--pk-steel); margin-top: 2px; }
.plana-tasks strong, .plana-records strong { display: block; font-size: .9375rem; }
.plana-tasks small { display: block; color: var(--pk-muted); margin-top: 8px; line-height: 1.7; font-size: .75rem; }
.plana-help { padding: 20px 12px 0; font-size: .75rem; line-height: 1.9; color: var(--pk-muted); }
.plana-help p + p { margin-top: 16px; }
.plana-task-body { padding: 32px; min-width: 0; }
.plana-task-heading { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 20px; }
.plana-task-heading h2 { font-size: 1.25rem; }
.plana-instruction { color: var(--pk-muted); font-size: .875rem; line-height: 1.9; margin-bottom: 24px; max-width: 42em; }
.plana-targets { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
.plana-actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 20px; }
.plana-state { color: var(--pk-muted); font-size: .875rem; margin: 16px 0; }
.plana-next-step { border-left: 3px solid var(--pk-line); padding: 0 0 0 20px; margin: 16px 0 28px; }
.plana-next-step h3 { font-size: 1rem; margin-bottom: 8px; }
.plana-next-step p { font-size: .875rem; line-height: 1.9; color: var(--pk-muted); }
.plana-trouble-search { display: flex; align-items: center; gap: 12px; margin-bottom: 20px; }
.plana-records { list-style: none; padding: 0; }
.plana-records a { display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 18px 4px; border-bottom: 1px solid var(--pk-line); text-decoration: none; color: var(--pk-ink); }
.plana-records a:hover { color: var(--pk-steel); }
.plana-records strong { overflow-wrap: anywhere; }
.plana-records small { display: block; margin-top: 6px; color: var(--pk-muted); }
.plana-work-links { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 12px; padding: 24px 4px; font-size: .875rem; color: var(--pk-muted); }
.plana-work-links a { color: var(--pk-steel); text-decoration: none; }
@media (max-width: 1100px) { .plana-desk { grid-template-columns: 220px minmax(0, 1fr); } .plana-targets { grid-template-columns: 1fr; gap: 0; } .plana-task-body { padding: 24px; } }
@media (max-width: 850px) { .plana-desk { grid-template-columns: 1fr; } .plana-tasks { border-right: 0; border-bottom: 1px solid var(--pk-line); padding: 16px; } .plana-tasks a { padding: 12px; margin-bottom: 4px; } .plana-tasks small, .plana-help { display: none; } .plana-tasks h2 { padding-bottom: 8px; } }
@media (max-width: 600px) { .plana-heading { gap: 12px; align-items: start; margin: 4px 0 24px; } .plana-heading h1 { font-size: 1.4rem; } .plana-heading p { font-size: .75rem; } .plana-task-body { padding: 20px 16px; } .plana-desk { border-radius: 16px; } }
</style>
