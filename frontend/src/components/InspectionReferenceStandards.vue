<script setup lang="ts">
// 点検で使った基準器と、使用前の1点チェックの入力。点検日に使えるか（校正の有効期限・状態・トレーサビリティ）を、
// 選んだ時点で表示する（提出時の確認はサーバーが行い、使えないものが含まれると提出できない）
import { computed, nextTick, ref } from 'vue'
import type { InspectionReferenceStandardUse, ReferenceStandard } from '@/types/models'
import { STATUS_COLOR, STATUS_LABEL, calibrationOn, unusableReasons } from '@/utils/referenceStandard'

const props = defineProps<{ standards: ReferenceStandard[]; inspectionDate: string; requireTraceable: boolean }>()
const model = defineModel<InspectionReferenceStandardUse[]>({ required: true })

const picked = ref<number | null>(null)
const byId = computed(() => new Map(props.standards.map((s) => [s.id, s])))
// 追加できるのは、まだ選んでいない基準器（自拠点のものが先頭に来るよう、並びは一覧のまま）
const options = computed(() =>
  props.standards
    .filter((s) => !model.value.some((use) => use.reference_standard_id === s.id))
    .map((s) => ({ id: s.id, title: `${s.management_number}  ${s.name}`, subtitle: `${s.site?.name ?? ''}／${STATUS_LABEL[s.status]}` })),
)

async function add(id: number | null) {
  if (!id) return
  model.value = [...model.value, { reference_standard_id: id, pre_check_passed: null, pre_check_note: '' }]
  await nextTick()
  picked.value = null
}

function remove(index: number) {
  model.value = model.value.filter((_, i) => i !== index)
}

const reasonsFor = (use: InspectionReferenceStandardUse) => {
  const standard = byId.value.get(use.reference_standard_id)
  return standard && props.inspectionDate ? unusableReasons(standard, props.inspectionDate, props.requireTraceable) : []
}
</script>

<template>
  <v-card variant="outlined" class="mb-4" data-testid="reference-standards-section">
    <v-card-text>
      <h2 class="text-subtitle-1">使用した基準器</h2>
      <div class="text-caption text-medium-emphasis mb-3">
        校正に使った基準器と、使用前の1点チェックの結果を記録します。提出するときに、点検日に使える基準器か（校正の有効期限・状態・使用前のチェック）を確認し、5点校正の測定値を提出するには基準器の指定が必要です。
      </div>
      <v-alert v-if="requireTraceable" type="info" variant="tonal" density="compact" class="mb-3">
        この点検には取引用の計器が含まれるため、トレーサビリティのある校正の基準器が必要です。
      </v-alert>

      <v-autocomplete
        v-model="picked"
        :items="options"
        item-title="title"
        item-value="id"
        :item-props="(o: any) => ({ subtitle: o.subtitle })"
        label="基準器を追加"
        density="compact"
        hide-details
        clearable
        @update:model-value="add"
      />

      <v-table v-if="model.length" density="compact" class="mt-3">
        <thead>
          <tr>
            <th>基準器</th>
            <th>点検日時点の校正</th>
            <th>使用前の1点チェック</th>
            <th>備考</th>
            <th />
          </tr>
        </thead>
        <tbody>
          <tr v-for="(use, i) in model" :key="use.reference_standard_id" :data-testid="`reference-standard-${byId.get(use.reference_standard_id)?.management_number}`">
            <td class="text-no-wrap">
              {{ byId.get(use.reference_standard_id)?.management_number }} {{ byId.get(use.reference_standard_id)?.name }}
              <v-chip v-if="byId.get(use.reference_standard_id)" :color="STATUS_COLOR[byId.get(use.reference_standard_id)!.status]" size="x-small" label variant="tonal" class="ml-1">
                {{ STATUS_LABEL[byId.get(use.reference_standard_id)!.status] }}
              </v-chip>
            </td>
            <td>
              <template v-if="reasonsFor(use).length">
                <div v-for="reason in reasonsFor(use)" :key="reason" class="text-error text-caption">{{ reason }}</div>
              </template>
              <template v-else-if="byId.get(use.reference_standard_id) && calibrationOn(byId.get(use.reference_standard_id)!, inspectionDate)">
                <span class="text-caption">
                  {{ calibrationOn(byId.get(use.reference_standard_id)!, inspectionDate)!.performed_by }}・
                  {{ calibrationOn(byId.get(use.reference_standard_id)!, inspectionDate)!.certificate_number || '証明書番号なし' }}・
                  {{ calibrationOn(byId.get(use.reference_standard_id)!, inspectionDate)!.valid_until }}まで有効
                </span>
              </template>
            </td>
            <td>
              <v-btn-toggle v-model="use.pre_check_passed" density="compact" variant="outlined" divided color="primary">
                <v-btn :value="true" size="small">OK</v-btn>
                <v-btn :value="false" size="small">NG</v-btn>
              </v-btn-toggle>
              <span v-if="use.pre_check_passed === null" class="text-caption text-medium-emphasis ml-2">未確認</span>
            </td>
            <td style="min-width: 200px">
              <v-text-field v-model="use.pre_check_note" density="compact" variant="outlined" hide-details single-line placeholder="例: 0kPa・100kPaで確認" />
            </td>
            <td><v-btn icon="mdi-close" size="x-small" variant="text" aria-label="基準器を外す" @click="remove(i)" /></td>
          </tr>
        </tbody>
      </v-table>
    </v-card-text>
  </v-card>
</template>
