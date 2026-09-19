<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import api from '@/api/axios'

const authStore = useAuthStore()
const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')
const errorMessage = ref(route.query.expired ? 'ログインの有効期限が切れました。もう一度ログインしてください。' : '')
const loading = ref(false)

interface DemoAccount {
  id: number
  name: string
  email: string
  system_role: string
  employment_type: string
  company_name: string | null
  department_path: string | null
}

const demoAccounts = ref<DemoAccount[]>([])

const roleLabel: Record<string, string> = {
  admin: 'システム管理者',
  manager: '業務管理者',
  member: '一般',
  worker: '技能員',
}

const roleColor: Record<string, string> = {
  admin: 'error',
  manager: 'warning',
  member: 'primary',
  worker: 'success',
}

onMounted(async () => {
  try {
    const res = await api.get('/demo_accounts')
    demoAccounts.value = res.data.data
  } catch {
    // デモアカウント取得失敗は無視
  }
})

async function handleLogin() {
  errorMessage.value = ''
  loading.value = true
  try {
    await authStore.login(email.value, password.value)
    await router.push('/dashboard')
  } catch (e: any) {
    console.error('Login error:', e)
    if (e?.response?.status === 401) {
      errorMessage.value = 'メールアドレスまたはパスワードが正しくありません。'
    } else {
      errorMessage.value = e?.message || 'ログインに失敗しました。'
    }
  } finally {
    loading.value = false
  }
}

const AVATAR_COLORS = [
  '#2E5B7A', '#3D6E8C', '#6B7D5B', '#8C6A3D',
  '#7A4B3D', '#5B6B70', '#4B5A7A', '#2E7D4F',
]
function avatarColor(id: number) {
  return AVATAR_COLORS[id % AVATAR_COLORS.length]
}
function nameInitial(name: string) {
  return name.charAt(0)
}

async function loginAs(accountEmail: string) {
  errorMessage.value = ''
  loading.value = true
  try {
    await authStore.login(accountEmail, 'password')
    await router.push('/dashboard')
  } catch {
    errorMessage.value = 'ログインに失敗しました。'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="pk-login">
    <aside class="pk-login__brand">
      <router-link to="/" class="pk-login__brand-mark">
        <v-icon color="#E7B778" size="26">mdi-gauge-full</v-icon>
        <span>PlantKeeper</span>
      </router-link>
      <div class="pk-login__brand-copy">
        <h1>プラント保全業務を、<br />まるごと一つに。</h1>
        <p>設備台帳・点検記録・トラブル管理・資材管理を一元化した、現場発の統合管理システムです。</p>
      </div>
      <router-link to="/" class="pk-login__back">
        <v-icon size="16" class="mr-1">mdi-arrow-left</v-icon>
        トップページに戻る
      </router-link>
    </aside>

    <main class="pk-login__form">
      <div class="pk-login__form-inner">
        <h2 class="text-h5 font-weight-bold mb-1">ログイン</h2>
        <p class="text-body-2 text-medium-emphasis mb-6">アカウント情報を入力してください</p>

        <v-alert
          v-if="errorMessage"
          type="error"
          density="compact"
          variant="tonal"
          class="mb-4"
          role="alert"
        >
          {{ errorMessage }}
        </v-alert>

        <v-form @submit.prevent="handleLogin">
          <v-text-field
            v-model="email"
            label="メールアドレス"
            prepend-inner-icon="mdi-email-outline"
            type="email"
            required
          />
          <v-text-field
            v-model="password"
            label="パスワード"
            prepend-inner-icon="mdi-lock-outline"
            type="password"
            required
          />
          <v-btn
            type="submit"
            color="primary"
            block
            size="large"
            :loading="loading"
            class="mt-2"
          >
            ログイン
          </v-btn>
        </v-form>

        <template v-if="demoAccounts.length > 0">
          <v-divider class="my-6" />
          <div class="text-caption text-medium-emphasis mb-2">デモアカウント（クリックでログイン）</div>
          <div class="pk-demo-list">
            <button
              v-for="account in demoAccounts"
              :key="account.id"
              type="button"
              class="pk-demo-item"
              :disabled="loading"
              @click="loginAs(account.email)"
            >
              <v-avatar :color="avatarColor(account.id)" size="34" aria-hidden="true">
                <span class="text-white text-body-2 font-weight-bold">{{ nameInitial(account.name) }}</span>
              </v-avatar>
              <div class="pk-demo-item__body">
                <div class="pk-demo-item__name">{{ account.name }}</div>
                <div class="pk-demo-item__meta">
                  {{ [account.company_name, account.department_path].filter(Boolean).join(' / ') }}
                </div>
              </div>
              <v-chip :color="roleColor[account.system_role]" size="x-small" label>
                {{ roleLabel[account.system_role] ?? account.system_role }}
              </v-chip>
            </button>
          </div>
        </template>
      </div>
    </main>
  </div>
</template>

<style scoped>
.pk-login {
  min-height: 100dvh;
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
}

.pk-login__brand {
  background: var(--pk-ink);
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.05) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.05) 1px, transparent 1px);
  background-size: 44px 44px;
  color: #f5f6f5;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 2.5rem;
}

.pk-login__brand-mark {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-family: var(--pk-font-display);
  font-weight: 700;
  font-size: 1.1rem;
  color: #f5f6f5;
  text-decoration: none;
}

.pk-login__brand-copy h1 {
  font-family: var(--pk-font-display);
  font-weight: 800;
  font-size: clamp(1.6rem, 3vw, 2.4rem);
  line-height: 1.3;
  margin-bottom: 1rem;
  text-wrap: balance;
}

.pk-login__brand-copy p {
  color: rgba(245, 246, 245, 0.7);
  max-width: 400px;
  font-size: 0.95rem;
  text-wrap: pretty;
}

.pk-login__back {
  color: rgba(245, 246, 245, 0.55);
  text-decoration: none;
  font-size: 0.85rem;
  display: inline-flex;
  align-items: center;
  width: fit-content;
}

.pk-login__back:hover {
  color: #e7b778;
}

.pk-login__form {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  background: #fff;
}

.pk-login__form-inner {
  width: 100%;
  max-width: 400px;
}

.pk-demo-list {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  max-height: 260px;
  overflow-y: auto;
}

.pk-demo-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 0.6rem;
  border: 1px solid var(--pk-line);
  background: #fff;
  cursor: pointer;
  text-align: left;
  font: inherit;
  transition: border-color 0.15s ease, background 0.15s ease;
}

.pk-demo-item:hover:not(:disabled) {
  border-color: var(--pk-steel);
  background: rgba(46, 91, 122, 0.05);
}

.pk-demo-item:disabled {
  opacity: 0.5;
  cursor: default;
}

.pk-demo-item__body {
  flex: 1 1 auto;
  min-width: 0;
}

.pk-demo-item__name {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--pk-ink);
}

.pk-demo-item__meta {
  font-size: 0.75rem;
  color: #6b7678;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

@media (max-width: 900px) {
  .pk-login {
    grid-template-columns: 1fr;
    min-height: 0;
    align-content: start;
  }

  .pk-login__brand {
    padding: 2rem 1.5rem;
  }

  .pk-login__brand-copy p {
    display: none;
  }
}
</style>
