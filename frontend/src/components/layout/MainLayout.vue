<script setup lang="ts">
import { ref } from 'vue'
import { useDisplay } from 'vuetify'
import AppBar from '@/components/layout/AppBar.vue'
import SideNav from '@/components/layout/SideNav.vue'

const { mobile } = useDisplay()
const drawer = ref(!mobile.value)

function toggleDrawer() {
  drawer.value = !drawer.value
}
</script>

<template>
  <AppBar @toggle-drawer="toggleDrawer" />
  <SideNav v-model="drawer" />
  <v-main style="background: var(--pk-mist)">
    <v-container fluid class="pk-workspace">
      <slot />
    </v-container>
  </v-main>
</template>

<style scoped>
.pk-workspace { max-width: 1680px; padding: 28px 32px 48px; }
@media (max-width: 600px) { .pk-workspace { padding: 20px 16px 32px; } }
</style>
