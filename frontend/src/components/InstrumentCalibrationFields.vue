<script setup lang="ts">
// 計器の校正の条件（5点校正の期待値と合否の元になる）と、テレメータ・取引用の区分の入力欄。
// 計器の作成・編集ダイアログで共通に使う
import { CHARACTERISTIC_LABEL, TOLERANCE_BASIS_LABEL, type CalibrationFields } from '@/utils/calibration'

const model = defineModel<CalibrationFields>({ required: true })

const characteristicOptions = Object.entries(CHARACTERISTIC_LABEL).map(([value, title]) => ({ title, value }))
const basisOptions = Object.entries(TOLERANCE_BASIS_LABEL).map(([value, title]) => ({ title, value }))
</script>

<template>
  <div>
    <div class="text-subtitle-2 mt-2 mb-1">校正の条件（5点校正）</div>
    <div class="text-caption text-medium-emphasis mb-2">
      伝送器は入力（差圧・圧力・温度など）の範囲、調節弁は開度の範囲（0〜100%）を入れます。この範囲から、5点（0/25/50/75/100%）の期待値と、許容差に対する合否を計算します。
    </div>
    <v-row dense>
      <v-col cols="4"><v-text-field v-model="model.range_lower" label="校正範囲 下限" type="number" step="any" density="compact" /></v-col>
      <v-col cols="4"><v-text-field v-model="model.range_upper" label="校正範囲 上限" type="number" step="any" density="compact" /></v-col>
      <v-col cols="4"><v-text-field v-model="model.range_unit" label="単位（kPa・℃・% など）" density="compact" /></v-col>
      <v-col cols="6"><v-text-field v-model="model.tolerance_percent" label="許容差（%スパン）" type="number" step="any" density="compact" /></v-col>
      <v-col cols="6">
        <v-select v-model="model.tolerance_basis" :items="basisOptions" item-title="title" item-value="value" label="許容差の出所" clearable density="compact" />
      </v-col>
      <v-col cols="6">
        <v-select v-model="model.output_characteristic" :items="characteristicOptions" item-title="title" item-value="value" label="伝送器の出力" density="compact" />
      </v-col>
      <v-col cols="6">
        <v-select v-model="model.dcs_characteristic" :items="characteristicOptions" item-title="title" item-value="value" label="DCSの換算（差圧流量は平方根）" density="compact" />
      </v-col>
      <v-col cols="4"><v-text-field v-model="model.dcs_range_lower" label="DCS範囲 下限" type="number" step="any" density="compact" hint="平方根のときは必須" /></v-col>
      <v-col cols="4"><v-text-field v-model="model.dcs_range_upper" label="DCS範囲 上限" type="number" step="any" density="compact" /></v-col>
      <v-col cols="4"><v-text-field v-model="model.dcs_range_unit" label="DCSの単位（t/h など）" density="compact" /></v-col>
    </v-row>
    <div class="d-flex flex-wrap ga-4">
      <v-switch v-model="model.telemetry" label="テレメータ計器（行政へ報告）" color="primary" density="compact" hide-details />
      <v-switch v-model="model.custody_transfer" label="取引用（トレーサビリティが必要）" color="primary" density="compact" hide-details />
    </div>
  </div>
</template>
