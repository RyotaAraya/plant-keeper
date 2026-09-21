<script setup lang="ts">
import { computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useRouter } from 'vue-router'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'

const authStore = useAuthStore()
const router = useRouter()

defineEmits<{
  'toggle-drawer': []
}>()

const ROLE_LABELS: Record<string, string> = {
  admin: 'システム管理者',
  manager: '業務管理者',
  member: '一般',
  worker: '技能員',
}

const roleLabel = computed(() => {
  const role = authStore.user?.system_role
  return role ? (ROLE_LABELS[role] ?? role) : ''
})

const companyName = computed(() => authStore.user?.company?.name ?? '')
// 所属拠点。拠点の一覧を見られない協力会社にも、自分の拠点だけは分かるようにする
const siteName = computed(() => authStore.user?.site?.name ?? '')

async function handleLogout() {
  await authStore.logout()
  router.push('/login')
}
</script>

<template>
  <v-app-bar density="default">
    <v-app-bar-nav-icon aria-label="メニューを開閉" @click="$emit('toggle-drawer')" />
    <span class="pk-app-label d-none d-md-inline">保全ワークスペース</span>
    <v-spacer />
    <!-- どの画面からでもプラナを呼び出せる入口（専用ページ /plana へ） -->
    <v-btn to="/plana" variant="tonal" color="primary" class="mr-2" aria-label="プラナに相談" data-testid="plana-call">
      <template #prepend><PlanaAvatar :size="26" /></template>
      <span class="d-none d-sm-inline">プラナに相談</span>
    </v-btn>
    <div v-if="authStore.user" class="mr-4 text-right">
      <div class="text-body-2 font-weight-medium">
        <span v-if="siteName" class="pk-site-tag mr-2"><v-icon size="14" aria-hidden="true">mdi-domain</v-icon>{{ siteName }}</span>
        {{ authStore.user.name }}
      </div>
      <div class="text-caption text-medium-emphasis d-none d-sm-block">{{ roleLabel }} / {{ companyName }}</div>
    </div>
    <v-btn icon variant="text" aria-label="ログアウト" @click="handleLogout">
      <v-icon>mdi-logout-variant</v-icon>
    </v-btn>
  </v-app-bar>
</template>

<style scoped>
.pk-app-label { color: var(--pk-muted); font-size: 0.8125rem; }
@media (max-width: 600px) { .pk-site-tag { display: none; } }
</style>
