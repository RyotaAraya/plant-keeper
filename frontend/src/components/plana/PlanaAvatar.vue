<script setup lang="ts">
// AIアシスタント「プラナ」のキャラクター。画像は1枚だけで、大きさと切り取りはここで使い分ける。
//  face: 顔まわりを角丸の四角に切り出した小さなアイコン（ボタン・提案の見出し・ヘッダー）
//  full: 上半身をそのまま出す（トップの帯・専用ページ）。幅を決めるのは呼び出し側の CSS
// 隣に「プラナ」の文字があるときは飾りなので alt は空のまま（読み上げない）
import planaImage from '@/assets/plana/plana.webp'

withDefaults(
  defineProps<{
    variant?: 'face' | 'full'
    size?: number
    alt?: string
  }>(),
  { variant: 'face', size: 24, alt: '' },
)
</script>

<template>
  <span v-if="variant === 'face'" class="pk-plana-face" :style="{ width: `${size}px`, height: `${size}px` }">
    <img :src="planaImage" :alt="alt" draggable="false" />
  </span>
  <img v-else :src="planaImage" :alt="alt" class="pk-plana-full" draggable="false" />
</template>

<style scoped>
.pk-plana-face {
  position: relative;
  flex: none;
  display: inline-block;
  overflow: hidden;
  border-radius: 24%;
  background: linear-gradient(180deg, #d8ecfb, var(--pk-plana-sky));
  vertical-align: middle;
}

/* 帽子から顎までが収まる正方形（元画像の 225,20 から 700px 四方）を切り出す */
.pk-plana-face img {
  position: absolute;
  top: -3%;
  left: -32%;
  width: 179%;
  max-width: none;
  height: auto;
  user-select: none;
}

.pk-plana-full {
  display: block;
  max-width: 100%;
  height: auto;
  user-select: none;
}
</style>
