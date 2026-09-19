<script setup lang="ts">
import { computed } from 'vue'
import { MATRIX_GROUPS, MATRIX_ROLES, isAllowed } from '@/constants/permissionMatrix'

// 権限ごとに使える機能の一覧。プラントの安全・制御ドキュメントにある「因果マトリクス」の形式
// （行=機能、列=権限、交点に●）で、保全の現場の人が見慣れた読み方ができるようにしている
const props = withDefaults(
  defineProps<{
    variant?: 'light' | 'dark'
    // 行間を詰める（幅・高さに余裕のない場所用）
    dense?: boolean
    // 強調する列（会社種別:ロール）。ログイン画面で、選んだデモアカウントの権限を示す
    highlight?: string | null
  }>(),
  { variant: 'light', dense: false, highlight: null }
)

// 行ラベルは「・」の位置でだけ折り返す（「監/査ログ」のように語の途中で折れないように、
// 「・」の後ろに折り返せる位置（ゼロ幅スペース）を入れ、CSS側で語中の折り返しを禁止する）
const breakable = (label: string) => label.replace(/・/g, '・\u200b')

// 列見出しの上段（自社 / 協力会社）。同じ会社種別の列をまとめる
const columnGroups = computed(() => {
  const groups: { label: string; span: number }[] = []
  for (const role of MATRIX_ROLES) {
    const last = groups[groups.length - 1]
    if (last && last.label === role.groupLabel) last.span += 1
    else groups.push({ label: role.groupLabel, span: 1 })
  }
  return groups
})
</script>

<template>
  <div class="pk-matrix" :class="[`pk-matrix--${props.variant}`, { 'pk-matrix--dense': props.dense }]">
    <div class="pk-matrix__scroll">
      <table class="pk-matrix__table">
        <caption class="pk-matrix__sr">権限ごとに使える機能の一覧</caption>
        <thead>
          <tr>
            <td class="pk-matrix__stub" />
            <th
              v-for="group in columnGroups"
              :key="group.label"
              scope="colgroup"
              :colspan="group.span"
              class="pk-matrix__company"
            >
              {{ group.label }}
            </th>
          </tr>
          <tr>
            <td class="pk-matrix__stub" />
            <th
              v-for="role in MATRIX_ROLES"
              :key="role.key"
              scope="col"
              class="pk-matrix__role"
              :class="{ 'is-active': props.highlight === role.key }"
            >
              <span v-for="line in role.labelLines" :key="line" class="pk-matrix__role-line">{{ line }}</span>
            </th>
          </tr>
        </thead>

        <tbody v-for="group in MATRIX_GROUPS" :key="group.title">
          <tr>
            <th scope="rowgroup" :colspan="MATRIX_ROLES.length + 1" class="pk-matrix__group">{{ group.title }}</th>
          </tr>
          <tr v-for="row in group.rows" :key="row.label">
            <th scope="row" class="pk-matrix__label">{{ breakable(row.label) }}</th>
            <td
              v-for="role in MATRIX_ROLES"
              :key="role.key"
              class="pk-matrix__cell"
              :class="{ 'is-active': props.highlight === role.key }"
            >
              <span v-if="isAllowed(row, role)" class="pk-matrix__on"><span class="pk-matrix__sr">できる</span></span>
              <span v-else class="pk-matrix__off"><span class="pk-matrix__sr">できない</span></span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p class="pk-matrix__legend" aria-hidden="true">
      <span class="pk-matrix__on pk-matrix__on--legend" />できる
      <span class="pk-matrix__off pk-matrix__off--legend" />できない
    </p>
  </div>
</template>

<style scoped>
.pk-matrix {
  /* 配色は variant で切り替える（既存の鋼板の寒色とアンバー） */
  --m-text: var(--pk-ink);
  --m-muted: #5b6b70;
  --m-rule: var(--pk-line);
  --m-group-bg: var(--pk-mist);
  --m-group-text: var(--pk-steel);
  --m-on: var(--pk-steel);
  --m-off: #b3bcbf;
  --m-active-bg: rgba(46, 91, 122, 0.09);
  --m-active-line: var(--pk-amber);
  --m-surface: #fff;

  color: var(--m-text);
}

.pk-matrix--dark {
  --m-text: #e8ecee;
  --m-muted: rgba(232, 236, 238, 0.6);
  --m-rule: rgba(255, 255, 255, 0.16);
  --m-group-bg: rgba(255, 255, 255, 0.06);
  --m-group-text: #e7b778;
  --m-on: #e7b778;
  --m-off: rgba(255, 255, 255, 0.3);
  --m-active-bg: rgba(231, 183, 120, 0.16);
  --m-active-line: #e7b778;
  --m-surface: transparent;
}

.pk-matrix__scroll {
  overflow-x: auto;
  background: var(--m-surface);
  border: 1px solid var(--m-rule);
}

.pk-matrix__table {
  width: 100%;
  min-width: 540px;
  border-collapse: collapse;
  table-layout: fixed;
  font-size: 0.8125rem;
  line-height: 1.5;
}

.pk-matrix__stub {
  width: 36%;
}

.pk-matrix__company {
  padding: 0.55rem 0.5rem 0.4rem;
  font-family: var(--pk-font-display);
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--m-muted);
  text-align: center;
  /* 自社 / 協力会社 の区切りを、列の並びと同じ幅の下線で示す */
  border-bottom: 1px solid var(--m-rule);
  border-left: 1px solid var(--m-rule);
}

.pk-matrix__company:nth-child(2) {
  border-left: 0;
}

.pk-matrix__role {
  padding: 0.5rem 0.25rem 0.6rem;
  font-family: var(--pk-font-display);
  font-size: 0.75rem;
  font-weight: 700;
  text-align: center;
  border-bottom: 2px solid transparent;
  transition: background-color 0.15s ease, border-color 0.15s ease;
}

.pk-matrix__role-line {
  display: block;
  white-space: nowrap;
}

.pk-matrix__group {
  padding: 0.4rem 0.75rem;
  background: var(--m-group-bg);
  color: var(--m-group-text);
  font-family: var(--pk-font-display);
  font-size: 0.75rem;
  font-weight: 700;
  text-align: left;
  border-top: 1px solid var(--m-rule);
  border-bottom: 1px solid var(--m-rule);
}

.pk-matrix__label {
  padding: 0.5rem 0.75rem;
  font-weight: 400;
  text-align: left;
  text-wrap: balance;
  word-break: keep-all;
  overflow-wrap: anywhere;
  border-bottom: 1px solid var(--m-rule);
}

.pk-matrix__cell {
  height: 2.4rem;
  text-align: center;
  vertical-align: middle;
  border-bottom: 1px solid var(--m-rule);
  transition: background-color 0.15s ease;
}

/* 選んだ権限の列だけを強調する（見出しは下線、セルは薄い帯） */
.pk-matrix__role.is-active {
  background: var(--m-active-bg);
  border-bottom-color: var(--m-active-line);
}

.pk-matrix__cell.is-active {
  background: var(--m-active-bg);
}

/* できる=塗りつぶしの円、できない=細い横線。色だけに頼らず形でも区別する */
.pk-matrix__on,
.pk-matrix__off {
  display: inline-block;
  vertical-align: middle;
}

.pk-matrix__on {
  width: 0.7rem;
  height: 0.7rem;
  border-radius: 50%;
  background: var(--m-on);
}

.pk-matrix__off {
  width: 0.55rem;
  height: 2px;
  background: var(--m-off);
}

.pk-matrix__legend {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin: 0.6rem 0 0;
  font-size: 0.75rem;
  color: var(--m-muted);
}

.pk-matrix__legend .pk-matrix__off {
  margin-left: 0.75rem;
}

.pk-matrix__sr {
  position: absolute;
  width: 1px;
  height: 1px;
  margin: -1px;
  padding: 0;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.pk-matrix--dense .pk-matrix__table {
  font-size: 0.75rem;
}

.pk-matrix--dense .pk-matrix__stub {
  width: 40%;
}

.pk-matrix--dense .pk-matrix__label {
  padding: 0.3rem 0.6rem;
  line-height: 1.4;
}

.pk-matrix--dense .pk-matrix__cell {
  height: 2rem;
}

.pk-matrix--dense .pk-matrix__group {
  padding: 0.25rem 0.6rem;
}

@media (prefers-reduced-motion: reduce) {
  .pk-matrix__role,
  .pk-matrix__cell {
    transition: none;
  }
}
</style>
