<script setup lang="ts">
// プラナへの相談欄。今はチャットではなく、入力した文を持って専用ページ（/plana）へ移るだけ。
// 専用ページは、いま使えるプラナの機能（下書き・類似トラブル）へ案内する。
// 自由な質問への回答を足すときは、送信先のページ側を変える（この欄は変えなくてよい）
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'

const props = withDefaults(
  defineProps<{
    // scene: 青い帯の上（トップ）/ plain: 業務画面の白地
    tone?: 'scene' | 'plain'
    initial?: string
  }>(),
  { tone: 'scene', initial: '' },
)

const MAX_LENGTH = 200

const router = useRouter()
const text = ref(props.initial)
watch(() => props.initial, (value) => (text.value = value))

function submit() {
  const q = text.value.trim()
  router.push({ path: '/plana', query: q ? { q } : {} })
}
</script>

<template>
  <form class="pk-consult" :class="`pk-consult--${tone}`" role="search" @submit.prevent="submit">
    <label class="pk-consult__label" for="plana-consult">
      <v-icon size="18" aria-hidden="true">mdi-creation</v-icon>
      プラナに相談する
    </label>
    <input
      id="plana-consult"
      v-model="text"
      class="pk-consult__input"
      type="text"
      :maxlength="MAX_LENGTH"
      placeholder="例）PT-100の過去のトラブルや対応履歴を教えてください"
      autocomplete="off"
      data-testid="plana-consult-input"
    />
    <button type="submit" class="pk-consult__send" aria-label="相談する" data-testid="plana-consult-send">
      <v-icon size="22" aria-hidden="true">mdi-arrow-right</v-icon>
    </button>
  </form>
</template>

<style scoped>
.pk-consult {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.4rem 0.4rem 0.4rem 1rem;
  background: #fff;
  border: 1px solid var(--pk-line);
  border-radius: 8px;
}

.pk-consult--scene {
  border-color: transparent;
  box-shadow: 0 14px 34px -14px rgba(6, 22, 60, 0.7);
}

.pk-consult:focus-within {
  outline: 2px solid var(--pk-amber);
  outline-offset: 2px;
}

.pk-consult__label {
  flex: none;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding-right: 0.9rem;
  border-right: 1px solid var(--pk-line);
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--pk-plana-navy);
  white-space: nowrap;
}

.pk-consult__label .v-icon {
  color: var(--pk-plana-blue);
}

.pk-consult__input {
  flex: 1 1 auto;
  min-width: 0;
  padding: 0.65rem 0;
  font: inherit;
  font-size: 0.9rem;
  color: var(--pk-ink);
  background: transparent;
  border: none;
  outline: none;
  text-overflow: ellipsis;
}

.pk-consult__input::placeholder {
  color: #7b868b;
}

.pk-consult__send {
  flex: none;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.75rem;
  height: 2.75rem;
  color: #fff;
  background: var(--pk-plana-blue);
  border: none;
  border-radius: 6px;
  cursor: pointer;
  transition: background-color 0.15s;
}

.pk-consult__send:hover {
  background: var(--pk-plana-navy);
}

.pk-consult__send:focus-visible {
  outline: 2px solid var(--pk-amber);
  outline-offset: 2px;
}

/* 幅が狭いときは、ラベルを上の行に出して、入力欄の幅を確保する */
@media (max-width: 600px) {
  .pk-consult {
    flex-wrap: wrap;
    padding: 0.6rem 0.5rem 0.5rem 0.9rem;
    row-gap: 0.15rem;
  }

  .pk-consult__label {
    flex: 1 0 100%;
    padding-right: 0;
    border-right: none;
  }

  .pk-consult__input {
    flex: 1 1 0;
  }
}
</style>
