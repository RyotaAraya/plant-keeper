<script setup lang="ts">
</script>

<template>
  <v-app>
    <router-view v-slot="{ Component, route }">
      <!-- 点検の新規・編集を切り替えるときは、別の記録の入力を残さない。 -->
      <component :is="Component" :key="route.name === 'InspectionNew' || route.name === 'InspectionEdit' ? route.fullPath : undefined" />
    </router-view>
  </v-app>
</template>
