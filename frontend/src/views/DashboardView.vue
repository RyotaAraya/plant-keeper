<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import MainLayout from '@/components/layout/MainLayout.vue'

const authStore = useAuthStore()
</script>

<template>
  <MainLayout>
    <h1 class="text-h5 mb-4">
      ようこそ、{{ authStore.user?.name ?? '' }} さん
    </h1>

    <v-row>
      <v-col cols="12" md="4">
        <v-card>
          <v-card-title>
            <v-icon class="mr-2">mdi-alert-circle</v-icon>
            トラブル対応状況
          </v-card-title>
          <v-card-text class="text-body-1">
            準備中
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card>
          <v-card-title>
            <v-icon class="mr-2">mdi-clipboard-check</v-icon>
            点検スケジュール
          </v-card-title>
          <v-card-text class="text-body-1">
            準備中
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card>
          <v-card-title>
            <v-icon class="mr-2">mdi-package-variant</v-icon>
            在庫アラート
          </v-card-title>
          <v-card-text class="text-body-1">
            準備中
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </MainLayout>
</template>
