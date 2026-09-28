<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import api from '@/api/axios'
import { useAuthStore } from '@/stores/auth'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import { DIAGNOSTIC_STATUS, type DiagnosticStatus } from '@/constants/diagnostics'
import { formatDateTime } from '@/utils/interlock'
import type { IntegrationToken } from '@/types/models'

// 外部連携（管理者だけ）: 機器管理システム（AMS・PRM など）が、機器の自己診断（NAMUR NE 107）を送るときのトークンの発行・失効。
// トークンの値は発行した直後にだけ表示する（保存しているのはハッシュだけで、あとから見せられない）
const authStore = useAuthStore()
const endpoint = computed(() => `${api.defaults.baseURL}/integrations/device_diagnostics`)
const tokens = ref<IntegrationToken[]>([])
const sites = ref<{ id: number; name: string }[]>([])
const loading = ref(false)
const loadError = ref('')

async function fetchTokens() {
  loading.value = true
  loadError.value = ''
  try {
    const [tokenRes, siteRes] = await Promise.all([api.get('/integration_tokens'), api.get('/sites', { params: { per_page: 100, is_active: true } })])
    tokens.value = tokenRes.data.data
    sites.value = siteRes.data.data
  } catch {
    loadError.value = '連携の一覧を読み込めませんでした。再読み込みしてください。'
  } finally {
    loading.value = false
  }
}

// --- 発行 ---
const issueDialog = ref(false)
const issueForm = ref({ name: '', site_id: null as number | null })
const issueErrors = ref<string[]>([])
const issuing = ref(false)
// 発行したトークン（値つき）。ダイアログを閉じると消える
const issued = ref<IntegrationToken | null>(null)
const copied = ref(false)

function openIssue() {
  // 既定は自分の所属拠点（その拠点の機器管理システムを登録することが多いため）
  const own = sites.value.find((site) => site.id === authStore.user?.site_id)
  issueForm.value = { name: '', site_id: own?.id ?? sites.value[0]?.id ?? null }
  issueErrors.value = []
  issued.value = null
  testResult.value = null
  testError.value = ''
  copied.value = false
  issueDialog.value = true
}

async function issue() {
  issuing.value = true
  issueErrors.value = []
  try {
    const res = await api.post('/integration_tokens', { integration_token: issueForm.value })
    issued.value = res.data.data
    await fetchTokens()
  } catch (e: any) {
    issueErrors.value = e.response?.data?.errors ?? ['発行できませんでした']
  } finally {
    issuing.value = false
  }
}

async function copyToken() {
  if (!issued.value?.token) return
  try {
    await window.navigator.clipboard.writeText(issued.value.token)
    copied.value = true
  } catch {
    copied.value = false
  }
}

// --- 試しに送る（発行したトークンで、本物の受け口に送る。機器管理システムの代わり） ---
const testForm = ref({ tag_number: '', status: 'failure' as DiagnosticStatus, code: '', message: '' })
// trouble_id は、故障（F）でトラブルを自動で登録したとき
const testResult = ref<{ tag_number: string; result: string; errors: string[]; trouble_id?: number | null } | null>(null)
const testError = ref('')
const testing = ref(false)
const statusOptions = (Object.keys(DIAGNOSTIC_STATUS) as DiagnosticStatus[]).map((value) => ({
  title: `${DIAGNOSTIC_STATUS[value].letter} ${DIAGNOSTIC_STATUS[value].label}`, value,
}))
const RESULT_LABEL: Record<string, string> = {
  changed: '受け付けました（計器の状態が変わりました）',
  unchanged: '受け付けました（いまと同じ状態のため、記録は増やしていません）',
  stale: 'いまの状態より古い日時のため、反映していません',
  error: '受け付けられませんでした',
}

async function sendTest() {
  if (!issued.value?.token) return
  testing.value = true
  testResult.value = null
  testError.value = ''
  const { tag_number, status, code, message } = testForm.value
  try {
    // 共通の api（ユーザのトークンを付け、401でログイン画面へ戻す）は使わない。連携の認証はユーザのログインと別のため
    const res = await window.fetch(endpoint.value, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Integration-Token': issued.value.token },
      body: JSON.stringify({ diagnostics: [{ tag_number, status, code: code || undefined, message: message || undefined, occurred_at: new Date().toISOString() }] }),
    })
    const body = await res.json()
    if (!res.ok) {
      testError.value = (body.errors ?? ['送れませんでした']).join('、')
      return
    }
    testResult.value = body.data.results[0]
    await fetchTokens() // 最後に使った日時を更新する
  } catch {
    testError.value = '送れませんでした（通信の失敗）'
  } finally {
    testing.value = false
  }
}

// --- 失効 ---
const revoking = ref<IntegrationToken | null>(null)
const revokeError = ref('')

async function revoke() {
  if (!revoking.value) return
  revokeError.value = ''
  try {
    await api.post(`/integration_tokens/${revoking.value.id}/revoke`)
    revoking.value = null
    await fetchTokens()
  } catch (e: any) {
    revokeError.value = (e.response?.data?.errors ?? ['失効できませんでした']).join('、')
  }
}

const example = computed(() => JSON.stringify({
  diagnostics: [{ tag_number: 'PT-502', status: 'M', code: 'SENSOR_DRIFT', message: 'センサのドリフトを検出しました', occurred_at: '2026-09-26T10:00:00+09:00' }],
}, null, 2))

onMounted(fetchTokens)
</script>

<template>
  <MainLayout>
    <PageHeader title="外部連携" description="機器管理システム（AMS Device Manager・PRM など）から、機器の自己診断（NAMUR NE 107）を受け取るためのトークンを発行・失効します。">
      <v-btn color="primary" prepend-icon="mdi-key-plus" :disabled="loading || !!loadError" data-testid="integration-issue" @click="openIssue">トークンを発行</v-btn>
    </PageHeader>

    <v-alert v-if="loadError" type="error" variant="tonal" class="mb-4" role="alert">
      {{ loadError }} <v-btn size="small" variant="text" @click="fetchTokens">再読み込み</v-btn>
    </v-alert>

    <v-card class="mb-4">
      <v-card-title class="text-subtitle-1">受け口</v-card-title>
      <v-card-text class="text-body-2">
        <p>
          <code>POST {{ endpoint }}</code>（ヘッダー <code>X-Integration-Token</code> に発行したトークン）。
          計器は、トークンの拠点のタグ番号で探します。状態は NE 107 の記号（N 正常 / F 故障 / C 機能点検中 / S 仕様外 / M 保守要求）で送ります。
          いまと同じ状態を受け取り続けても記録は増えず、いまより古い日時の診断は反映せず、未来の日時（5分を超えるもの）は誤りになります。一度に500件まで送れます。
        </p>
        <pre class="pk-integration__example">{{ example }}</pre>
      </v-card-text>
    </v-card>

    <v-card>
      <v-card-title class="text-subtitle-1">発行したトークン</v-card-title>
      <v-table density="comfortable" data-testid="integration-tokens">
        <thead>
          <tr class="text-no-wrap"><th>名前</th><th>拠点</th><th>トークン</th><th>発行</th><th>最後に使った日時</th><th>状態</th><th /></tr>
        </thead>
        <tbody>
          <tr v-for="token in tokens" :key="token.id" :data-testid="`integration-token-${token.id}`">
            <td>{{ token.name }}</td>
            <td class="text-no-wrap">{{ token.site.name }}</td>
            <td class="text-no-wrap"><code>…{{ token.token_hint }}</code></td>
            <td class="text-no-wrap">{{ formatDateTime(token.created_at) }}（{{ token.created_by.name }}）</td>
            <td class="text-no-wrap">{{ token.last_used_at ? formatDateTime(token.last_used_at) : '未使用' }}</td>
            <td class="text-no-wrap">
              <v-chip v-if="token.revoked_at" size="small" label color="grey" variant="tonal">失効（{{ formatDateTime(token.revoked_at) }}）</v-chip>
              <v-chip v-else size="small" label color="success" variant="tonal">有効</v-chip>
            </td>
            <td class="text-right">
              <v-btn v-if="!token.revoked_at" size="small" variant="outlined" color="error" @click="revoking = token; revokeError = ''">失効</v-btn>
            </td>
          </tr>
          <tr v-if="!tokens.length && !loading"><td colspan="7" class="text-medium-emphasis">発行したトークンはありません。</td></tr>
        </tbody>
      </v-table>
    </v-card>

    <!-- 発行 → トークンの表示と、試しに送る -->
    <v-dialog v-model="issueDialog" max-width="640" persistent scrollable>
      <v-card data-testid="integration-issue-dialog">
        <v-card-title>{{ issued ? 'トークンを発行しました' : 'トークンを発行' }}</v-card-title>
        <v-card-text>
          <template v-if="!issued">
            <v-alert v-if="issueErrors.length" type="error" variant="tonal" class="mb-3">{{ issueErrors.join('、') }}</v-alert>
            <v-text-field v-model="issueForm.name" label="名前（どのシステムのものか）" placeholder="AMS Device Manager（川崎）" class="mb-2" data-testid="integration-name" />
            <v-select v-model="issueForm.site_id" :items="sites" item-title="name" item-value="id" label="拠点（この拠点の計器だけに送れる）" data-testid="integration-site" />
          </template>
          <template v-else>
            <v-alert type="warning" variant="tonal" class="mb-3">
              このトークンは、いま一度だけ表示します。閉じると二度と表示できないので、機器管理システムに設定してください。
            </v-alert>
            <v-text-field :model-value="issued.token" label="トークン" readonly data-testid="integration-token-value" append-inner-icon="mdi-content-copy" @click:append-inner="copyToken" />
            <p v-if="copied" class="text-caption text-success mb-2">コピーしました</p>

            <v-divider class="my-4" />
            <h3 class="text-subtitle-2 mb-1">試しに送る</h3>
            <p class="text-body-2 text-medium-emphasis mb-3">
              機器管理システムの代わりに、このトークンで受け口へ診断を1件送ります（{{ issued.site.name }}の計器）。送ると、計器の診断の状態と記録が変わります。
            </p>
            <div class="d-flex flex-wrap ga-2">
              <v-text-field v-model="testForm.tag_number" label="タグ番号" density="compact" style="max-width: 160px" data-testid="integration-test-tag" />
              <v-select v-model="testForm.status" :items="statusOptions" label="状態" density="compact" style="max-width: 200px" data-testid="integration-test-status" />
              <v-text-field v-model="testForm.code" label="コード（任意）" density="compact" style="max-width: 180px" />
            </div>
            <v-text-field v-model="testForm.message" label="内容（任意）" density="compact" />
            <v-btn variant="outlined" :loading="testing" :disabled="!testForm.tag_number" data-testid="integration-test-send" @click="sendTest">送る</v-btn>
            <v-alert v-if="testError" type="error" variant="tonal" class="mt-3" data-testid="integration-test-result">{{ testError }}</v-alert>
            <v-alert v-else-if="testResult" :type="testResult.result === 'error' ? 'error' : 'success'" variant="tonal" class="mt-3" data-testid="integration-test-result">
              {{ testResult.tag_number }}: {{ RESULT_LABEL[testResult.result] ?? testResult.result }}
              <template v-if="testResult.errors.length">（{{ testResult.errors.join('、') }}）</template>
              <template v-if="testResult.trouble_id">。故障のため<router-link :to="`/troubles/${testResult.trouble_id}`">トラブルを登録しました</router-link></template>
            </v-alert>
          </template>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <template v-if="!issued">
            <v-btn @click="issueDialog = false">キャンセル</v-btn>
            <v-btn color="primary" :loading="issuing" data-testid="integration-issue-submit" @click="issue">発行</v-btn>
          </template>
          <v-btn v-else color="primary" data-testid="integration-issue-close" @click="issueDialog = false">閉じる</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 失効の確認 -->
    <v-dialog :model-value="!!revoking" max-width="480" @update:model-value="(v: boolean) => { if (!v) revoking = null }">
      <v-card v-if="revoking" data-testid="integration-revoke-dialog">
        <v-card-title>トークンを失効しますか</v-card-title>
        <v-card-text>
          「{{ revoking.name }}」（…{{ revoking.token_hint }}）を失効します。失効すると、このトークンでは診断を送れなくなり、元に戻せません（新しく発行し直してください）。
          <v-alert v-if="revokeError" type="error" variant="tonal" class="mt-3">{{ revokeError }}</v-alert>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="revoking = null">やめる</v-btn>
          <v-btn color="error" data-testid="integration-revoke-submit" @click="revoke">失効する</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>

<style scoped>
.pk-integration__example { margin-top: 8px; padding: 12px; overflow-x: auto; border-radius: 8px; background: var(--pk-soft-blue); font-size: 0.8125rem; }
code { overflow-wrap: anywhere; }
</style>
