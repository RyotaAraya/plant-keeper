<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import PageHeader from '@/components/layout/PageHeader.vue'
import FilterResetButton from '@/components/FilterResetButton.vue'
import ListCount from '@/components/ListCount.vue'
import { useSavedFilters } from '@/composables/useSavedFilters'
import { usePermissions } from '@/composables/usePermissions'
import { invalidateActiveSites } from '@/composables/useSiteScope'

const router = useRouter()
const { canManageSite } = usePermissions()

const sites = ref<any[]>([])
const loading = ref(false)
const loadError = ref(false)
const totalCount = ref<number | null>(null)
// 閉鎖拠点の表示は保存して、開き直したときに戻す
const saved = useSavedFilters<{ show_inactive: boolean }>('sites', { show_inactive: 'boolean' })
const showInactive = ref(saved.load().show_inactive ?? false)
saved.hold({ show_inactive: showInactive.value })

// 表のページ（リセットで先頭に戻す）
const tablePage = ref(1)

function reset() {
  tablePage.value = 1
  saved.clear()
  showInactive.value = false
  saved.hold({ show_inactive: false })
}
const dialog = ref(false)
const editingId = ref<number | null>(null)
const form = ref({ name: '', prefecture: '', address: '', is_active: true, closed_on: '' })
const errors = ref<string[]>([])

const headers = [
  { title: '拠点名', key: 'name' },
  { title: '所在県', key: 'prefecture' },
  { title: '住所', key: 'address' },
  { title: '状態', key: 'is_active', width: '100px' },
  { title: '', key: 'actions', sortable: false, width: '60px' },
]

async function fetchSites() {
  loading.value = true
  loadError.value = false
  try {
    const params: any = { per_page: 1000 }
    if (!showInactive.value) params.is_active = true
    const res = await api.get('/sites', { params })
    sites.value = res.data.data
    totalCount.value = res.data.meta?.total_count ?? res.data.data.length
  } catch {
    loadError.value = true
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingId.value = null
  form.value = { name: '', prefecture: '', address: '', is_active: true, closed_on: '' }
  errors.value = []
  dialog.value = true
}

function openEdit(item: any) {
  editingId.value = item.id
  form.value = { name: item.name, prefecture: item.prefecture || '', address: item.address || '', is_active: item.is_active, closed_on: item.closed_on || '' }
  errors.value = []
  dialog.value = true
}

async function save() {
  errors.value = []
  try {
    if (editingId.value) {
      await api.patch(`/sites/${editingId.value}`, { site: form.value })
    } else {
      await api.post('/sites', { site: form.value })
    }
    invalidateActiveSites()
    dialog.value = false
    await fetchSites()
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

function goToDetail(row: any) {
  router.push(`/sites/${row.id}`)
}

onMounted(fetchSites)
watch(showInactive, (value) => {
  saved.save({ show_inactive: value })
  void fetchSites()
})
</script>

<template>
  <MainLayout>
    <PageHeader title="拠点管理" description="製油所などの拠点の一覧です。設備・部署・倉庫は拠点ごとに管理します。">
      <v-btn v-if="canManageSite" color="primary" prepend-icon="mdi-plus" @click="openCreate">新規登録</v-btn>
    </PageHeader>

    <div class="pk-filters">
      <v-switch v-model="showInactive" label="閉鎖拠点を表示" density="compact" hide-details />
      <FilterResetButton @reset="reset" />
    </div>

    <ListCount :total="totalCount" :shown="sites.length" :loading="loading" :error="loadError" />

    <v-data-table
      v-model:page="tablePage"
      :headers="headers"
      :items="sites"
      :loading="loading"
      hover
      class="cursor-pointer"
      @click:row="(_e: any, { item }: any) => goToDetail(item)"
    >
      <template #item.name="{ item }"><span class="pk-keep-words">{{ item.name }}</span></template>
      <template #item.prefecture="{ item }">{{ item.prefecture || '—' }}</template>
      <template #item.address="{ item }">{{ item.address || '—' }}</template>
      <template #item.is_active="{ item }">
        <v-chip :color="item.is_active ? 'success' : 'grey'" size="small">
          {{ item.is_active ? '稼働中' : '閉鎖' }}
        </v-chip>
      </template>
      <template #item.actions="{ item }">
        <v-btn v-if="canManageSite" icon="mdi-pencil" size="x-small" variant="text" :aria-label="`${item.name}を編集`" @click.stop="openEdit(item)" />
      </template>
    </v-data-table>

    <v-dialog v-model="dialog" max-width="600">
      <v-card>
        <v-card-title>{{ editingId ? '拠点の編集' : '拠点の登録' }}</v-card-title>
        <v-card-text>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-text-field v-model="form.name" label="拠点名" class="mb-2" />
          <v-text-field v-model="form.prefecture" label="所在県" class="mb-2" />
          <v-text-field v-model="form.address" label="住所" class="mb-2" />
          <v-switch v-model="form.is_active" label="稼働中" class="mb-2" />
          <v-text-field v-if="!form.is_active" v-model="form.closed_on" label="閉鎖日" type="date" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">キャンセル</v-btn>
          <v-btn color="primary" variant="flat" @click="save">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
