<script setup lang="ts">
// 点検計画の周期の見直しの候補（延長・短縮）の根拠を示し、権限のある人は周期を変えられる。
// 候補はルールで出したもので、変えるかどうかは人が決める
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import { usePermissions } from '@/composables/usePermissions'
import type { InspectionPlan } from '@/types/models'
import { intervalLabel } from '@/utils/interval'
import { REVIEW_COLOR, REVIEW_LABEL } from '@/utils/intervalReview'

const props = defineProps<{ plan: InspectionPlan | null }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

const { canManageInspectionPlan } = usePermissions()
const review = computed(() => props.plan?.interval_review ?? null)
const intervalDays = ref(0)
const errors = ref<string[]>([])
const saving = ref(false)

watch(open, (isOpen) => {
  if (!isOpen || !review.value) return
  intervalDays.value = review.value.suggested_interval_days
  errors.value = []
})

// 周期を変えたときの次回期限（前回実施から新しい周期。前回がなければ今の期限のまま）
const nextDueOn = computed(() => {
  const last = props.plan?.last_inspected_on
  if (!last || !intervalDays.value) return props.plan?.next_due_on ?? ''
  const d = new Date(`${last}T00:00:00`)
  d.setDate(d.getDate() + Number(intervalDays.value))
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
})

const formatDate = (value: string) => new Date(value).toLocaleDateString('ja-JP', { timeZone: 'Asia/Tokyo' })

async function save() {
  if (!props.plan) return
  errors.value = []
  saving.value = true
  try {
    await api.patch(`/inspection_plans/${props.plan.id}`, { inspection_plan: { interval_days: intervalDays.value, next_due_on: nextDueOn.value } })
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
  <v-dialog v-model="open" max-width="640" scrollable>
    <v-card v-if="plan && review" data-testid="interval-review-dialog">
      <v-card-title class="d-flex align-center ga-2">
        <v-chip :color="REVIEW_COLOR[review.kind]" size="small" label variant="flat">{{ REVIEW_LABEL[review.kind] }}</v-chip>
        <span>{{ plan.name }}</span>
      </v-card-title>
      <v-card-text>
        <p class="text-body-2 mb-3">いまの周期は <strong>{{ intervalLabel(plan.interval_days) }}</strong>。5点校正の記録から、次の理由で見直しの候補にしています（決めるのは人です）。</p>
        <ul class="mb-3 ml-5">
          <li v-for="reason in review.reasons" :key="reason">{{ reason }}</li>
        </ul>
        <v-alert v-for="caution in review.cautions" :key="caution" type="warning" variant="tonal" density="compact" class="mb-3">{{ caution }}</v-alert>

        <div class="text-caption text-medium-emphasis mb-1">根拠にした校正（調整前の最大誤差・許容差 ±{{ review.tolerance_percent }}%）</div>
        <v-table density="compact" class="mb-3">
          <tbody>
            <tr v-for="row in review.evidence" :key="row.inspection_id">
              <td class="text-no-wrap">{{ formatDate(row.inspected_at) }}</td>
              <td>{{ row.as_found.max_error?.toFixed(2) ?? '—' }}%</td>
              <td>{{ row.as_found.result === 'fail' ? '不合格' : '合格' }}</td>
              <td>{{ row.adjusted ? '調整あり' : '調整なし' }}</td>
            </tr>
          </tbody>
        </v-table>
        <router-link v-if="plan.instrument" :to="`/instruments/${plan.instrument.id}`" class="text-body-2">{{ plan.instrument.tag_number }} の校正の傾向を見る</router-link>

        <template v-if="canManageInspectionPlan">
          <v-divider class="my-4" />
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-3">{{ errors.join('、') }}</v-alert>
          <v-text-field
            v-model.number="intervalDays"
            label="新しい周期（日）"
            type="number"
            min="1"
            :hint="`目安は ${intervalLabel(review.suggested_interval_days)}。変えると次回期限は ${nextDueOn} になります`"
            persistent-hint
            data-testid="interval-review-days"
          />
        </template>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">閉じる</v-btn>
        <v-btn v-if="canManageInspectionPlan" color="primary" :loading="saving" data-testid="interval-review-save" @click="save">周期を変更</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
