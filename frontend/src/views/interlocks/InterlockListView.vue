<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import InterlockFormDialog from '@/components/InterlockFormDialog.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import SiteScopeTag from '@/components/SiteScopeTag.vue'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { Interlock } from '@/types/models'
import { BYPASS_STATE_OPTIONS, bypassColor, bypassLabel, formatDateTime, formatHours, restoreDueLabel } from '@/utils/interlock'
import { latestGuard } from '@/utils/latestGuard'
import { siteIdsFromQuery } from '@/utils/listQuery'

const route = useRoute()
const router = useRouter()
const { canManageInterlock } = usePermissions()
const authStore = useAuthStore()

const interlocks = ref<Interlock[]>([])
const loading = ref(false)
// 通常業務では自拠点だけ見ればよいため、自分の所属拠点を初期値にする（ほかの画面のリンクから来たときはその拠点）
const selectedSiteIds = ref<number[]>(siteIdsFromQuery(route.query.site_ids, authStore.user?.site_id ? [authStore.user.site_id] : []))
const bypassState = ref<string | null>(typeof route.query.bypass_state === 'string' ? route.query.bypass_state : null)
const search = ref('')

const headers = [
  { title: '番号', key: 'tag_number', width: '90px' },
  { title: '名称', key: 'name', minWidth: '200px' },
  { title: '設備', key: 'equipment.name', minWidth: '140px' },
  { title: '関係する計器', key: 'instruments', sortable: false, minWidth: '160px' },
  { title: 'バイパス', key: 'open_bypass', sortable: false, minWidth: '260px' },
]

// 終わっていないバイパスの件数（見ている拠点・検索の範囲）。いまインターロックが外れているもの・誰かの操作を待っているものを先に知らせる
const summary = computed(() => {
  const open = interlocks.value.map((il) => il.open_bypass).filter((b) => !!b)
  return {
    overdue: open.filter((b) => b!.overdue).length,
    bypassed: open.filter((b) => b!.status === 'bypassed').length,
  }
})

const fetchGuard = latestGuard()

async function fetchInterlocks() {
  const isLatest = fetchGuard()
  loading.value = true
  try {
    const params: Record<string, unknown> = { per_page: 500 }
    if (selectedSiteIds.value.length) params.site_ids = selectedSiteIds.value
    if (bypassState.value) params.bypass_state = bypassState.value
    if (search.value) params.q = search.value
    const res = await api.get('/interlocks', { params })
    if (!isLatest()) return
    interlocks.value = res.data.data
  } finally {
    if (isLatest()) loading.value = false
  }
}

const dialog = ref(false)

// 行の色: 復帰期限超過は赤、バイパス中は黄
const rowProps = ({ item }: { item: Interlock }) => ({
  class: item.open_bypass?.overdue ? 'pk-row--overdue' : item.open_bypass?.status === 'bypassed' ? 'pk-row--bypassed' : '',
})

onMounted(fetchInterlocks)
watch([selectedSiteIds, bypassState, search], fetchInterlocks)
</script>

<template>
  <MainLayout>
    <PageHeader
      title="インターロック"
      description="安全計装（インターロック）の台帳と、点検・故障のときのバイパスを管理します。バイパスは申請 → 承認 → 実施 → 復帰 → 別の人の確認で完了し、予定の復帰を過ぎたものは「復帰期限超過」になります。"
    >
      <v-btn v-if="canManageInterlock" color="primary" prepend-icon="mdi-plus" @click="dialog = true">新規登録</v-btn>
    </PageHeader>

    <v-alert v-if="summary.overdue" type="error" variant="tonal" density="compact" class="mb-3" data-testid="interlock-overdue-alert">
      予定の復帰を過ぎてもバイパスされたままのインターロックが <strong>{{ summary.overdue }}件</strong> あります。復帰の予定と代替措置を確認してください。
    </v-alert>

    <div class="pk-filters">
      <SiteScopeTag v-model="selectedSiteIds" />
      <v-divider vertical class="pk-scope-divider" />
      <v-select
        v-model="bypassState"
        :items="BYPASS_STATE_OPTIONS"
        label="バイパス"
        density="compact"
        hide-details
        clearable
        style="max-width: 240px"
        data-testid="bypass-state-filter"
      />
      <v-text-field v-model="search" label="番号・名称・計器のタグ番号" density="compact" hide-details clearable prepend-inner-icon="mdi-magnify" style="max-width: 300px" />
      <span class="text-caption text-medium-emphasis">バイパス中 {{ summary.bypassed }}件</span>
    </div>

    <v-data-table
      :headers="headers"
      :items="interlocks"
      :loading="loading"
      :row-props="rowProps"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => router.push(`/interlocks/${item.id}`)"
    >
      <template #item.name="{ item }">
        <div>{{ item.name }}</div>
        <div v-if="!item.is_active" class="text-caption text-medium-emphasis">廃止</div>
      </template>
      <template #item.equipment.name="{ item }">
        <div>{{ item.equipment.name }}</div>
        <div class="text-caption text-medium-emphasis">{{ item.equipment.site.name }}</div>
      </template>
      <template #item.instruments="{ item }">
        <span class="text-no-wrap">{{ item.instruments.map((i: any) => i.tag_number).join('、') || '—' }}</span>
      </template>
      <template #item.open_bypass="{ item }">
        <template v-if="item.open_bypass">
          <v-chip :color="bypassColor(item.open_bypass)" size="small" label variant="flat" class="mr-2">{{ bypassLabel(item.open_bypass) }}</v-chip>
          <span v-if="item.open_bypass.status === 'bypassed'" class="text-caption">
            {{ formatHours(item.open_bypass.bypassed_hours) }}経過 ／ 予定の復帰 {{ formatDateTime(item.open_bypass.planned_restore_at) }}（{{ restoreDueLabel(item.open_bypass) }}）
          </span>
          <span v-else class="text-caption text-medium-emphasis">{{ item.open_bypass.request_number }}</span>
        </template>
        <span v-else class="text-medium-emphasis">—</span>
      </template>
    </v-data-table>

    <InterlockFormDialog
      v-model="dialog"
      :interlock="null"
      :default-site-id="selectedSiteIds.length === 1 ? selectedSiteIds[0] : null"
      @saved="(id) => router.push(`/interlocks/${id}`)"
    />
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
.cursor-pointer :deep(tr.pk-row--overdue) {
  background: rgba(var(--v-theme-error), 0.07);
}
.cursor-pointer :deep(tr.pk-row--bypassed) {
  background: rgba(var(--v-theme-warning), 0.08);
}
</style>
