<script setup lang="ts">
// プラナ（AIアシスタント）の入口。プラナは各画面（点検の入力・トラブル詳細）の中で呼び出すもので、
// このページは「何ができるか」と、使う場所への案内を示す。チャットはまだなく、
// 相談欄（トップ・ここ）に入れた文は、回答ではなくこのページの案内につながる。
// AIの処理は既存のまま（このページは AI を呼ばず、状況の取得 GET /ai/status だけ）
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
import PlanaConsultBar from '@/components/plana/PlanaConsultBar.vue'
import PlanaNote from '@/components/plana/PlanaNote.vue'
import { planaCapabilities } from '@/constants/planaCapabilities'
import type { AiStatus } from '@/types/models'

const route = useRoute()
const question = computed(() => (typeof route.query.q === 'string' ? route.query.q.trim() : ''))

// 状況が取れなくても、案内の表示には影響しない（回数の表示を出さないだけ）
const status = ref<AiStatus | null>(null)
onMounted(async () => {
  try {
    status.value = (await api.get('/ai/status')).data.data
  } catch {
    status.value = null
  }
})
</script>

<template>
  <MainLayout>
    <div class="pk-plana-page">
      <header class="pk-plana-head">
        <div class="pk-plana-head__figure">
          <PlanaAvatar variant="full" alt="プラナ。ヘルメットをかぶり、タブレットを持った、PlantKeeperのAIアシスタントのキャラクター" />
        </div>
        <div class="pk-plana-head__body">
          <h1 class="pk-plana-head__title">プラナ <span class="pk-plana-head__badge">AI</span></h1>
          <p class="pk-plana-head__lead">
            PlantKeeperに蓄積された設備・点検・トラブルなどの記録をもとに、情報の整理や過去事例の検索、報告の下書き作成などをサポートするAIアシスタントです。提案までがプラナの役割で、記録する内容と次の判断は、いつも人が決めます。
          </p>
          <p v-if="status?.enabled" class="pk-plana-head__meta" data-testid="plana-remaining">
            今日の残り {{ status.remaining_today }} / {{ status.daily_limit }} 回（下書きと類似トラブルの合計です）
          </p>
        </div>
      </header>

      <v-alert v-if="status && !status.enabled" type="info" variant="tonal" density="compact" class="mb-4" data-testid="plana-disabled">
        この環境では、プラナのAIは有効になっていません。各画面のプラナのボタンは出ませんが、記録の入力はそのまま使えます。
      </v-alert>

      <PlanaConsultBar tone="plain" :initial="question" class="mb-4" />

      <v-card v-if="question" variant="flat" class="pa-4 mb-6" data-testid="plana-question">
        <div class="text-caption text-medium-emphasis mb-1">いただいた相談</div>
        <div class="text-body-1 mb-3 pk-plana-question">{{ question }}</div>
        <PlanaNote>
          文章での質問への回答は、まだ用意できていません。いまは、下の場面でプラナを呼び出せます。
        </PlanaNote>
      </v-card>

      <h2 class="text-subtitle-1 font-weight-bold mb-3 mt-6">プラナでできること</h2>
      <v-row>
        <v-col v-for="cap in planaCapabilities" :key="cap.key" cols="12" md="4">
          <v-card class="pa-4 h-100 d-flex flex-column" data-testid="plana-capability">
            <div class="d-flex align-center ga-2 mb-2">
              <v-icon color="primary" size="20" aria-hidden="true">{{ cap.icon }}</v-icon>
              <h3 class="text-subtitle-2 font-weight-bold">{{ cap.title }}</h3>
            </div>
            <p class="text-body-2 text-medium-emphasis mb-4 flex-grow-1">{{ cap.summary }}</p>
            <div>
              <v-btn size="small" variant="tonal" color="primary" :to="cap.to">{{ cap.linkLabel }}</v-btn>
            </div>
          </v-card>
        </v-col>
      </v-row>
    </div>
  </MainLayout>
</template>

<style scoped>
.pk-plana-page {
  max-width: 1040px;
}

.pk-plana-head {
  display: flex;
  align-items: stretch;
  gap: 1.5rem;
  margin-bottom: 1.25rem;
}

/* キャラクターは、銘板のような四角い台に載せる（業務画面の角ばった部品と揃える） */
.pk-plana-head__figure {
  flex: none;
  width: 132px;
  height: 132px;
  overflow: hidden;
  background: linear-gradient(180deg, var(--pk-plana-navy) 0%, var(--pk-plana-blue) 55%, var(--pk-plana-sky) 100%);
  border: 1px solid var(--pk-line);
}

.pk-plana-head__body {
  align-self: center;
  min-width: 0;
}

.pk-plana-head__title {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin: 0 0 0.35rem;
  font-family: var(--pk-font-display);
  font-size: 1.75rem;
  font-weight: 900;
  line-height: 1.2;
  color: var(--pk-plana-navy);
}

.pk-plana-head__badge {
  padding: 0.05rem 0.55rem;
  font-size: 0.95rem;
  font-weight: 900;
  color: var(--pk-plana-navy);
  background: var(--pk-plana-glow);
  border-radius: 999px;
}

.pk-plana-head__lead {
  max-width: 44em;
  margin: 0;
  font-size: 0.875rem;
  line-height: 1.7;
  color: rgb(var(--v-theme-secondary));
  text-wrap: pretty;
  word-break: auto-phrase;
}

.pk-plana-head__meta {
  margin: 0.4rem 0 0;
  font-size: 0.75rem;
  color: rgb(var(--v-theme-secondary));
}

.pk-plana-question {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}

@media (max-width: 600px) {
  .pk-plana-head {
    flex-direction: column;
    gap: 1rem;
  }

  .pk-plana-head__figure {
    width: 104px;
    height: 104px;
  }
}
</style>
