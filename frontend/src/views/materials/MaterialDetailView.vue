<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const route = useRoute()
const router = useRouter()
const material = ref<any>(null)
const loading = ref(true)

const categoryLabel: Record<string, string> = {
  instrument: '計装', valve: 'バルブ', electrical: '電気', piping: '配管'
}
const availabilityLabel: Record<string, string> = {
  custom: '特注', catalog: 'カタログ', commodity: '汎用'
}
const reorderLabel: Record<string, string> = {
  reorder_point: '発注点方式', use_based: '使用時発注'
}

async function fetchMaterial() {
  loading.value = true
  try {
    const res = await api.get(`/materials/${route.params.id}`)
    material.value = res.data.data
  } finally {
    loading.value = false
  }
}

onMounted(fetchMaterial)
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="material">
      <div class="d-flex align-center mb-4">
        <v-btn icon="mdi-arrow-left" variant="text" @click="router.push('/materials')" />
        <h1 class="text-h5 ml-2">{{ material.name }}</h1>
        <v-chip class="ml-3" size="small">{{ material.part_number }}</v-chip>
      </div>

      <v-card class="mb-4">
        <v-card-text>
          <v-row>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">メーカー</div>
              <div>{{ material.manufacturer?.name }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">カテゴリ</div>
              <div>{{ categoryLabel[material.category] }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">入手性</div>
              <div>{{ availabilityLabel[material.availability] }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">定格</div>
              <div>{{ material.rating || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">リード日数</div>
              <div>{{ material.lead_time_days ? `${material.lead_time_days}日` : '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">発注方式</div>
              <div>{{ reorderLabel[material.reorder_method] || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">発注点 / 数量</div>
              <div>{{ material.reorder_point ?? '—' }} / {{ material.reorder_quantity ?? '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">危険物</div>
              <div>
                <v-icon v-if="material.is_hazardous" color="error" size="small">mdi-alert</v-icon>
                {{ material.is_hazardous ? material.hazard_note || 'はい' : 'なし' }}
              </div>
            </v-col>
          </v-row>
          <div v-if="material.description" class="mt-3">
            <div class="text-caption text-grey">説明</div>
            <div>{{ material.description }}</div>
          </div>
        </v-card-text>
      </v-card>

      <v-row>
        <v-col cols="12" md="6">
          <h2 class="text-h6 mb-3">在庫状況</h2>
          <v-card variant="outlined">
            <v-card-text>
              <div class="text-h4 text-center mb-2">{{ material.total_stock }}</div>
              <div class="text-caption text-center text-grey mb-3">合計在庫数</div>
              <v-table v-if="material.stock_summary?.length" density="compact">
                <thead><tr><th>倉庫</th><th width="80" class="text-right">数量</th></tr></thead>
                <tbody>
                  <tr v-for="s in material.stock_summary" :key="s.warehouse">
                    <td>{{ s.warehouse }}</td>
                    <td class="text-right">{{ s.quantity }}</td>
                  </tr>
                </tbody>
              </v-table>
              <div v-else class="text-center text-grey">在庫なし</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="12" md="6">
          <h2 class="text-h6 mb-3">最近の発注</h2>
          <v-card variant="outlined">
            <v-list v-if="material.recent_orders?.length" density="compact">
              <v-list-item
                v-for="order in material.recent_orders"
                :key="order.id"
                :title="`${order.supplier_name} — ${order.quantity}個`"
                :subtitle="`${order.ordered_on} / ${order.user?.name}`"
                @click="router.push('/orders')"
              >
                <template #append>
                  <v-chip size="x-small">{{ order.status }}</v-chip>
                </template>
              </v-list-item>
            </v-list>
            <v-card-text v-else>
              <div class="text-center text-grey">発注履歴なし</div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </template>
  </MainLayout>
</template>
