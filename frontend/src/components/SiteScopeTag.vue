<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import api from '@/api/axios'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'

// 一覧がどの拠点を表示しているかを示す銘板。全ての一覧の絞り込みの行の左端に置く。
// 拠点は複数選べる。初期値は自分の所属拠点（呼び出し側で決める）。全拠点を選ぶと、拠点をまたいで見られる。
// 空の配列は全拠点を表す（絞り込みなし）。拠点の一覧を見られない協力会社は切り替えられず、所属拠点の表示だけになる
const model = defineModel<number[]>({ required: true })

const { canViewSites } = usePermissions()
const authStore = useAuthStore()

const sites = ref<{ id: number; name: string }[]>([])
const ownSiteId = computed(() => authStore.user?.site_id ?? null)

onMounted(async () => {
  if (!canViewSites.value) return
  const res = await api.get('/sites', { params: { per_page: 100, is_active: true } })
  // 所属拠点を先頭に置く（切り替えたあとに戻りやすいように）
  sites.value = [...res.data.data].sort((a, b) => Number(b.id === ownSiteId.value) - Number(a.id === ownSiteId.value))
})

const switchable = computed(() => canViewSites.value && sites.value.length > 1)

// 選択中の拠点。空は全拠点（メニューでは全てにチェックが付く）
const selectedIds = computed(() => (model.value.length ? model.value : sites.value.map((s) => s.id)))
const isAll = computed(() => sites.value.length > 0 && sites.value.every((s) => selectedIds.value.includes(s.id)))

const label = computed(() => {
  if (!switchable.value) return authStore.user?.site?.name ?? '所属拠点'
  if (isAll.value) return '全拠点'
  const chosen = sites.value.filter((s) => selectedIds.value.includes(s.id))
  const first = chosen[0]?.name ?? '拠点を選択'
  return chosen.length > 1 ? `${first} ほか${chosen.length - 1}` : first
})

function toggle(id: number) {
  const current = selectedIds.value
  const next = current.includes(id) ? current.filter((v) => v !== id) : [...current, id]
  // 全ての拠点を外すことはできない（少なくとも1つは選んでおく）
  if (!next.length) return
  // 稼働中の全拠点を選んだ状態は、全拠点（空）にそろえる。表示は「全拠点」なのに、非稼働の拠点のデータだけ外れる、を防ぐ
  model.value = sites.value.every((s) => next.includes(s.id)) ? [] : next
}

function selectOwn() {
  model.value = ownSiteId.value ? [ownSiteId.value] : []
}
</script>

<template>
  <v-menu v-if="switchable" location="bottom start" :close-on-content-click="false">
    <template #activator="{ props: menuProps }">
      <button v-bind="menuProps" type="button" class="pk-site-scope pk-site-scope--switchable" aria-label="表示する拠点を選ぶ">
        <v-icon size="18" aria-hidden="true">mdi-domain</v-icon>
        <span>{{ label }}</span>
        <v-icon size="18" aria-hidden="true">mdi-chevron-down</v-icon>
      </button>
    </template>
    <v-card min-width="240">
      <v-list density="compact" role="menu">
        <v-list-item
          v-for="site in sites"
          :key="site.id"
          :title="site.name"
          :subtitle="site.id === ownSiteId ? '所属拠点' : undefined"
          role="menuitemcheckbox"
          :aria-checked="selectedIds.includes(site.id)"
          @click="toggle(site.id)"
        >
          <template #prepend>
            <v-checkbox-btn :model-value="selectedIds.includes(site.id)" density="compact" tabindex="-1" aria-hidden="true" class="pointer-events-none" />
          </template>
        </v-list-item>
      </v-list>
      <v-divider />
      <div class="d-flex justify-space-between pa-1">
        <v-btn size="small" variant="text" :disabled="!ownSiteId" @click="selectOwn">所属拠点だけ</v-btn>
        <v-btn size="small" variant="text" @click="model = []">全拠点</v-btn>
      </div>
    </v-card>
  </v-menu>
  <span v-else class="pk-site-scope">
    <v-icon size="18" aria-hidden="true">mdi-domain</v-icon>
    <span>{{ label }}</span>
  </span>
</template>

<style scoped>
.pk-site-scope {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 40px;
  padding: 0 0.75rem;
  border: 1px solid var(--pk-line);
  border-left: 3px solid var(--pk-amber);
  background: var(--pk-mist);
  color: var(--pk-steel-dark);
  font-family: var(--pk-font-display);
  font-size: 0.9375rem;
  font-weight: 700;
  white-space: nowrap;
}

.pk-site-scope--switchable {
  cursor: pointer;
}

.pk-site-scope--switchable:hover {
  border-color: var(--pk-steel);
  border-left-color: var(--pk-amber);
}

.pointer-events-none {
  pointer-events: none;
}
</style>
