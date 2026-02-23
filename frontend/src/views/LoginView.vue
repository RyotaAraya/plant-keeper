<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import api from '@/api/axios'

const authStore = useAuthStore()
const router = useRouter()

const email = ref('')
const password = ref('')
const errorMessage = ref('')
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
    await router.push('/')
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
  '#1565C0', '#2E7D32', '#6A1B9A', '#00838F',
  '#E65100', '#AD1457', '#4527A0', '#00695C',
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
    await router.push('/')
  } catch {
    errorMessage.value = 'ログインに失敗しました。'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <v-main>
    <v-container class="fill-height" fluid>
      <v-row align="center" justify="center">
        <v-col cols="12" sm="8" md="5">
          <v-card class="elevation-12">
            <v-toolbar color="primary" dark flat>
              <v-toolbar-title>PlantKeeper</v-toolbar-title>
            </v-toolbar>
            <v-card-text>
              <v-alert
                v-if="errorMessage"
                type="error"
                density="compact"
                class="mb-4"
              >
                {{ errorMessage }}
              </v-alert>
              <v-form @submit.prevent="handleLogin">
                <v-text-field
                  v-model="email"
                  label="メールアドレス"
                  prepend-icon="mdi-email"
                  type="email"
                  required
                />
                <v-text-field
                  v-model="password"
                  label="パスワード"
                  prepend-icon="mdi-lock"
                  type="password"
                  required
                />
                <v-btn
                  type="submit"
                  color="primary"
                  block
                  size="large"
                  :loading="loading"
                  class="mt-4"
                >
                  ログイン
                </v-btn>
              </v-form>
            </v-card-text>

            <template v-if="demoAccounts.length > 0">
              <v-divider />
              <v-card-text class="pb-1">
                <div class="text-caption text-medium-emphasis mb-1">デモアカウント（クリックでログイン）</div>
              </v-card-text>
              <v-list
                density="compact"
                style="max-height: 280px; overflow-y: auto;"
              >
                <v-list-item
                  v-for="account in demoAccounts"
                  :key="account.id"
                  :disabled="loading"
                  rounded="lg"
                  class="mx-2 mb-1"
                  @click="loginAs(account.email)"
                >
                  <template #prepend>
                    <v-avatar :color="avatarColor(account.id)" size="32">
                      <span class="text-white text-body-2 font-weight-bold">{{ nameInitial(account.name) }}</span>
                    </v-avatar>
                  </template>
                  <v-list-item-title>{{ account.name }}</v-list-item-title>
                  <v-list-item-subtitle>
                    {{ [account.company_name, account.department_path].filter(Boolean).join(' / ') }}
                  </v-list-item-subtitle>
                  <template #append>
                    <v-chip
                      :color="roleColor[account.system_role]"
                      size="x-small"
                      label
                    >
                      {{ roleLabel[account.system_role] ?? account.system_role }}
                    </v-chip>
                  </template>
                </v-list-item>
              </v-list>
              <div class="pb-2" />
            </template>
          </v-card>
        </v-col>
      </v-row>
    </v-container>
  </v-main>
</template>
