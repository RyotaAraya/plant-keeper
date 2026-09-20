<script setup lang="ts">
// 「次回を作る」: 系列の周期から提案された名称・日付・対象設備を確認して直し、次回の定期整備を複製で作る。
// 対象設備は、周期が来ているものが最初から選ばれている（理由が付く）。系列に属さない整備は、日付を入力する
import { ref, watch } from 'vue'
import api from '@/api/axios'

const props = defineProps<{ maintenanceId: number }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ created: [id: number] }>()

type Candidate = { id: number; name: string; included: boolean; reason: string }
const form = ref({ title: '', planned_start_on: '', planned_end_on: '' })
const candidates = ref<Candidate[]>([])
const assignmentsCount = ref(0)
const loading = ref(false)
const errors = ref<string[]>([])

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  loading.value = true
  try {
    const res = await api.get(`/scheduled_maintenances/${props.maintenanceId}/next_suggestion`)
    const s = res.data.data
    form.value = { title: s.title, planned_start_on: s.planned_start_on ?? '', planned_end_on: s.planned_end_on ?? '' }
    candidates.value = s.equipments
    assignmentsCount.value = s.assignments_count
  } finally {
    loading.value = false
  }
})

async function create() {
  errors.value = []
  try {
    const res = await api.post(`/scheduled_maintenances/${props.maintenanceId}/duplicate`, {
      scheduled_maintenance: { ...form.value, equipment_ids: candidates.value.filter((c) => c.included).map((c) => c.id) },
    })
    open.value = false
    emit('created', res.data.data.id)
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['作成に失敗しました']
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="640" scrollable>
    <v-card>
      <v-card-title>次回を作る</v-card-title>
      <v-card-text>
        <v-progress-linear v-if="loading" indeterminate />
        <template v-else>
          <div class="text-caption text-medium-emphasis mb-3">
            系列の周期から、次回の名称・日付・対象設備を提案しました。確認して、必要なら直してください。担当者（{{ assignmentsCount }}人）と説明は引き継ぎ、状態は計画中で作ります。
          </div>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="form.title" label="名称 *" class="mb-2" />
          <v-row dense>
            <v-col cols="6"><v-text-field v-model="form.planned_start_on" label="予定 開始日 *" type="date" /></v-col>
            <v-col cols="6"><v-text-field v-model="form.planned_end_on" label="予定 終了日" type="date" /></v-col>
          </v-row>
          <div class="text-subtitle-2 mt-2 mb-1">対象設備</div>
          <div v-for="candidate in candidates" :key="candidate.id" class="d-flex align-center" :data-testid="`candidate-${candidate.name}`">
            <v-checkbox v-model="candidate.included" :label="candidate.name" density="compact" hide-details />
            <span class="text-caption text-medium-emphasis ml-2">{{ candidate.reason }}</span>
          </div>
        </template>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" :disabled="loading" @click="create">作成</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
