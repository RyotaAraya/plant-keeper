<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const router = useRouter()

const email = ref('')
const password = ref('')
const errorMessage = ref('')
const loading = ref(false)

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
</script>

<template>
  <v-app>
    <v-main>
      <v-container class="fill-height" fluid>
        <v-row align="center" justify="center">
          <v-col cols="12" sm="8" md="4">
            <v-card class="elevation-12">
              <v-toolbar color="primary" dark flat>
                <v-toolbar-title>保全統合管理システム</v-toolbar-title>
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
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </v-main>
  </v-app>
</template>
