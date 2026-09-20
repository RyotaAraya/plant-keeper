<script setup lang="ts">
// 5点校正の表。計器の校正条件（範囲・許容差・出力特性・DCS換算）から各点の期待値を求め、
// 入力した出力・DCS表示との誤差と、許容差に対する合否（上昇と下降の差=ヒステリシスも）をその場で表示する。
// 調整前と調整後を分けて記録し、調整した場合は調整後が最終の判定になる
import { computed, ref } from 'vue'
import type { CalibrationInput, CalibrationSnapshot } from '@/types/models'
import {
  CHARACTERISTIC_LABEL,
  DIRECTIONS,
  DIRECTION_LABEL,
  RESULT_COLOR,
  RESULT_LABEL,
  STAGES,
  STAGE_LABEL,
  TOLERANCE_BASIS_LABEL,
  dcsUnit,
  evaluateCalibration,
  outputUnit,
  type Stage,
} from '@/utils/calibration'

const props = defineProps<{ snapshot: CalibrationSnapshot | null; readonly?: boolean }>()
const model = defineModel<CalibrationInput>({ required: true })

const stage = ref<Stage>('as_found')
const evaluation = computed(() => (props.snapshot ? evaluateCalibration(props.snapshot, model.value) : null))
// 調整後は、調整した場合（または調整後の値が入っている記録）だけ表示する
const showAsLeft = computed(() => model.value.adjusted || evaluation.value?.stages.as_left.result !== 'empty')
const activeStage = computed<Stage>(() => (stage.value === 'as_left' && !showAsLeft.value ? 'as_found' : stage.value))
const rows = computed(() => evaluation.value?.stages[activeStage.value].points ?? [])

const fmt = (value: number | null | undefined, digits = 3) => (value === null || value === undefined ? '—' : value.toFixed(digits))
const signed = (value: number | null | undefined) => (value === null || value === undefined ? '—' : `${value > 0 ? '+' : ''}${value.toFixed(3)}`)
const okColor = (ok: boolean | null) => (ok === null ? undefined : ok ? 'success' : 'error')
const okText = (ok: boolean | null) => (ok === null ? '' : ok ? 'OK' : 'NG')
const stageLabel = (s: Stage) => `${STAGE_LABEL[s]}${evaluation.value && evaluation.value.stages[s].result !== 'empty' ? `（${RESULT_LABEL[evaluation.value.stages[s].result]}）` : ''}`
</script>

<template>
  <div class="pk-calibration">
    <v-alert v-if="!snapshot" type="warning" variant="tonal" density="compact">
      この計器には校正範囲・許容差が設定されていないため、5点校正を記録できません。装置・計器の編集で設定してください。
    </v-alert>

    <template v-else-if="evaluation">
      <div class="text-body-2 mb-2">
        校正範囲 {{ snapshot.range_lower }}〜{{ snapshot.range_upper }} {{ snapshot.range_unit }} ／
        許容差 ±{{ snapshot.tolerance_percent }}%スパン（{{ TOLERANCE_BASIS_LABEL[snapshot.tolerance_basis ?? ''] ?? '出所未設定' }}）
        <template v-if="snapshot.kind === 'transmitter'">
          ／ 出力 {{ CHARACTERISTIC_LABEL[snapshot.output_characteristic] }}（4-20mA）
          ／ DCS {{ CHARACTERISTIC_LABEL[snapshot.dcs_characteristic] }}
          <template v-if="snapshot.dcs_range_upper !== null">（{{ snapshot.dcs_range_lower ?? snapshot.range_lower }}〜{{ snapshot.dcs_range_upper }} {{ dcsUnit(snapshot) }}）</template>
        </template>
        <template v-else>／ 調節弁のポジショナ（指令の開度に対する実開度）</template>
      </div>

      <div class="d-flex align-center flex-wrap ga-3 mb-2">
        <v-btn-toggle v-model="stage" mandatory density="compact" variant="outlined" divided color="primary">
          <v-btn v-for="s in STAGES.filter((x) => x === 'as_found' || showAsLeft)" :key="s" :value="s" size="small">{{ stageLabel(s) }}</v-btn>
        </v-btn-toggle>
        <v-checkbox v-if="!readonly" v-model="model.adjusted" label="調整した（調整後の値も記録）" density="compact" hide-details />
        <v-chip :color="RESULT_COLOR[evaluation.result]" size="small" label data-testid="calibration-result">
          最終判定: {{ RESULT_LABEL[evaluation.result] }}
        </v-chip>
      </div>

      <v-table density="compact" class="pk-calibration__table">
        <thead>
          <tr>
            <th>点</th>
            <th>方向</th>
            <th class="text-right">入力（{{ snapshot.range_unit }}）</th>
            <th class="text-right">期待出力（{{ outputUnit(snapshot) }}）</th>
            <th>出力（{{ outputUnit(snapshot) }}）</th>
            <th class="text-right">誤差（%）</th>
            <th class="text-right">期待DCS（{{ dcsUnit(snapshot) }}）</th>
            <th>DCS（{{ dcsUnit(snapshot) }}）</th>
            <th class="text-right">誤差（%）</th>
            <th>判定</th>
            <th>ヒステリシス</th>
          </tr>
        </thead>
        <tbody>
          <template v-for="(row, i) in rows" :key="row.percent">
            <tr v-for="(dir, d) in DIRECTIONS" :key="dir" :class="{ 'pk-calibration__first': d === 0 }">
              <td v-if="d === 0" rowspan="2" class="font-weight-bold">{{ row.percent }}%</td>
              <td>{{ DIRECTION_LABEL[dir] }}</td>
              <td v-if="d === 0" rowspan="2" class="text-right">{{ fmt(row.expected.input, 2) }}</td>
              <td v-if="d === 0" rowspan="2" class="text-right">{{ fmt(row.expected.output) }}</td>
              <td>
                <template v-if="readonly">{{ fmt(row[dir].output) }}</template>
                <v-text-field
                  v-else
                  v-model="model.stages[activeStage].points[i]![dir].output"
                  type="number" step="any" density="compact" variant="outlined" hide-details single-line
                  :aria-label="`${STAGE_LABEL[activeStage]} ${row.percent}% ${DIRECTION_LABEL[dir]} 出力`"
                  class="pk-calibration__input"
                />
              </td>
              <td class="text-right" :class="{ 'text-error': row[dir].output_error !== null && Math.abs(row[dir].output_error!) > snapshot.tolerance_percent }">{{ signed(row[dir].output_error) }}</td>
              <td v-if="d === 0" rowspan="2" class="text-right">{{ fmt(row.expected.dcs, 2) }}</td>
              <td>
                <template v-if="readonly">{{ fmt(row[dir].dcs, 2) }}</template>
                <v-text-field
                  v-else
                  v-model="model.stages[activeStage].points[i]![dir].dcs"
                  type="number" step="any" density="compact" variant="outlined" hide-details single-line
                  :aria-label="`${STAGE_LABEL[activeStage]} ${row.percent}% ${DIRECTION_LABEL[dir]} DCS`"
                  class="pk-calibration__input"
                />
              </td>
              <td class="text-right" :class="{ 'text-error': row[dir].dcs_error !== null && Math.abs(row[dir].dcs_error!) > snapshot.tolerance_percent }">{{ signed(row[dir].dcs_error) }}</td>
              <td><v-chip v-if="row[dir].ok !== null" :color="okColor(row[dir].ok)" size="x-small" label>{{ okText(row[dir].ok) }}</v-chip></td>
              <td v-if="d === 0" rowspan="2">
                <template v-if="row.hysteresis !== null">
                  {{ fmt(row.hysteresis) }}%
                  <v-chip :color="okColor(row.hysteresis_ok)" size="x-small" label class="ml-1">{{ okText(row.hysteresis_ok) }}</v-chip>
                </template>
              </td>
            </tr>
          </template>
        </tbody>
      </v-table>
      <div class="text-caption text-medium-emphasis mt-1">
        誤差は、出力は{{ snapshot.kind === 'transmitter' ? '16mA' : '校正範囲の幅' }}に対する%、DCSはDCSの範囲の幅に対する%。上昇と下降の出力の差も、同じ許容差で判定します。
      </div>
    </template>
  </div>
</template>

<style scoped>
.pk-calibration__table :deep(th),
.pk-calibration__table :deep(td) {
  white-space: nowrap;
  padding: 0 8px !important;
  font-size: 0.85rem;
}

.pk-calibration__first :deep(td) {
  border-top: 1px solid rgba(var(--v-border-color), var(--v-border-opacity));
}

.pk-calibration__input {
  min-width: 84px;
  max-width: 100px;
}
</style>
