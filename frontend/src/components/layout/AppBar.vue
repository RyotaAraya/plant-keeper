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
  <v-app-bar color="primary" density="default">
    <v-app-bar-nav-icon @click="$emit('toggle-drawer')" />
    <v-app-bar-title>PlantKeeper</v-app-bar-title>
    <v-spacer />
    <div v-if="authStore.user" class="mr-4 text-right">
      <div class="text-body-2">{{ authStore.user.name }}</div>
      <div class="text-caption opacity-80">{{ roleLabel }}・{{ companyName }}</div>
    </div>
    <v-btn icon @click="handleLogout">
      <v-icon>mdi-logout</v-icon>
    </v-btn>
  </v-app-bar>
</template>
