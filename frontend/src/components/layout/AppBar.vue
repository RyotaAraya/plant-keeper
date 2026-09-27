<script setup lang="ts">
import { computed } from 'vue'
import { useNavigation } from '@/composables/useNavigation'
import { confirmUnsavedWork } from '@/composables/useUnsavedWork'
import { useAuthStore } from '@/stores/auth'
import { useRoute, useRouter } from 'vue-router'

const authStore = useAuthStore()
const router = useRouter()
const route = useRoute()
const { items } = useNavigation()
const section = computed(() =>
  items.value.find((item) => [item.to, ...(item.also ?? [])].some((path) => route.path === path || route.path.startsWith(`${path}/`))),
)
const detailLabel = computed(() => {
  if (!section.value || route.path === section.value.to) return ''
  if (route.name === 'InspectionNew') return '新規点検'
  if (route.name === 'InspectionEdit') return '点検の編集'
  if (route.name === 'SettingsReseed') return 'デモデータの再投入'
  if (route.name === 'Integrations') return '外部連携'
  return '詳細'
})

const roleLabels: Record<string, string> = { admin: 'システム管理者', manager: '業務管理者', member: '一般', worker: '技能員' }
const roleLabel = computed(() => roleLabels[authStore.user?.system_role ?? ''] ?? '')

defineEmits<{
  'toggle-drawer': []
}>()

async function handleLogout() {
  if (!confirmUnsavedWork()) return
  await authStore.logout()
  router.push('/login')
}
</script>

<template>
  <v-app-bar density="default">
    <v-app-bar-nav-icon aria-label="メニューを開閉" @click="$emit('toggle-drawer')" />
    <nav class="pk-app-location" aria-label="現在の場所">
      <router-link to="/home" :aria-current="route.path === '/home' ? 'page' : undefined">ホーム</router-link>
      <template v-if="section && section.to !== '/home'">
        <span aria-hidden="true">/</span>
        <router-link v-if="detailLabel" :to="section.to" :aria-label="`${section.title}の一覧へ戻る`">{{ section.title }}</router-link>
        <span v-else aria-current="page">{{ section.title }}</span>
      </template>
      <template v-if="detailLabel"><span aria-hidden="true">/</span><span aria-current="page">{{ detailLabel }}</span></template>
    </nav>
    <v-spacer />
    <v-menu v-if="authStore.user" location="bottom end" :offset="8">
      <template #activator="{ props }">
        <v-btn v-bind="props" variant="text" class="pk-account-button mr-3" aria-label="アカウントメニュー">
          <span class="pk-account-avatar" aria-hidden="true">{{ authStore.user.name.trim().slice(0, 1) }}</span>
          <span class="d-none d-sm-inline">{{ authStore.user.name }}</span>
          <v-icon size="16" aria-hidden="true">mdi-chevron-down</v-icon>
        </v-btn>
      </template>
      <v-card width="280" class="pk-account-menu">
        <div class="pa-5">
          <p class="font-weight-bold mb-1">{{ authStore.user.name }}</p>
          <p class="text-body-2 text-medium-emphasis">{{ authStore.user.company?.name }}</p>
          <p class="text-body-2 text-medium-emphasis mt-3"><v-icon size="16" class="mr-1" aria-hidden="true">mdi-domain</v-icon>{{ authStore.user.site?.name ?? '所属拠点なし' }}</p>
          <p class="text-caption text-medium-emphasis mt-1">{{ roleLabel }}</p>
        </div>
        <v-divider />
        <v-list density="compact" class="pa-1">
          <v-list-item title="ログアウト" prepend-icon="mdi-logout-variant" @click="handleLogout" />
        </v-list>
      </v-card>
    </v-menu>
  </v-app-bar>
</template>

<style scoped>
.pk-app-location { display: flex; align-items: center; gap: 12px; color: var(--pk-muted); font-size: 0.8125rem; }
.pk-app-location a { color: inherit; text-decoration: none; }
.pk-app-location a:hover { color: var(--pk-steel); text-decoration: underline; }
.pk-account-button { color: var(--pk-steel-dark); }
.pk-account-button :deep(.v-btn__content) { gap: 8px; }
.pk-account-avatar { display: grid; place-items: center; width: 30px; height: 30px; border: 1px solid var(--pk-line); border-radius: 50%; background: var(--pk-mist); font-size: 0.75rem; font-weight: 700; }
</style>
