<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import DetailHeader from '@/components/layout/DetailHeader.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import { useDetailTab } from '@/composables/useDetailTab'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const material = ref<any>(null)
const loading = ref(true)
// 詳細の中身は「概要 → タブ」（在庫状況は、在庫を見られる人だけ）
const tab = useDetailTab(() => [...(material.value?.stock_summary ? ['stock'] : []), 'orders'])

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
      <DetailHeader back-to="/materials" back-label="資材管理" kind="資材" :title="material.name" :subtitle="`型番 ${material.part_number}`" />

      <!-- 概要: 常に見える基本情報 -->
      <v-card class="mb-4 pk-summary" data-testid="detail-summary">
        <v-card-text>
          <dl class="pk-summary__grid">
            <div><dt>メーカー</dt><dd>{{ material.manufacturer?.name }}</dd></div>
            <div><dt>カテゴリ</dt><dd>{{ categoryLabel[material.category] }}</dd></div>
            <div><dt>入手性</dt><dd>{{ availabilityLabel[material.availability] }}</dd></div>
            <div><dt>定格</dt><dd>{{ material.rating || '—' }}</dd></div>
            <div><dt>リード日数</dt><dd>{{ material.lead_time_days ? `${material.lead_time_days}日` : '—' }}</dd></div>
            <div><dt>発注方式</dt><dd>{{ reorderLabel[material.reorder_method] || '—' }}</dd></div>
            <div><dt>発注点 / 数量</dt><dd>{{ material.reorder_point ?? '—' }} / {{ material.reorder_quantity ?? '—' }}</dd></div>
            <div>
              <dt>危険物</dt>
              <dd>
                <v-icon v-if="material.is_hazardous" color="error" size="small">mdi-alert</v-icon>
                {{ material.is_hazardous ? material.hazard_note || 'はい' : 'なし' }}
              </dd>
            </div>
            <div v-if="material.description" class="pk-summary__wide"><dt>説明</dt><dd style="white-space: pre-wrap">{{ material.description }}</dd></div>
          </dl>
        </v-card-text>
      </v-card>

      <!-- 在庫は自社のみ。見られない人には項目自体が返らない -->
      <v-tabs v-model="tab" class="mb-4">
        <v-tab v-if="material.stock_summary" value="stock">在庫状況</v-tab>
        <v-tab value="orders">最近の発注（{{ material.recent_orders?.length ?? 0 }}）</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item v-if="material.stock_summary" value="stock">
          <v-card variant="outlined">
            <v-card-text>
              <div class="text-h4 text-center mb-2 pk-mono">{{ material.usable_stock }}</div>
              <div class="text-caption text-center text-grey mb-3">
                利用可の在庫数（全拠点）
                <template v-if="material.total_stock !== material.usable_stock">／ 使用中・修理中などを含む合計 {{ material.total_stock }}</template>
              </div>
              <v-table v-if="material.stock_summary.length" density="compact">
                <thead>
                  <tr>
                    <th>拠点・倉庫</th>
                    <th width="80" class="text-right">利用可</th>
                    <th width="80" class="text-right">合計</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="s in material.stock_summary" :key="`${s.site_id}-${s.warehouse}`">
                    <td>
                      {{ s.site_name }} {{ s.warehouse }}
                      <span v-if="s.site_id === authStore.user?.site_id" class="pk-site-tag ml-1">所属拠点</span>
                    </td>
                    <td class="text-right pk-mono">{{ s.usable_quantity }}</td>
                    <td class="text-right pk-mono">{{ s.quantity }}</td>
                  </tr>
                </tbody>
              </v-table>
              <div v-else class="text-center text-grey">在庫なし</div>
            </v-card-text>
          </v-card>
        </v-window-item>
        <v-window-item value="orders">
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
        </v-window-item>
      </v-window>
    </template>
  </MainLayout>
</template>
