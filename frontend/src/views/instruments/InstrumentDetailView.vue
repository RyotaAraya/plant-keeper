<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const route = useRoute()
const router = useRouter()

const instrument = ref<any>(null)
const loading = ref(false)
const tab = ref('info')

const statusLabel: Record<string, string> = {
  open: '未対応', in_progress: '対応中', resolved: '解決済', closed: 'クローズ'
}
const priorityLabel: Record<string, string> = {
  low: '低', medium: '中', high: '高', critical: '緊急'
}
const priorityColor: Record<string, string> = {
  low: 'info', medium: 'warning', high: 'error', critical: 'error'
}
const inspectionStatusLabel: Record<string, string> = {
  draft: '下書き', submitted: '提出済', approval_requested: '承認依頼中', approved: '承認済'
}

async function fetchInstrument() {
  loading.value = true
  try {
    const res = await api.get(`/instruments/${route.params.id}`)
    instrument.value = res.data.data
  } finally {
    loading.value = false
  }
}

onMounted(fetchInstrument)
</script>

<template>
  <MainLayout>
    <v-btn variant="text" prepend-icon="mdi-arrow-left" class="mb-2" @click="router.push('/instruments')">
      計器一覧に戻る
    </v-btn>

    <v-skeleton-loader v-if="loading" type="card" />

    <template v-else-if="instrument">
      <v-card class="mb-4">
        <v-card-title>{{ instrument.tag_number }}</v-card-title>
        <v-card-subtitle>
          {{ instrument.equipment?.name }} / {{ instrument.equipment?.site?.name }}
        </v-card-subtitle>
        <v-card-text>
          <v-row>
            <v-col cols="12" md="3"><strong>種別:</strong> {{ instrument.instrument_type }}</v-col>
            <v-col cols="12" md="3"><strong>サービス:</strong> {{ instrument.service?.name || '—' }}</v-col>
            <v-col cols="12" md="3"><strong>ラインクラス:</strong> {{ instrument.line_class?.code || '—' }}</v-col>
            <v-col cols="12" md="3"><strong>設置場所:</strong> {{ instrument.location || '—' }}</v-col>
          </v-row>
          <v-row v-if="instrument.service" class="mt-2">
            <v-col cols="12" md="3"><strong>温度:</strong> {{ instrument.service.temperature }}</v-col>
            <v-col cols="12" md="3"><strong>圧力:</strong> {{ instrument.service.pressure }}</v-col>
            <v-col cols="12" md="3">
              <strong>危険性:</strong>
              <v-chip :color="instrument.service.hazard_level === 'high' ? 'error' : instrument.service.hazard_level === 'medium' ? 'warning' : 'success'" size="small">
                {{ { high: '高', medium: '中', low: '低' }[instrument.service.hazard_level as string] }}
              </v-chip>
            </v-col>
          </v-row>
          <p v-if="instrument.notes" class="mt-3"><strong>備考:</strong> {{ instrument.notes }}</p>
        </v-card-text>
      </v-card>

      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="troubles">トラブル履歴</v-tab>
        <v-tab value="inspections">点検履歴</v-tab>
      </v-tabs>

      <v-window v-model="tab">
        <v-window-item value="troubles">
          <v-list v-if="(instrument.recent_troubles || []).length">
            <v-list-item
              v-for="t in instrument.recent_troubles"
              :key="t.id"
              :title="t.title"
              :subtitle="t.reported_at?.slice(0, 10)"
            >
              <template #append>
                <v-chip :color="priorityColor[t.priority] || 'grey'" size="small" class="mr-2">
                  {{ priorityLabel[t.priority] || t.priority }}
                </v-chip>
                <v-chip size="small">{{ statusLabel[t.status] || t.status }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
          <p v-else class="text-body-2 text-grey ml-4">トラブル履歴なし</p>
        </v-window-item>

        <v-window-item value="inspections">
          <v-list v-if="(instrument.recent_inspections || []).length">
            <v-list-item
              v-for="i in instrument.recent_inspections"
              :key="i.id"
              :title="i.inspection_type"
              :subtitle="i.inspected_at?.slice(0, 10)"
            >
              <template #append>
                <v-chip size="small">{{ inspectionStatusLabel[i.status] || i.status }}</v-chip>
              </template>
            </v-list-item>
          </v-list>
          <p v-else class="text-body-2 text-grey ml-4">点検履歴なし</p>
        </v-window-item>
      </v-window>
    </template>
  </MainLayout>
</template>
