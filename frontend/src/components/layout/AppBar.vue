<script setup lang="ts">
import { computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useRouter } from 'vue-router'

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

async function handleLogout() {
  await authStore.logout()
  router.push('/login')
}
</script>

<template>
  <v-app-bar density="default">
    <v-app-bar-nav-icon @click="$emit('toggle-drawer')" />
    <v-spacer />
    <div v-if="authStore.user" class="mr-4 text-right">
      <div class="text-body-2 font-weight-medium">{{ authStore.user.name }}</div>
      <div class="text-caption text-medium-emphasis pk-mono">{{ roleLabel }} / {{ companyName }}</div>
    </div>
    <v-btn icon variant="text" aria-label="ログアウト" @click="handleLogout">
      <v-icon>mdi-logout-variant</v-icon>
    </v-btn>
  </v-app-bar>
</template>
