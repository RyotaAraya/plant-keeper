<script setup lang="ts">
// 「計画」画面で開いた、点検のまとまりの中身（子の点検計画）。計画ごとの周期・次回期限と、点検の実施・周期の見直し
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import IntervalReviewDialog from '@/components/IntervalReviewDialog.vue'
import InspectionPlanDialog from '@/components/plans/InspectionPlanDialog.vue'
import { usePermissions } from '@/composables/usePermissions'
import type { InspectionPlan, InspectionPlanGroup } from '@/types/models'
import { equipmentNames } from '@/utils/equipment'
import { dueColor, dueLabel, inspectionFromPlan, referenceStandardFromPlan } from '@/utils/inspectionPlan'
import { REVIEW_COLOR, REVIEW_LABEL } from '@/utils/intervalReview'

const props = defineProps<{ group: InspectionPlanGroup; equipments: { id: number; name: string; site_id: number }[] }>()
const emit = defineEmits<{ changed: [] }>()

const router = useRouter()
const { canManageInspectionPlan, canManageReferenceStandard } = usePermissions()
const plans = ref<InspectionPlan[]>([])
const loading = ref(true)
const addDialog = ref(false)
const reviewDialog = ref(false)
const reviewing = ref<InspectionPlan | null>(null)

async function load() {
  loading.value = true
  try {
    const res = await api.get('/inspection_plans', { params: { inspection_plan_group_ids: [props.group.id], per_page: 1000 } })
    plans.value = res.data.data
  } finally {
    loading.value = false
  }
}

function reload() {
  load()
  emit('changed') // 親の行の件数・期限も変わる
}

function openReview(plan: InspectionPlan) {
  reviewing.value = plan
  reviewDialog.value = true
}

onMounted(load)
</script>

<template>
  <div class="pk-group-plans" :data-testid="`group-plans-${group.id}`">
    <div v-if="loading" class="text-medium-emphasis text-body-2 pa-2">読み込み中…</div>
    <div v-else-if="!plans.length" class="text-medium-emphasis text-body-2 pa-2">有効な計画はありません。</div>
    <v-table v-else density="compact">
      <thead>
        <tr>
          <th style="width: 200px">期限</th>
          <th>点検計画</th>
          <th>設備・基準器</th>
          <th style="width: 90px">計器</th>
          <th style="width: 100px">周期</th>
          <th style="width: 110px">見直し</th>
          <th style="width: 130px" />
        </tr>
      </thead>
      <tbody>
        <tr v-for="plan in plans" :key="plan.id">
          <td><v-chip :color="dueColor(plan)" size="small">{{ dueLabel(plan) }}</v-chip></td>
          <td>{{ plan.name }}</td>
          <td>{{ plan.reference_standard ? plan.reference_standard.name : equipmentNames(plan) }}</td>
          <td>{{ plan.instrument?.tag_number }}</td>
          <td class="text-no-wrap">{{ plan.interval_days }}日ごと</td>
          <td>
            <v-chip
              v-if="plan.interval_review"
              :color="REVIEW_COLOR[plan.interval_review.kind]"
              size="small"
              label
              variant="flat"
              append-icon="mdi-chevron-right"
              @click="openReview(plan)"
            >
              {{ REVIEW_LABEL[plan.interval_review.kind] }}
            </v-chip>
          </td>
          <td class="text-right">
            <v-btn v-if="plan.reference_standard" size="small" variant="outlined" @click="router.push(referenceStandardFromPlan(plan, canManageReferenceStandard))">
              {{ canManageReferenceStandard ? '校正を記録' : '基準器を見る' }}
            </v-btn>
            <v-btn v-else size="small" variant="outlined" @click="router.push(inspectionFromPlan(plan))">点検を実施</v-btn>
          </td>
        </tr>
      </tbody>
    </v-table>
    <div v-if="canManageInspectionPlan" class="pa-2">
      <v-btn size="small" variant="text" color="primary" prepend-icon="mdi-plus" @click="addDialog = true">このまとまりに計画を追加</v-btn>
    </div>

    <InspectionPlanDialog v-model="addDialog" :equipments="equipments" :groups="[group]" :group-id="group.id" @saved="reload" />
    <IntervalReviewDialog v-model="reviewDialog" :plan="reviewing" @saved="reload" />
  </div>
</template>

<style scoped>
.pk-group-plans { padding: 4px 0 8px 32px; }
.pk-group-plans :deep(table) { background: transparent; }
</style>
