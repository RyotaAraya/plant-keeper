<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import DetailHeader from '@/components/layout/DetailHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import { useDetailTab } from '@/composables/useDetailTab'
import { usePermissions } from '@/composables/usePermissions'
import { invalidateActiveSites } from '@/composables/useSiteScope'

const route = useRoute()
const router = useRouter()
const { canManageSite } = usePermissions()

const site = ref<any>(null)
const equipments = ref<any[]>([])
const loading = ref(false)
// 詳細の中身は「概要 → タブ」
const tab = useDetailTab(() => ['equipments'])

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
    invalidateActiveSites()
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
    <v-skeleton-loader v-if="loading" type="card" />

    <template v-else-if="site">
      <DetailHeader back-to="/sites" back-label="拠点管理" kind="拠点" :title="site.name">
        <template #status>
          <StatusChip :label="site.is_active ? '稼働中' : '閉鎖'" :color="site.is_active ? 'success' : 'grey'" />
        </template>
        <template #actions>
          <v-btn v-if="canManageSite" variant="outlined" prepend-icon="mdi-pencil" @click="openEditSite">編集</v-btn>
        </template>
      </DetailHeader>
      <!-- 概要: 常に見える基本情報 -->
      <v-card class="mb-4 pk-summary" data-testid="detail-summary">
        <v-card-text>
          <dl class="pk-summary__grid">
            <div><dt>所在県</dt><dd>{{ site.prefecture }}</dd></div>
            <div class="pk-summary__wide"><dt>住所</dt><dd>{{ site.address }}</dd></div>
            <div v-if="site.closed_on"><dt>閉鎖日</dt><dd>{{ site.closed_on }}</dd></div>
            <div><dt>設備数</dt><dd class="pk-mono">{{ site.equipments_count }}</dd></div>
            <div><dt>倉庫数</dt><dd class="pk-mono">{{ site.warehouses_count }}</dd></div>
          </dl>
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
