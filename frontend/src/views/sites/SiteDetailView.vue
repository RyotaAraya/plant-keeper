<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'

const route = useRoute()
const router = useRouter()
const { canManageSite } = usePermissions()

const site = ref<any>(null)
const equipments = ref<any[]>([])
const loading = ref(false)
const tab = ref('equipments')

// --- 編集 ---
const editDialog = ref(false)
const editErrors = ref<string[]>([])
const editForm = ref({ name: '', prefecture: '', address: '', is_active: true, closed_on: '' })

function openEditSite() {
  editForm.value = {
    name: site.value.name,
    prefecture: site.value.prefecture || '',
    address: site.value.address || '',
    is_active: site.value.is_active,
    closed_on: site.value.closed_on || '',
  }
  editErrors.value = []
  editDialog.value = true
}

async function saveSite() {
  editErrors.value = []
  try {
    await api.patch(`/sites/${route.params.id}`, { site: editForm.value })
    editDialog.value = false
    await fetchSite()
  } catch (e: any) {
    editErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

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
          <v-spacer />
          <v-btn v-if="canManageSite" variant="outlined" size="small" prepend-icon="mdi-pencil" @click="openEditSite">編集</v-btn>
        </v-card-title>
        <v-card-text>
          <v-row>
            <v-col cols="12" md="4"><strong>所在県:</strong> {{ site.prefecture }}</v-col>
            <v-col cols="12" md="4"><strong>住所:</strong> {{ site.address }}</v-col>
            <v-col v-if="site.closed_on" cols="12" md="4"><strong>閉鎖日:</strong> {{ site.closed_on }}</v-col>
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
              prepend-icon="mdi-factory"
              @click="router.push(`/equipments/${eq.id}`)"
            />
            <v-list-item v-if="equipments.length === 0" title="設備がありません" />
          </v-list>
        </v-window-item>
      </v-window>
    </template>

    <!-- 拠点編集ダイアログ -->
    <v-dialog v-model="editDialog" max-width="500">
      <v-card>
        <v-card-title>拠点編集</v-card-title>
        <v-card-text>
          <v-alert v-if="editErrors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in editErrors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="editForm.name" label="拠点名" class="mb-2" />
          <v-text-field v-model="editForm.prefecture" label="所在県" class="mb-2" />
          <v-text-field v-model="editForm.address" label="住所" class="mb-2" />
          <v-switch v-model="editForm.is_active" label="稼働中" class="mb-2" />
          <v-text-field v-if="!editForm.is_active" v-model="editForm.closed_on" label="閉鎖日" type="date" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="editDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveSite">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>
