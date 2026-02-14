<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'

const route = useRoute()
const router = useRouter()

const site = ref<any>(null)
const equipments = ref<any[]>([])
const loading = ref(false)
const tab = ref('equipments')

async function fetchSite() {
  loading.value = true
  try {
    const res = await api.get(`/sites/${route.params.id}`)
    site.value = res.data.data
    const eqRes = await api.get('/equipments', { params: { site_id: route.params.id, per_page: 100 } })
    equipments.value = eqRes.data.data
  } finally {
    loading.value = false
  }
}

onMounted(fetchSite)
</script>

<template>
  <MainLayout>
    <v-btn variant="text" prepend-icon="mdi-arrow-left" class="mb-2" @click="router.push('/sites')">
      拠点一覧に戻る
    </v-btn>

    <v-skeleton-loader v-if="loading" type="card" />

    <template v-else-if="site">
      <v-card class="mb-4">
        <v-card-title class="d-flex align-center">
          {{ site.name }}
          <v-chip :color="site.is_active ? 'success' : 'grey'" size="small" class="ml-2">
            {{ site.is_active ? '稼働中' : '閉鎖' }}
          </v-chip>
        </v-card-title>
        <v-card-text>
          <v-row>
            <v-col cols="12" md="4"><strong>所在県:</strong> {{ site.prefecture }}</v-col>
            <v-col cols="12" md="4"><strong>住所:</strong> {{ site.address }}</v-col>
            <v-col cols="12" md="4" v-if="site.closed_on"><strong>閉鎖日:</strong> {{ site.closed_on }}</v-col>
          </v-row>
          <v-row class="mt-2">
            <v-col cols="6" md="3">
              <v-card variant="tonal" class="text-center pa-3">
                <div class="text-h5">{{ site.equipments_count }}</div>
                <div class="text-body-2">設備数</div>
              </v-card>
            </v-col>
            <v-col cols="6" md="3">
              <v-card variant="tonal" class="text-center pa-3">
                <div class="text-h5">{{ site.warehouses_count }}</div>
                <div class="text-body-2">倉庫数</div>
              </v-card>
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="equipments">設備一覧</v-tab>
      </v-tabs>

      <v-window v-model="tab">
        <v-window-item value="equipments">
          <v-list>
            <v-list-item
              v-for="eq in equipments"
              :key="eq.id"
              :title="eq.name"
              :subtitle="eq.description"
              @click="router.push(`/equipments/${eq.id}`)"
              prepend-icon="mdi-factory"
            />
            <v-list-item v-if="equipments.length === 0" title="設備がありません" />
          </v-list>
        </v-window-item>
      </v-window>
    </template>
  </MainLayout>
</template>
