<script setup lang="ts">
// 校正の作業指示の書き出し。表示中の拠点の、5点校正のある点検計画を期限順に並べ、選んだ計画を作業指示のファイル（JSON）にする。
// 校正ソフトが結果の記録に計画のID（inspection_plan_id）を入れて返せば、「校正結果の取り込み」でその計画の点検の下書きになる。
// 書き出しても計画の期限は変わらない（進むのは、取り込んだ点検を提出したとき）
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import StatusChip from '@/components/StatusChip.vue'
import { dueColor, dueLabel } from '@/utils/inspectionPlan'
import { downloadBlob } from '@/utils/download'

type Candidate = {
  id: number
  name: string
  next_due_on: string
  overdue: boolean
  days_until_due: number
  last_inspected_on: string | null
  interval_days: number
  site: { id: number; name: string }
  equipment: { id: number; name: string }
  instrument: { id: number; tag_number: string }
  checklist_template: { id: number; name: string }
}

// 期限超過と、この日数以内に期限が来る計画を、はじめから選んでおく
const PRESELECT_DAYS = 30

const props = defineProps<{ siteIds: number[] }>()
const open = defineModel<boolean>({ default: false })

const candidates = ref<Candidate[]>([])
const selected = ref<number[]>([])
const errors = ref<string[]>([])
const exported = ref<{ fileName: string; count: number } | null>(null)
const loading = ref(false)
const exporting = ref(false)

// 拠点が1つに決まらないときは、拠点の列を出す
const headers = computed(() => [
  { title: '期限', key: 'next_due_on', width: '170px' },
  { title: '計器', key: 'instrument.tag_number', width: '110px' },
  { title: '点検計画', key: 'name' },
  ...(props.siteIds.length === 1 ? [] : [{ title: '拠点', key: 'site.name', width: '130px' }]),
  { title: '前回実施', key: 'last_inspected_on', width: '110px' },
])

watch(open, async (isOpen) => {
  if (!isOpen) return
  candidates.value = []
  selected.value = []
  errors.value = []
  exported.value = null
  loading.value = true
  try {
    const res = await api.get('/calibration_work_orders', { params: props.siteIds.length ? { site_ids: props.siteIds } : {} })
    candidates.value = res.data.data
    selected.value = candidates.value.filter((plan) => plan.days_until_due <= PRESELECT_DAYS).map((plan) => plan.id)
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['点検計画を読み込めませんでした']
  } finally {
    loading.value = false
  }
})

async function runExport() {
  errors.value = []
  exported.value = null
  exporting.value = true
  try {
    const res = await api.post('/calibration_work_orders', { inspection_plan_ids: selected.value })
    const { file_name: fileName, document } = res.data.data
    downloadBlob(fileName, new globalThis.Blob([JSON.stringify(document, null, 2)], { type: 'application/json' }))
    exported.value = { fileName, count: document.work_orders.length }
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['書き出しに失敗しました']
  } finally {
    exporting.value = false
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="880" scrollable>
    <v-card data-testid="calibration-work-order">
      <v-card-title>校正の作業指示の書き出し</v-card-title>
      <v-card-text>
        <div class="text-body-2 text-medium-emphasis mb-3">
          5点校正のある点検計画を、キャリブレータ・校正管理ソフトに渡すファイル（JSON）にします。
          結果の記録に計画のID（inspection_plan_id）を入れて返すと、「校正結果の取り込み」でその計画の点検の下書きになります。下書きを提出すると、次回期限が進みます。
          期限超過と{{ PRESELECT_DAYS }}日以内に期限が来る計画を選んであります。
        </div>

        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-alert v-if="exported" type="success" variant="tonal" density="compact" class="mb-4" data-testid="calibration-work-order-result">
          {{ exported.count }}件の作業指示を「{{ exported.fileName }}」に書き出しました
        </v-alert>

        <v-data-table
          v-model="selected"
          :headers="headers"
          :items="candidates"
          :loading="loading"
          item-value="id"
          show-select
          density="compact"
          :items-per-page="-1"
          hide-default-footer
          no-data-text="5点校正のある点検計画はありません"
          data-testid="calibration-work-order-plans"
        >
          <template #item.next_due_on="{ item }">
            <StatusChip :label="dueLabel(item)" :color="dueColor(item)" :alert="item.overdue" />
          </template>
          <template #item.name="{ item }">
            <div>{{ item.name }}</div>
            <div class="text-caption text-medium-emphasis">{{ item.equipment.name }} ・ {{ item.checklist_template.name }}</div>
          </template>
          <template #item.last_inspected_on="{ item }">{{ item.last_inspected_on ?? '未実施' }}</template>
        </v-data-table>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">閉じる</v-btn>
        <v-btn color="primary" prepend-icon="mdi-download" :disabled="!selected.length" :loading="exporting" @click="runExport">
          {{ selected.length }}件を書き出す
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
