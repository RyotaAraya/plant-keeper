<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const route = useRoute()
const router = useRouter()
const inspection = ref<any>(null)
const loading = ref(true)

const inspectionTypeLabel: Record<string, string> = {
  routine: '日常点検', periodic: '定期点検', telemetry: 'テレメトリ', operation_check: '運転チェック'
}

const statusLabel: Record<string, string> = {
  draft: '下書き', submitted: '提出済', approval_requested: '承認待ち', approved: '承認済'
}

const statusColor: Record<string, string> = {
  draft: 'grey', submitted: 'info', approval_requested: 'warning', approved: 'success'
}

const itemTypeLabel: Record<string, string> = {
  check: 'チェック', measurement: '計測値', text: 'テキスト'
}

const defectItems = computed(() => {
  if (!inspection.value?.inspection_items) return []
  return inspection.value.inspection_items.filter((i: any) => i.has_defect)
})

async function fetchInspection() {
  loading.value = true
  try {
    const res = await api.get(`/inspections/${route.params.id}`)
    inspection.value = res.data.data
  } finally {
    loading.value = false
  }
}

async function updateStatus(status: string) {
  await api.patch(`/inspections/${route.params.id}`, { inspection: { status } })
  await fetchInspection()
}

function formatDate(dt: string) {
  if (!dt) return ''
  return new Date(dt).toLocaleString('ja-JP', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' })
}

onMounted(fetchInspection)
</script>

<template>
  <MainLayout>
    <v-progress-linear v-if="loading" indeterminate />
    <template v-else-if="inspection">
      <div class="d-flex align-center mb-4">
        <v-btn icon="mdi-arrow-left" variant="text" @click="router.push('/inspections')" />
        <h1 class="text-h5 ml-2">点検記録詳細</h1>
        <v-spacer />
        <v-btn v-if="inspection.status === 'draft'" class="mr-2" variant="outlined" @click="router.push(`/inspections/${inspection.id}/edit`)">
          <v-icon start>mdi-pencil</v-icon>編集
        </v-btn>
        <v-btn v-if="inspection.status === 'draft'" color="primary" @click="updateStatus('submitted')">提出</v-btn>
        <v-btn v-if="inspection.status === 'submitted'" color="warning" @click="updateStatus('approval_requested')">承認依頼</v-btn>
        <v-btn v-if="inspection.status === 'approval_requested'" color="success" @click="updateStatus('approved')">承認</v-btn>
      </div>

      <v-card class="mb-4">
        <v-card-text>
          <v-row>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">点検日時</div>
              <div>{{ formatDate(inspection.inspected_at) }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">種別</div>
              <div>{{ inspectionTypeLabel[inspection.inspection_type] }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">ステータス</div>
              <v-chip :color="statusColor[inspection.status]" size="small">
                {{ statusLabel[inspection.status] }}
              </v-chip>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">実施者</div>
              <div>{{ inspection.user?.name }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">設備</div>
              <div>
                <a class="text-primary" style="cursor:pointer" @click="router.push(`/equipments/${inspection.equipment?.id}`)">
                  {{ inspection.equipment?.name }}
                </a>
              </div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">計器</div>
              <div>{{ inspection.instrument?.tag_number || '—' }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">部署</div>
              <div>{{ inspection.department?.name }}</div>
            </v-col>
            <v-col cols="6" md="3">
              <div class="text-caption text-grey">テンプレート</div>
              <div>{{ inspection.checklist_template?.name || '—' }}</div>
            </v-col>
          </v-row>
          <div v-if="inspection.notes" class="mt-3">
            <div class="text-caption text-grey">備考</div>
            <div style="white-space: pre-wrap">{{ inspection.notes }}</div>
          </div>
        </v-card-text>
      </v-card>

      <h2 class="text-h6 mb-3">点検項目</h2>
      <v-table density="compact">
        <thead>
          <tr>
            <th width="40">#</th>
            <th>内容</th>
            <th width="100">種別</th>
            <th width="120">結果</th>
            <th width="80">不具合</th>
            <th width="120">計器</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in inspection.inspection_items" :key="item.id" :class="{ 'bg-red-lighten-5': item.has_defect }">
            <td>{{ item.position }}</td>
            <td>{{ item.content }}</td>
            <td>{{ itemTypeLabel[item.item_type] }}</td>
            <td>
              <template v-if="item.item_type === 'check'">
                <v-icon :color="item.checked ? 'success' : 'grey'">{{ item.checked ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
              </template>
              <template v-else-if="item.item_type === 'measurement'">
                {{ item.measured_value || '—' }}
              </template>
              <template v-else>
                {{ item.text_value || '—' }}
              </template>
            </td>
            <td>
              <v-chip v-if="item.has_defect" color="error" size="x-small">
                <v-icon start size="x-small">mdi-alert</v-icon>あり
              </v-chip>
            </td>
            <td>{{ item.instrument?.tag_number || '' }}</td>
          </tr>
        </tbody>
      </v-table>

      <template v-if="defectItems.length">
        <h2 class="text-h6 mt-6 mb-3">不具合 → トラブル連携</h2>
        <v-list>
          <v-list-item
            v-for="item in defectItems"
            :key="item.id"
            :title="item.trouble?.title || `不具合（項目${item.position}）`"
            :subtitle="item.content"
            @click="item.trouble && router.push(`/troubles/${item.trouble.id}`)"
          >
            <template #prepend>
              <v-icon color="error">mdi-alert-circle</v-icon>
            </template>
            <template #append v-if="item.trouble">
              <v-chip size="x-small" color="primary">トラブル #{{ item.trouble.id }}</v-chip>
            </template>
          </v-list-item>
        </v-list>
      </template>
    </template>
  </MainLayout>
</template>
