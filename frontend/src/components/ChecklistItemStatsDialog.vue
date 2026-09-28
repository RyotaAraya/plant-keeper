<script setup lang="ts">
// チェックリストのテンプレートの項目ごとに、実施回数と「不具合あり」の件数を示す（項目の見直しの材料）。
// 数えるのは提出した点検の記録だけで、項目を変えるかどうかは人が決める（ここでは何も変えない）
import { ref, watch } from 'vue'
import api from '@/api/axios'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { useSiteScope } from '@/composables/useSiteScope'
import type { ChecklistItemStats, ChecklistItemStatsPeriod, ChecklistItemStatsRow } from '@/types/models'
import { ITEM_TYPE_OPTIONS } from '@/utils/checklistCriteria'
import { latestGuard } from '@/utils/latestGuard'

const props = defineProps<{ template: { id: number; name: string } | null }>()
const open = defineModel<boolean>({ default: false })

const { ownSiteIds } = useSiteScope()
const PERIOD_OPTIONS: { title: string; value: ChecklistItemStatsPeriod }[] = [
  { title: '直近1年', value: '1y' },
  { title: '直近3年', value: '3y' },
  { title: '全期間', value: 'all' },
]
const ITEM_TYPE_LABEL = Object.fromEntries(ITEM_TYPE_OPTIONS.map((o) => [o.value, o.title]))

const period = ref<ChecklistItemStatsPeriod>('1y')
const siteIds = ref<number[]>([])
const stats = ref<ChecklistItemStats | null>(null)
const loading = ref(false)
const error = ref('')
const guard = latestGuard()

// 開くたびに、自拠点・直近1年から始める（取得は下の watch がまとめて1回だけ行う）
watch(open, (isOpen) => {
  if (!isOpen) return
  stats.value = null
  period.value = '1y'
  // ダイアログは URL を持たないため、開くたびに所属拠点から始める
  siteIds.value = ownSiteIds()
})
watch([open, period, siteIds], () => {
  if (open.value) fetchStats()
})

async function fetchStats() {
  if (!props.template) return
  const isLatest = guard()
  loading.value = true
  error.value = ''
  try {
    const res = await api.get(`/checklist_templates/${props.template.id}/item_stats`, {
      params: { period: period.value, site_ids: siteIds.value },
    })
    if (isLatest()) stats.value = res.data.data
  } catch (e: any) {
    if (isLatest()) error.value = e.response?.data?.errors?.[0] || '集計を取得できませんでした'
  } finally {
    if (isLatest()) loading.value = false
  }
}

// 実施があって、不具合が一度も出ていない項目（見直しの材料として目立たせる）。自由記述は不具合を判定しないため除く
const noDefect = (row: ChecklistItemStatsRow) => row.item_type !== 'text' && row.performed_count > 0 && row.defect_count === 0
const formatDate = (value: string | null) => (value ? new Date(value).toLocaleDateString('ja-JP', { timeZone: 'Asia/Tokyo' }) : '—')

const headers = [
  { title: '#', key: 'position', width: '48px' },
  { title: '区分', key: 'section', width: '80px' },
  { title: '項目', key: 'content' },
  { title: '種別', key: 'item_type', width: '90px' },
  { title: '実施', key: 'performed_count', width: '70px', align: 'end' as const },
  { title: '不具合', key: 'defect_count', width: '80px', align: 'end' as const },
  { title: '該当なし', key: 'na_count', width: '90px', align: 'end' as const },
  { title: '最後の不具合', key: 'last_defect_at', width: '120px' },
]
</script>

<template>
  <v-dialog v-model="open" max-width="960" scrollable>
    <v-card data-testid="checklist-item-stats">
      <v-card-title>項目の見直し</v-card-title>
      <v-card-subtitle>{{ template?.name }}</v-card-subtitle>
      <v-card-text>
        <div class="d-flex flex-wrap align-center ga-3 mb-3">
          <SiteScopeTag v-model="siteIds" />
          <v-btn-toggle v-model="period" mandatory density="compact" variant="outlined" divided color="primary">
            <v-btn v-for="option in PERIOD_OPTIONS" :key="option.value" :value="option.value" size="small">{{ option.title }}</v-btn>
          </v-btn-toggle>
        </div>
        <p class="text-body-2 mb-1">
          提出した点検 <strong>{{ stats?.inspections_count ?? 0 }}件</strong>の記録から、項目ごとに実施回数と「不具合あり」の件数を数えています。
        </p>
        <p class="text-caption text-medium-emphasis mb-3">
          実施は判定が良好・不具合ありのもの（選択式・自由記述は記入したもの）で、「－」（該当なし）は別に数えます。
          5点校正は、点検者が「不具合あり」にしたものだけを不具合に数えます。項目を作り直す前の記録は含みません。
        </p>
        <v-alert v-if="error" type="error" density="compact" class="mb-3">{{ error }}</v-alert>
        <v-data-table
          :headers="headers"
          :items="stats?.items ?? []"
          :loading="loading"
          :items-per-page="-1"
          density="compact"
          hide-default-footer
        >
          <template #item.section="{ item }">{{ item.section || '—' }}</template>
          <template #item.item_type="{ item }">{{ ITEM_TYPE_LABEL[item.item_type] ?? item.item_type }}</template>
          <template #item.content="{ item }">
            <span>{{ item.content }}</span>
            <v-chip v-if="noDefect(item)" size="x-small" variant="tonal" color="info" label class="ml-2">不具合なし</v-chip>
            <v-chip v-else-if="item.performed_count === 0" size="x-small" variant="tonal" label class="ml-2">実施なし</v-chip>
          </template>
          <template #item.defect_count="{ item }">
            <span :class="{ 'text-error font-weight-bold': item.defect_count > 0 }">{{ item.defect_count }}</span>
          </template>
          <template #item.last_defect_at="{ item }">{{ formatDate(item.last_defect_at) }}</template>
        </v-data-table>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">閉じる</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
