<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import { useRouter } from 'vue-router'

const authStore = useAuthStore()
const router = useRouter()

defineEmits<{
  'toggle-drawer': []
}>()

async function handleLogout() {
  await authStore.logout()
  router.push('/login')
}
</script>

<template>
  <v-app-bar color="primary" density="default">
    <v-app-bar-nav-icon @click="$emit('toggle-drawer')" />
    <v-app-bar-title>保全統合管理システム</v-app-bar-title>
    <v-spacer />
    <span v-if="authStore.user" class="mr-4 text-body-1">
      {{ authStore.user.name }}
    </span>
    <v-btn icon @click="handleLogout">
      <v-icon>mdi-logout</v-icon>
    </v-btn>
  </v-app-bar>
</template>
