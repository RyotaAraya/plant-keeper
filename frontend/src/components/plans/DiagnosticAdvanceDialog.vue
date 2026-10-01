<script setup lang="ts">
// 機器の診断（保守要求・仕様外）で、点検計画の次回期限を前倒しする候補の根拠を示し、権限のある人は期限を今日にできる。
// 候補はルールで出したもので（InspectionPlan.diagnostic_advance_candidates）、前倒しするかどうかは人が決める。
// 「計画」の点検の期限順と、計器の詳細で使う
import { ref, watch } from 'vue'
import api from '@/api/axios'
import DiagnosticChip from '@/components/DiagnosticChip.vue'
import { usePermissions } from '@/composables/usePermissions'
import { DIAGNOSTIC_STATUS } from '@/constants/diagnostics'
import type { DiagnosticAdvance, InspectionPlan } from '@/types/models'
import { todayForInput } from '@/utils/datetime'

const props = defineProps<{
  plan: Pick<InspectionPlan, 'id' | 'name' | 'next_due_on'> | null
  diagnostic: DiagnosticAdvance | null
  tagNumber?: string | null
}>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

const { canManageInspectionPlan } = usePermissions()
const errors = ref<string[]>([])
const saving = ref(false)

watch(open, (isOpen) => {
  if (isOpen) errors.value = []
})

const formatDateTime = (value: string) =>
  new Date(value).toLocaleString('ja-JP', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tokyo' })

async function advance() {
  if (!props.plan) return
  errors.value = []
  saving.value = true
  try {
    await api.patch(`/inspection_plans/${props.plan.id}`, { inspection_plan: { next_due_on: todayForInput() } })
    open.value = false
    emit('saved')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="560">
    <v-card v-if="plan && diagnostic" data-testid="diagnostic-advance-dialog">
      <v-card-title class="d-flex align-center ga-2 flex-wrap">
        <DiagnosticChip :status="diagnostic.diagnostic_status" />
        <span>{{ plan.name }}</span>
      </v-card-title>
      <v-card-text>
        <p class="text-body-2 mb-3">
          {{ tagNumber ?? '計器' }}が{{ formatDateTime(diagnostic.diagnostic_since) }}から「{{ DIAGNOSTIC_STATUS[diagnostic.diagnostic_status].label }}」です。
          {{ DIAGNOSTIC_STATUS[diagnostic.diagnostic_status].hint }}。
        </p>
        <p v-if="diagnostic.message || diagnostic.code" class="text-body-2 mb-3">
          機器の診断: {{ diagnostic.message }}<template v-if="diagnostic.code">（{{ diagnostic.code }}）</template>
        </p>
        <p class="text-body-2">
          次回期限は <strong>{{ plan.next_due_on }}</strong> です。診断が出てから点検していないため、前倒しの候補にしています。期限を変えるかどうかは人が決めます。
        </p>
        <v-alert v-if="errors.length" type="error" density="compact" class="mt-3">{{ errors.join('、') }}</v-alert>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">閉じる</v-btn>
        <v-btn v-if="canManageInspectionPlan" color="primary" :loading="saving" data-testid="diagnostic-advance-save" @click="advance">期限を今日にする</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
