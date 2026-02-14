<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const router = useRouter()
const authStore = useAuthStore()
const dashboard = ref<any>(null)
const loading = ref(true)

async function fetchDashboard() {
  loading.value = true
  try {
    const res = await api.get('/dashboard')
    dashboard.value = res.data.data
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

onMounted(fetchDashboard)
</script>

<template>
  <MainLayout>
    <h1 class="text-h5 mb-4">
      ようこそ、{{ authStore.user?.name ?? '' }} さん
    </h1>

    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="dashboard">
      <!-- 統計カード -->
      <v-row class="mb-4">
        <v-col cols="6" md="3">
          <v-card color="error" variant="tonal" @click="router.push('/troubles?status=open')">
            <v-card-text class="text-center">
              <div class="text-h3">{{ dashboard.troubles.open }}</div>
              <div class="text-body-2">未対応トラブル</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card color="warning" variant="tonal" @click="router.push('/troubles?status=in_progress')">
            <v-card-text class="text-center">
              <div class="text-h3">{{ dashboard.troubles.in_progress }}</div>
              <div class="text-body-2">対応中トラブル</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card color="info" variant="tonal" @click="router.push('/inspections')">
            <v-card-text class="text-center">
              <div class="text-h3">{{ dashboard.inspections.pending_approval }}</div>
              <div class="text-body-2">承認待ち点検</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="6" md="3">
          <v-card color="success" variant="tonal">
            <v-card-text class="text-center">
              <div class="text-h3">{{ dashboard.inspections.this_month }}</div>
              <div class="text-body-2">今月の点検数</div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <v-row>
        <!-- 直近の定期整備 -->
        <v-col cols="12" md="6">
          <v-card>
            <v-card-title>
              <v-icon class="mr-2">mdi-wrench</v-icon>
              直近の定期整備
              <v-chip class="ml-2" size="x-small" color="warning">{{ dashboard.maintenances.planned + dashboard.maintenances.in_progress }}件</v-chip>
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
                  <v-icon color="warning">mdi-calendar-clock</v-icon>
                </template>
              </v-list-item>
            </v-list>
            <v-card-text v-else>
              <div class="text-grey text-center">直近の予定なし</div>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- 在庫アラート -->
        <v-col cols="12" md="6">
          <v-card>
            <v-card-title>
              <v-icon class="mr-2">mdi-alert</v-icon>
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
                  <v-icon color="error">mdi-package-variant-minus</v-icon>
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
        <v-col cols="12" md="6" v-if="dashboard.troubles.critical > 0">
          <v-card color="error" variant="tonal">
            <v-card-title>
              <v-icon class="mr-2">mdi-alert-octagon</v-icon>
              緊急トラブル: {{ dashboard.troubles.critical }}件
            </v-card-title>
            <v-card-actions>
              <v-btn @click="router.push('/troubles')">トラブル一覧へ</v-btn>
            </v-card-actions>
          </v-card>
        </v-col>

        <!-- 修理状況 -->
        <v-col cols="12" md="6">
          <v-card>
            <v-card-title>
              <v-icon class="mr-2">mdi-tools</v-icon>
              修理・発注状況
            </v-card-title>
            <v-card-text>
              <div class="d-flex ga-4">
                <div>修理待ち: <strong>{{ dashboard.repairs.pending }}</strong></div>
                <div>修理中: <strong>{{ dashboard.repairs.in_repair }}</strong></div>
                <div>発注下書き: <strong>{{ dashboard.orders.draft }}</strong></div>
                <div>発注済: <strong>{{ dashboard.orders.ordered }}</strong></div>
              </div>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- 最近の発注 -->
        <v-col cols="12" md="6">
          <v-card>
            <v-card-title>
              <v-icon class="mr-2">mdi-cart</v-icon>
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
