<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'

const router = useRouter()
const authStore = useAuthStore()
const { canViewSites } = usePermissions()
const dashboard = ref<any>(null)
const loading = ref(true)

const sites = ref<any[]>([])
// 通常業務では自拠点だけ意識すればよいため、自分の所属拠点をデフォルト選択（切替可）
const selectedSiteId = ref<number | null>(authStore.user?.site_id ?? null)

async function fetchSites() {
  // 拠点の一覧を見られない協力会社は、自分の所属拠点で固定（切り替えの選択欄を出さない）
  if (!canViewSites.value) return
  const res = await api.get('/sites', { params: { per_page: 100, is_active: true } })
  sites.value = res.data.data
}

async function fetchDashboard() {
  loading.value = true
  try {
    const params: any = {}
    if (selectedSiteId.value) params.site_id = selectedSiteId.value
    const res = await api.get('/dashboard', { params })
    dashboard.value = res.data.data
    lastUpdated.value = formatTime(new Date())
  } finally {
    loading.value = false
  }
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleDateString('ja-JP')
}

const statusLabel: Record<string, string> = {
  draft: '下書き', ordered: '発注済', received: '受領済'
}

const lastUpdated = ref('')

function formatTime(d: Date) {
  return d.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' })
}

watch(selectedSiteId, fetchDashboard)

onMounted(async () => {
  await Promise.all([fetchDashboard(), fetchSites()])
})
</script>

<template>
  <MainLayout>
    <div class="d-flex align-center flex-wrap ga-3 mb-4">
      <div class="d-flex align-baseline flex-wrap ga-2">
        <h1 class="text-h5">
          ようこそ、{{ authStore.user?.name ?? '' }} さん
        </h1>
        <span v-if="lastUpdated" class="text-caption text-medium-emphasis pk-mono">
          最終更新 {{ lastUpdated }}
        </span>
      </div>
      <v-spacer />
      <v-select
        v-if="canViewSites"
        v-model="selectedSiteId"
        :items="sites"
        item-title="name"
        item-value="id"
        label="拠点"
        clearable
        density="compact"
        hide-details
        style="min-width: 200px; max-width: 260px"
      />
    </div>

    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="dashboard">
      <!-- 統計カード -->
      <v-row class="mb-4">
        <v-col cols="6" md="3">
          <button class="pk-kpi pk-kpi--error" @click="router.push('/troubles?status=open')">
            <v-icon class="pk-kpi__icon" aria-hidden="true">mdi-alert-circle-outline</v-icon>
            <div class="pk-kpi__value pk-mono">{{ dashboard.troubles.open }}</div>
            <div class="pk-kpi__label">未対応トラブル</div>
          </button>
        </v-col>
        <v-col cols="6" md="3">
          <button class="pk-kpi pk-kpi--warning" @click="router.push('/troubles?status=in_progress')">
            <v-icon class="pk-kpi__icon" aria-hidden="true">mdi-progress-wrench</v-icon>
            <div class="pk-kpi__value pk-mono">{{ dashboard.troubles.in_progress }}</div>
            <div class="pk-kpi__label">対応中トラブル</div>
          </button>
        </v-col>
        <v-col cols="6" md="3">
          <button class="pk-kpi pk-kpi--info" @click="router.push('/inspections')">
            <v-icon class="pk-kpi__icon" aria-hidden="true">mdi-clipboard-check-outline</v-icon>
            <div class="pk-kpi__value pk-mono">{{ dashboard.inspections.pending_approval }}</div>
            <div class="pk-kpi__label">承認待ち点検</div>
          </button>
        </v-col>
        <v-col cols="6" md="3">
          <div class="pk-kpi pk-kpi--success">
            <v-icon class="pk-kpi__icon" aria-hidden="true">mdi-calendar-check-outline</v-icon>
            <div class="pk-kpi__value pk-mono">{{ dashboard.inspections.this_month }}</div>
            <div class="pk-kpi__label">今月の点検数</div>
          </div>
        </v-col>
      </v-row>

      <v-row>
        <!-- 点検期限 -->
        <v-col cols="12" md="6">
          <v-card>
            <v-card-title>
              <v-icon class="mr-2" aria-hidden="true">mdi-calendar-alert</v-icon>
              点検期限
              <v-chip v-if="dashboard.inspection_plans.overdue > 0" class="ml-2" size="x-small" color="error">
                超過{{ dashboard.inspection_plans.overdue }}件
              </v-chip>
              <v-chip v-if="dashboard.inspection_plans.due_soon > 0" class="ml-2" size="x-small" color="warning">
                7日以内{{ dashboard.inspection_plans.due_soon }}件
              </v-chip>
            </v-card-title>
            <v-list v-if="dashboard.inspection_plans.overdue_list?.length" density="compact">
              <v-list-item
                v-for="p in dashboard.inspection_plans.overdue_list"
                :key="p.id"
                :title="p.name"
                :subtitle="`${p.equipment?.name}${p.instrument ? ' / ' + p.instrument.tag_number : ''} — ${-p.days_until_due}日超過`"
                @click="router.push('/inspection-plans?overdue=true')"
              >
                <template #prepend>
                  <v-icon color="error" aria-hidden="true">mdi-clock-alert-outline</v-icon>
                </template>
              </v-list-item>
            </v-list>
            <v-card-text v-else>
              <div class="text-grey text-center">期限超過の点検はありません</div>
            </v-card-text>
            <v-card-actions>
              <v-btn @click="router.push('/inspection-plans')">点検計画へ</v-btn>
            </v-card-actions>
          </v-card>
        </v-col>

        <!-- 直近の定期整備 -->
        <v-col cols="12" md="6">
          <v-card>
            <v-card-title>
              <v-icon class="mr-2" aria-hidden="true">mdi-wrench</v-icon>
              直近の定期整備
              <v-chip class="ml-2" size="x-small" color="warning">計{{ dashboard.maintenances.planned + dashboard.maintenances.in_progress }}件</v-chip>
            </v-card-title>
            <v-list v-if="dashboard.maintenances.upcoming?.length" density="compact">
              <v-list-item
                v-for="m in dashboard.maintenances.upcoming"
                :key="m.id"
                :title="m.title"
                :subtitle="`${m.equipment?.name} — ${formatDate(m.scheduled_date)}`"
                @click="router.push(`/maintenances/${m.id}`)"
              >
                <template #prepend>
                  <v-icon color="warning" aria-hidden="true">mdi-calendar-clock</v-icon>
                </template>
              </v-list-item>
            </v-list>
            <v-card-text v-else>
              <div class="text-grey text-center">
                直近30日以内の予定はありません
                <template v-if="dashboard.maintenances.planned + dashboard.maintenances.in_progress > 0">
                  <br /><span class="text-caption">（計{{ dashboard.maintenances.planned + dashboard.maintenances.in_progress }}件が今後予定されています）</span>
                </template>
              </div>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- 在庫アラート（権限のない人には項目自体が返らない） -->
        <v-col v-if="dashboard.stock_alerts" cols="12" md="6">
          <v-card>
            <v-card-title>
              <v-icon class="mr-2" aria-hidden="true">mdi-alert</v-icon>
              在庫アラート
            </v-card-title>
            <v-list v-if="dashboard.stock_alerts?.length" density="compact">
              <v-list-item
                v-for="a in dashboard.stock_alerts"
                :key="a.id"
                :title="a.name"
                :subtitle="`${a.part_number} — 在庫: ${a.total_stock} / 発注点: ${a.reorder_point}`"
                @click="router.push(`/materials/${a.id}`)"
              >
                <template #prepend>
                  <v-icon color="error" aria-hidden="true">mdi-package-variant-minus</v-icon>
                </template>
              </v-list-item>
            </v-list>
            <v-card-text v-else>
              <div class="text-grey text-center">アラートなし</div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <v-row class="mt-2">
        <!-- 緊急トラブル -->
        <v-col v-if="dashboard.troubles.critical > 0" cols="12" md="6">
          <v-card color="error" variant="tonal">
            <v-card-title>
              <v-icon class="mr-2" aria-hidden="true">mdi-alert-octagon</v-icon>
              緊急トラブル: {{ dashboard.troubles.critical }}件
            </v-card-title>
            <v-card-actions>
              <v-btn @click="router.push('/troubles')">トラブル一覧へ</v-btn>
            </v-card-actions>
          </v-card>
        </v-col>

        <!-- 修理状況（権限のない人には項目自体が返らない） -->
        <v-col v-if="dashboard.repairs && dashboard.orders" cols="12" md="6">
          <v-card>
            <v-card-title>
              <v-icon class="mr-2" aria-hidden="true">mdi-tools</v-icon>
              修理・発注状況
            </v-card-title>
            <v-card-text>
              <div class="pk-stat-mini-row">
                <button class="pk-stat-mini pk-stat-mini--warning" @click="router.push('/repairs')">
                  <div class="pk-stat-mini__value pk-mono">{{ dashboard.repairs.pending }}</div>
                  <div class="pk-stat-mini__label">修理待ち</div>
                </button>
                <button class="pk-stat-mini pk-stat-mini--info" @click="router.push('/repairs')">
                  <div class="pk-stat-mini__value pk-mono">{{ dashboard.repairs.in_repair }}</div>
                  <div class="pk-stat-mini__label">修理中</div>
                </button>
                <button class="pk-stat-mini pk-stat-mini--muted" @click="router.push('/orders')">
                  <div class="pk-stat-mini__value pk-mono">{{ dashboard.orders.draft }}</div>
                  <div class="pk-stat-mini__label">発注下書き</div>
                </button>
                <button class="pk-stat-mini pk-stat-mini--success" @click="router.push('/orders')">
                  <div class="pk-stat-mini__value pk-mono">{{ dashboard.orders.ordered }}</div>
                  <div class="pk-stat-mini__label">発注済</div>
                </button>
              </div>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- 最近の発注 -->
        <v-col v-if="dashboard.orders" cols="12" md="6">
          <v-card>
            <v-card-title>
              <v-icon class="mr-2" aria-hidden="true">mdi-cart</v-icon>
              最近の発注
            </v-card-title>
            <v-list v-if="dashboard.orders.recent?.length" density="compact">
              <v-list-item
                v-for="o in dashboard.orders.recent"
                :key="o.id"
                :title="`${o.material?.name} × ${o.quantity}`"
                :subtitle="`${o.user?.name} — ${formatDate(o.ordered_on)}`"
                @click="router.push('/orders')"
              >
                <template #append>
                  <v-chip size="x-small">{{ statusLabel[o.status] || o.status }}</v-chip>
                </template>
              </v-list-item>
            </v-list>
            <v-card-text v-else>
              <div class="text-grey text-center">発注なし</div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </template>
  </MainLayout>
</template>

<style scoped>
.pk-kpi {
  position: relative;
  display: block;
  width: 100%;
  background: #fff;
  border: 1px solid var(--pk-line);
  border-left: 3px solid var(--pk-line);
  padding: 1.1rem 1.25rem;
  text-align: left;
  cursor: default;
  font: inherit;
}

button.pk-kpi {
  cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease;
}

button.pk-kpi:hover {
  background: var(--pk-mist);
}

.pk-kpi__icon {
  position: absolute;
  top: 1rem;
  right: 1rem;
  opacity: 0.25;
  font-size: 1.5rem !important;
}

.pk-kpi__value {
  font-size: 2rem;
  font-weight: 700;
  line-height: 1.1;
}

.pk-kpi__label {
  font-size: 0.8rem;
  color: #5b6b70;
  margin-top: 0.25rem;
}

.pk-kpi--error { border-left-color: #b3261e; }
.pk-kpi--error .pk-kpi__value,
.pk-kpi--error .pk-kpi__icon { color: #b3261e; }
.pk-kpi--warning { border-left-color: #b4720e; }
.pk-kpi--warning .pk-kpi__value,
.pk-kpi--warning .pk-kpi__icon { color: #b4720e; }
.pk-kpi--info { border-left-color: #3d6e8c; }
.pk-kpi--info .pk-kpi__value,
.pk-kpi--info .pk-kpi__icon { color: #3d6e8c; }
.pk-kpi--success { border-left-color: #2e7d4f; }
.pk-kpi--success .pk-kpi__value,
.pk-kpi--success .pk-kpi__icon { color: #2e7d4f; }

.pk-stat-mini-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
}

.pk-stat-mini {
  flex: 1 1 100px;
  background: var(--pk-mist);
  border: 1px solid var(--pk-line);
  border-radius: 2px;
  padding: 0.6rem 0.75rem;
  text-align: left;
  cursor: pointer;
  font: inherit;
  transition: background 0.15s ease, border-color 0.15s ease;
}

.pk-stat-mini:hover {
  background: #fff;
  border-color: var(--pk-steel);
}

.pk-stat-mini__value {
  font-size: 1.25rem;
  font-weight: 700;
  line-height: 1.1;
}

.pk-stat-mini__label {
  font-size: 0.75rem;
  color: #5b6b70;
  margin-top: 0.2rem;
}

.pk-stat-mini--warning .pk-stat-mini__value { color: #b4720e; }
.pk-stat-mini--info .pk-stat-mini__value { color: #3d6e8c; }
.pk-stat-mini--success .pk-stat-mini__value { color: #2e7d4f; }
.pk-stat-mini--muted .pk-stat-mini__value { color: var(--pk-ink); }
</style>

