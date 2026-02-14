<script setup lang="ts">
import { ref } from 'vue'
import AppBar from '@/components/layout/AppBar.vue'
import SideNav from '@/components/layout/SideNav.vue'

const drawer = ref(true)

function toggleDrawer() {
  drawer.value = !drawer.value
}
</script>

<template>
  <v-app>
    <AppBar @toggle-drawer="toggleDrawer" />
    <SideNav v-model="drawer" />
    <v-main>
      <v-container fluid>
        <slot />
      </v-container>
    </v-main>
  </v-app>
</template>
