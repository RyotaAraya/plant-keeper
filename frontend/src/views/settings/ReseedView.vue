<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'

// デモデータの再投入。設定画面には出さず、このURL（/settings/reseed）からだけ開く（危険な操作を、目につく場所に置かない）。
// 画面を隠すだけでは防御にならないため、サーバ側は ALLOW_DEMO_RESEED=true のサーバでだけ実行を許す（本番は既定で無効）
// 数分かかるため、バックグラウンドで始めて、状態を確認し続ける
type ReseedStatus = 'idle' | 'running' | 'succeeded' | 'failed'
const RESEED_POLL_MS = 3000
const reseedDialog = ref(false)
const reseedStatus = ref<ReseedStatus>('idle')
const reseedError = ref('')
const reseedStarting = ref(false)
const reseedEnabled = ref<boolean | null>(null) // null=不明（確認中・取得できなかった）
let reseedTimer: number | undefined

function stopReseedPolling() {
  if (reseedTimer) window.clearInterval(reseedTimer)
  reseedTimer = undefined
}

function startReseedPolling() {
  stopReseedPolling()
  reseedTimer = window.setInterval(pollReseed, RESEED_POLL_MS)
}

// 再投入中はユーザ（ログイン情報）も空になるため、状態の確認はログイン不要のAPI。サーバが忙しくて失敗しても、確認を続ける
async function fetchReseedStatus(): Promise<{ status: ReseedStatus; error?: string; enabled?: boolean } | null> {
  try {
    return (await api.get('/admin/reseed')).data.data
  } catch {
    return null
  }
}

async function pollReseed() {
  const state = await fetchReseedStatus()
  if (!state || state.status === 'running') return
  stopReseedPolling()
  if (state.status === 'idle') {
    // 実行中にサーバが再起動すると、状態が失われて未実行に戻る
    reseedStatus.value = 'failed'
    reseedError.value = '再投入の状態が分からなくなりました（サーバが再起動した可能性があります）。データを確認し、必要ならもう一度実行してください'
  } else {
    reseedStatus.value = state.status
    reseedError.value = state.error ?? ''
  }
}

async function openReseedDialog() {
  reseedDialog.value = true
  if (reseedStatus.value === 'running') return
  reseedStatus.value = 'idle'
  reseedError.value = ''
}

async function reseed() {
  reseedStarting.value = true
  reseedError.value = ''
  try {
    await api.post('/admin/reseed')
    reseedStatus.value = 'running'
    startReseedPolling()
  } catch (e: any) {
    if (e.response?.status === 409) {
      // すでに実行中（別の画面から始めた場合など）
      reseedStatus.value = 'running'
      startReseedPolling()
    } else {
      reseedError.value = e.response?.data?.errors?.join('、') || '再投入を始められませんでした'
    }
  } finally {
    reseedStarting.value = false
  }
}

// 画面を開いたとき、このサーバで有効か（無効なら案内だけを出す）と、実行中なら続きを確認する
async function loadReseedStatus() {
  const state = await fetchReseedStatus()
  reseedEnabled.value = state?.enabled ?? null
  if (state?.status === 'running') {
    reseedStatus.value = 'running'
    startReseedPolling()
  }
}

onBeforeUnmount(stopReseedPolling)
onMounted(loadReseedStatus)
</script>

<template>
  <MainLayout>
    <PageHeader title="デモデータの再投入" description="デモ環境の全データを削除して、初期のデモデータに入れ直します。" />

    <v-alert v-if="reseedEnabled === false" type="info" variant="tonal" data-testid="reseed-disabled">
      このサーバでは、デモデータの再投入は無効です。サーバの環境変数 <code>ALLOW_DEMO_RESEED=true</code> が設定されたサーバ（stg など）でだけ使えます。本番は既定で無効です。
    </v-alert>

    <v-card v-else variant="outlined">
      <v-card-title class="text-subtitle-1">
        <v-icon class="mr-2" color="warning" aria-hidden="true">mdi-database-refresh</v-icon>
        全データを削除して、初期デモデータを再投入する
      </v-card-title>
      <v-card-text>
        現在の全データ（拠点・設備・点検・トラブル等）を削除し、初期デモデータに置き換えます。デモ環境用の機能です。
        <v-alert v-if="reseedStatus === 'running'" type="info" density="compact" class="mt-3" data-testid="reseed-running">
          再投入を実行中です（数分かかります）。終わるまで、データが揃っていないことがあります。
        </v-alert>
        <v-alert v-else-if="reseedStatus === 'succeeded'" type="success" density="compact" class="mt-3">デモデータを再投入しました。</v-alert>
        <v-alert v-else-if="reseedStatus === 'failed'" type="error" density="compact" class="mt-3">{{ reseedError || '再投入に失敗しました' }}</v-alert>
      </v-card-text>
      <v-card-actions>
        <v-btn color="warning" variant="tonal" :disabled="reseedStatus === 'running'" @click="openReseedDialog">再投入する</v-btn>
      </v-card-actions>
    </v-card>

    <v-dialog v-model="reseedDialog" max-width="440">
      <v-card>
        <v-card-title>
          <template v-if="reseedStatus === 'idle'">デモデータを再投入しますか？</template>
          <template v-else-if="reseedStatus === 'running'">再投入しています</template>
          <template v-else-if="reseedStatus === 'succeeded'">再投入しました</template>
          <template v-else>再投入に失敗しました</template>
        </v-card-title>
        <v-card-text>
          <template v-if="reseedStatus === 'idle'">
            現在登録されている全データ（拠点・設備・点検・トラブル等）が削除され、初期デモデータに置き換わります。この操作は取り消せません。
            数分（stgでは約4分）かかります。
          </template>
          <template v-else-if="reseedStatus === 'running'">
            <v-progress-linear indeterminate color="warning" class="mb-3" data-testid="reseed-progress" />
            サーバで実行中です。この画面を閉じても処理は続きます（途中で止めることはできません）。もう一度実行しないでください。
          </template>
          <template v-else-if="reseedStatus === 'succeeded'">
            デモデータを再投入しました。
          </template>
          <v-alert v-if="reseedError" type="error" density="compact" class="mt-3">{{ reseedError }}</v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <template v-if="reseedStatus === 'idle'">
            <v-btn @click="reseedDialog = false">やめる</v-btn>
            <v-btn color="warning" :loading="reseedStarting" @click="reseed">実行する</v-btn>
          </template>
          <v-btn v-else color="primary" @click="reseedDialog = false">閉じる</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>
