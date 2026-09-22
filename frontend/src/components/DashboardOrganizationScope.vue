<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import api from '@/api/axios'
import { useAuthStore } from '@/stores/auth'
import { usePermissions } from '@/composables/usePermissions'
import { latestGuard } from '@/utils/latestGuard'
import type { DashboardScope, DepartmentTreeNode } from '@/types/models'

const model = defineModel<DashboardScope>({ required: true })
const authStore = useAuthStore()
const { canViewSites } = usePermissions()
const sites = ref<{ id: number; name: string }[]>(authStore.user?.site ? [authStore.user.site] : [])
const tree = ref<DepartmentTreeNode[]>([])
const loading = ref(false)
const error = ref('')
const sitesError = ref(false)
const loadGuard = latestGuard()

const siteItems = computed(() => [{ id: null, name: '全拠点' }, ...sites.value])
const ownScope = computed<DashboardScope>(() => ({
  siteId: authStore.user?.site_id ?? null,
  departmentId: authStore.user?.department_id ?? null,
}))
const isOwnScope = computed(() => model.value.siteId === ownScope.value.siteId && model.value.departmentId === ownScope.value.departmentId)

function findPath(nodes: DepartmentTreeNode[], id: number | null): DepartmentTreeNode[] {
  for (const node of nodes) {
    if (node.id === id) return [node]
    const path = findPath(node.children, id)
    if (path.length) return [node, ...path]
  }
  return []
}

// 選択値から階層を求める。親の変更は1回の更新で子も解除し、watchの連鎖を作らない。
const path = computed(() => findPath(tree.value, model.value.departmentId))
const division = computed(() => path.value.find((node) => node.level === 'division'))
const section = computed(() => path.value.find((node) => node.level === 'section'))
const team = computed(() => path.value.find((node) => node.level === 'team'))
const levels = computed(() => [
  { label: '部', value: division.value?.id ?? null, nodes: tree.value, parentId: null, disabled: !model.value.siteId },
  { label: '課', value: section.value?.id ?? null, nodes: division.value?.children ?? [], parentId: division.value?.id ?? null, disabled: !division.value },
  { label: 'チーム', value: team.value?.id ?? null, nodes: section.value?.children ?? [], parentId: section.value?.id ?? null, disabled: !section.value },
])

async function loadDepartments() {
  const isLatest = loadGuard()
  const siteId = model.value.siteId
  tree.value = []
  error.value = ''
  loading.value = !!siteId
  if (!siteId) return
  try {
    const res = await api.get<{ data: DepartmentTreeNode[] }>('/departments', { params: { tree: true, site_id: siteId } })
    if (isLatest()) tree.value = res.data.data
  } catch {
    if (isLatest()) error.value = '組織の選択肢を読み込めませんでした。'
  } finally {
    if (isLatest()) loading.value = false
  }
}

async function loadSites() {
  if (!canViewSites.value) return
  sitesError.value = false
  try {
    const res = await api.get('/sites', { params: { per_page: 100, is_active: true } })
    const ownSite = authStore.user?.site
    const items: { id: number; name: string }[] = res.data.data
    if (ownSite && !items.some((site) => site.id === ownSite.id)) items.push(ownSite)
    sites.value = items.sort((a, b) => Number(b.id === ownSite?.id) - Number(a.id === ownSite?.id))
  } catch {
    sitesError.value = true
  }
}

watch(() => model.value.siteId, loadDepartments, { immediate: true })
onMounted(loadSites)
</script>

<template>
  <section class="pk-organization-scope" aria-label="表示する組織を選ぶ">
    <div class="pk-organization-scope__heading">
      <span>表示する組織</span>
      <v-btn size="small" variant="text" color="primary" :disabled="isOwnScope" @click="model = { ...ownScope }">
        <v-icon start size="16" aria-hidden="true">mdi-restore</v-icon>自分の所属に戻す
      </v-btn>
    </div>
    <div class="pk-organization-scope__fields">
      <v-select
        v-if="canViewSites"
        :model-value="model.siteId"
        :items="siteItems"
        item-title="name"
        item-value="id"
        label="拠点"
        density="compact"
        hide-details
        @update:model-value="model = { siteId: $event, departmentId: null }"
      />
      <div v-else class="pk-organization-scope__fixed">
        <span>拠点</span>
        <strong>{{ authStore.user?.site?.name ?? '所属拠点なし' }}</strong>
      </div>
      <template v-for="level in levels" :key="level.label">
        <v-icon class="pk-organization-scope__arrow" size="18" aria-hidden="true">mdi-chevron-right</v-icon>
        <v-select
          :model-value="level.value"
          :items="[{ id: null, name: 'すべて' }, ...level.nodes]"
          item-title="name"
          item-value="id"
          :label="level.label"
          density="compact"
          hide-details
          :disabled="level.disabled || loading || !!error"
          :loading="loading"
          @update:model-value="model = { ...model, departmentId: $event ?? level.parentId }"
        />
      </template>
    </div>
    <div v-if="error" class="pk-organization-scope__error" role="alert">
      {{ error }} <v-btn size="small" variant="text" @click="loadDepartments">再読み込み</v-btn>
    </div>
    <div v-if="sitesError" class="pk-organization-scope__error" role="alert">
      拠点の選択肢を読み込めませんでした。<v-btn size="small" variant="text" @click="loadSites">再読み込み</v-btn>
    </div>
  </section>
</template>

<style scoped>
.pk-organization-scope {
  padding: 16px 20px 20px;
  border: 1px solid var(--pk-line);
  border-radius: 16px;
  background: #fff;
}
.pk-organization-scope__heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
  color: var(--pk-steel-dark);
  font-size: 0.8125rem;
  font-weight: 700;
}
.pk-organization-scope__fields {
  display: grid;
  grid-template-columns: minmax(0, 1.2fr) repeat(3, 24px minmax(0, 1fr));
  align-items: center;
  gap: 8px;
}
.pk-organization-scope__fields > * { min-width: 0; }
.pk-organization-scope__arrow { justify-self: center; color: var(--pk-muted); }
.pk-organization-scope__fixed { display: grid; gap: 4px; font-size: 0.875rem; }
.pk-organization-scope__fixed > span { color: var(--pk-muted); font-size: 0.75rem; }
.pk-organization-scope__error { margin-top: 12px; color: rgb(var(--v-theme-error)); font-size: 0.8125rem; }
@media (max-width: 1100px) {
  .pk-organization-scope__fields { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; }
  .pk-organization-scope__arrow { display: none; }
}
@media (max-width: 600px) {
  .pk-organization-scope { padding: 12px; }
  .pk-organization-scope__fields { gap: 12px; }
}
</style>
