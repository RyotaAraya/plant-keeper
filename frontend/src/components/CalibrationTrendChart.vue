<script setup lang="ts">
// 5点校正の調整前（as found）の最大誤差の推移。横軸は点検日（間隔が分かるように日付に比例）、縦軸は誤差（%スパン）。
// 許容差の線を引き、不合格の回は赤、調整した回は調整後の値を白抜きで重ねる
import { computed } from 'vue'
import type { CalibrationHistoryRow } from '@/types/models'

const props = defineProps<{ rows: CalibrationHistoryRow[] }>()

const W = 640
const H = 220
const PAD = { left: 48, right: 24, top: 16, bottom: 36 }

const tolerance = computed(() => Math.max(...props.rows.map((r) => r.tolerance_percent)))
const yMax = computed(() => {
  const maxError = Math.max(0, ...props.rows.map((r) => r.as_found.max_error ?? 0))
  return Math.max(tolerance.value * 1.4, maxError * 1.15)
})
const times = computed(() => props.rows.map((r) => new Date(r.inspected_at).getTime()))

function x(i: number) {
  const [first, last] = [Math.min(...times.value), Math.max(...times.value)]
  if (last === first) return (PAD.left + W - PAD.right) / 2
  return PAD.left + ((times.value[i]! - first) / (last - first)) * (W - PAD.left - PAD.right)
}
const y = (value: number) => PAD.top + (1 - value / yMax.value) * (H - PAD.top - PAD.bottom)

const points = computed(() =>
  props.rows.map((row, i) => ({
    x: x(i),
    y: y(row.as_found.max_error ?? 0),
    fail: row.as_found.result === 'fail',
    leftY: row.as_left?.max_error != null ? y(row.as_left.max_error) : null,
    label: new Date(row.inspected_at).toLocaleDateString('ja-JP', { year: 'numeric', month: 'numeric', timeZone: 'Asia/Tokyo' }),
    value: row.as_found.max_error,
  })),
)
const line = computed(() => points.value.map((p) => `${p.x},${p.y}`).join(' '))
const yTicks = computed(() => [0, tolerance.value / 2, tolerance.value])
// 0.125 を 0.13 に丸めない（許容差の半分がそのまま読めるように）
const formatTick = (tick: number) => String(Number(tick.toFixed(3)))
</script>

<template>
  <svg :viewBox="`0 0 ${W} ${H}`" class="pk-trend" role="img" :aria-label="`調整前の最大誤差の推移（許容差 ±${tolerance}%）`">
    <!-- 目盛り -->
    <g v-for="tick in yTicks" :key="tick">
      <line :x1="PAD.left" :x2="W - PAD.right" :y1="y(tick)" :y2="y(tick)" class="pk-trend__grid" />
      <text :x="PAD.left - 6" :y="y(tick) + 4" text-anchor="end" class="pk-trend__axis">{{ formatTick(tick) }}%</text>
    </g>
    <!-- 許容差 -->
    <line :x1="PAD.left" :x2="W - PAD.right" :y1="y(tolerance)" :y2="y(tolerance)" class="pk-trend__tolerance" />
    <text :x="PAD.left + 6" :y="y(tolerance) - 6" text-anchor="start" class="pk-trend__tolerance-label">許容差 ±{{ tolerance }}%</text>
    <!-- 調整前の推移 -->
    <polyline :points="line" class="pk-trend__line" />
    <g v-for="(p, i) in points" :key="i">
      <line v-if="p.leftY !== null" :x1="p.x" :x2="p.x" :y1="p.y" :y2="p.leftY" class="pk-trend__adjust" />
      <circle v-if="p.leftY !== null" :cx="p.x" :cy="p.leftY" r="5" class="pk-trend__left" />
      <circle :cx="p.x" :cy="p.y" r="5.5" :class="p.fail ? 'pk-trend__fail' : 'pk-trend__pass'" />
      <text :x="p.x" :y="p.y - 10" text-anchor="middle" class="pk-trend__value">{{ p.value?.toFixed(2) }}</text>
      <text :x="p.x" :y="H - 12" text-anchor="middle" class="pk-trend__axis">{{ p.label }}</text>
    </g>
  </svg>
</template>

<style scoped>
.pk-trend { width: 100%; max-width: 760px; height: auto; display: block; }
.pk-trend__grid { stroke: var(--pk-line); stroke-width: 1; }
.pk-trend__axis { font-size: 11px; fill: var(--pk-muted); }
.pk-trend__tolerance { stroke: rgb(var(--v-theme-error)); stroke-width: 1.5; stroke-dasharray: 6 4; }
.pk-trend__tolerance-label { font-size: 11px; fill: rgb(var(--v-theme-error)); }
.pk-trend__line { fill: none; stroke: var(--pk-steel); stroke-width: 2; }
.pk-trend__pass { fill: var(--pk-steel); }
.pk-trend__fail { fill: rgb(var(--v-theme-error)); }
.pk-trend__left { fill: #fff; stroke: rgb(var(--v-theme-success)); stroke-width: 2; }
.pk-trend__adjust { stroke: rgb(var(--v-theme-success)); stroke-width: 1.5; stroke-dasharray: 3 3; }
.pk-trend__value { font-size: 11px; font-weight: 600; fill: var(--pk-ink); }
</style>
