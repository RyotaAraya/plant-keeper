<script setup lang="ts">
// 一覧の表の直前に置く検索結果の件数（#166）。
// total: 条件に合う総件数（サーバーで絞り込む一覧は meta.total_count、画面で絞り込む一覧は絞り込んだあとの件数）。未取得は null。
// shown: いま取得して表に渡している件数。上限つきの取得で total が shown を超えるときは「うちM件を表示」を添える
//   （サーバーのページ送りで取得する一覧や、上限の案内を別に出している一覧は partial を false にする）。
// 読み込み中・取得の失敗を「0件」と見せない
const props = withDefaults(defineProps<{
  total: number | null
  shown: number
  loading?: boolean
  error?: boolean
  partial?: boolean
}>(), { loading: false, error: false, partial: true })
</script>

<template>
  <p class="pk-list-count" :class="{ 'pk-list-count--error': props.error }" role="status" data-testid="list-count">
    <template v-if="props.error">一覧を取得できませんでした。再読み込みしてください。</template>
    <template v-else-if="props.total === null">{{ props.loading ? '読み込み中…' : '' }}</template>
    <template v-else>
      検索結果 <strong>{{ props.total }}</strong>件<template v-if="props.partial && props.total > props.shown">（うち{{ props.shown }}件を表示）</template>
      <!-- 件数に添える補足（インターロックの「バイパス中 N件」など） -->
      <slot />
    </template>
  </p>
</template>
