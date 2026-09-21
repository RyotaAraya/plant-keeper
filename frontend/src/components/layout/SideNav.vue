<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { usePermissions } from '@/composables/usePermissions'
import { useDisplay } from 'vuetify'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'

const route = useRoute()
const { mobile } = useDisplay()

defineProps<{
  modelValue: boolean
}>()

defineEmits<{
  'update:modelValue': [value: boolean]
}>()

const {
  canManageUsers,
  canViewAuditLogs,
  canAccessSettings,
  canManageOrders,
  canManageRepairs,
  canViewStocks,
  canViewMaterials,
  canViewSites,
} = usePermissions()

type NavItem = { title: string; icon: string; to: string; permission?: { value: boolean } }
type NavGroup = { label?: string; items: NavItem[] }

// 業務の流れ順にグループ化する。項目名は変えない（E2Eがリンク名で辿るため）。
// 見出しは、見える項目が1つもないグループでは出さない（協力会社や一般ユーザ向けの整理）。
const navGroups: NavGroup[] = [
  {
    items: [{ title: 'ダッシュボード', icon: 'mdi-view-dashboard-outline', to: '/dashboard' }],
  },
  {
    label: '日々の保全',
    items: [
      { title: '点検計画', icon: 'mdi-calendar-alert', to: '/inspection-plans' },
      { title: '点検・作業記録', icon: 'mdi-clipboard-check-outline', to: '/inspections' },
      { title: 'トラブル管理', icon: 'mdi-alert-circle-outline', to: '/troubles' },
      { title: '定期整備', icon: 'mdi-wrench-outline', to: '/maintenances' },
    ],
  },
  {
    label: '設備',
    items: [
      { title: '拠点管理', icon: 'mdi-domain', to: '/sites', permission: canViewSites },
      { title: '設備台帳', icon: 'mdi-factory', to: '/equipments' },
      { title: '装置・計器', icon: 'mdi-gauge', to: '/instruments' },
      { title: '基準器', icon: 'mdi-ruler-square', to: '/reference-standards' },
    ],
  },
  {
    label: '資材',
    items: [
      { title: '資材管理', icon: 'mdi-package-variant', to: '/materials', permission: canViewMaterials },
      { title: '在庫管理', icon: 'mdi-warehouse', to: '/stocks', permission: canViewStocks },
      { title: '修理管理', icon: 'mdi-hammer-wrench', to: '/repairs', permission: canManageRepairs },
      { title: '発注管理', icon: 'mdi-cart-outline', to: '/orders', permission: canManageOrders },
    ],
  },
  {
    label: '管理',
    items: [
      { title: '部署管理', icon: 'mdi-office-building-outline', to: '/departments', permission: canManageUsers },
      { title: 'ユーザ管理', icon: 'mdi-account-group-outline', to: '/users', permission: canManageUsers },
      { title: '監査ログ', icon: 'mdi-file-document-outline', to: '/audit-logs', permission: canViewAuditLogs },
      { title: '設定', icon: 'mdi-cog-outline', to: '/settings', permission: canAccessSettings },
    ],
  },
]

const visibleGroups = computed(() =>
  navGroups
    .map((group) => ({ ...group, items: group.items.filter((item) => !item.permission || item.permission.value) }))
    .filter((group) => group.items.length > 0),
)

// 詳細画面（/sites/:id 等）は一覧と別ルートのため、Vue Routerの自動判定だけでは
// アクティブ表示が外れてしまう。パスの前方一致で明示的に判定する。
function isItemActive(path: string) {
  return route.path === path || route.path.startsWith(`${path}/`)
}
</script>

<template>
  <v-navigation-drawer
    :model-value="modelValue"
    :permanent="!mobile"
    :temporary="mobile"
    :inert="mobile && !modelValue"
    class="pk-sidenav"
    width="248"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="pk-sidenav__brand">
      <v-icon size="26" color="primary">mdi-gauge-full</v-icon>
      <span class="pk-sidenav__brand-text">PlantKeeper</span>
    </div>
    <router-link to="/plana" class="pk-sidenav__assistant">
      <PlanaAvatar :size="38" />
      <span><strong>プラナ</strong><small>記録と調べものをサポート</small></span>
      <v-icon size="16" aria-hidden="true">mdi-chevron-right</v-icon>
    </router-link>
    <v-list nav class="pk-sidenav__list">
      <template v-for="group in visibleGroups" :key="group.label ?? 'top'">
        <v-list-subheader v-if="group.label" class="pk-sidenav__group">{{ group.label }}</v-list-subheader>
        <v-list-item
          v-for="item in group.items"
          :key="item.title"
          :to="item.to"
          :active="isItemActive(item.to)"
          :prepend-icon="item.icon"
          :title="item.title"
          class="pk-sidenav__item"
        />
      </template>
    </v-list>
  </v-navigation-drawer>
</template>

<style scoped>
.pk-sidenav {
  background: #fff !important;
  border-right: 1px solid var(--pk-line) !important;
}

.pk-sidenav__brand {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1.5rem 1.25rem 1.25rem;
}

.pk-sidenav__brand-text {
  font-family: var(--pk-font-display);
  font-weight: 700;
  font-size: 1.2rem;
  color: var(--pk-plana-navy);
  letter-spacing: 0.01em;
}

.pk-sidenav__list {
  padding: 0.5rem 0.75rem 1rem;
}

.pk-sidenav__assistant { display: flex; align-items: center; gap: 0.55rem; margin: 0 0.75rem 0.5rem; padding: 0.85rem 0.65rem; background: var(--pk-soft-blue); border-radius: 14px; color: var(--pk-plana-navy); text-decoration: none; }
.pk-sidenav__assistant strong { display: block; font-size: 0.875rem; }
.pk-sidenav__assistant small { display: block; margin-top: 0.15rem; font-size: 0.65rem; color: var(--pk-muted); }
.pk-sidenav__assistant:hover { outline: 1px solid var(--pk-steel); }

/* グループ見出し。項目より一段静かにし、右へ伸びる細線でグループの区切りを示す */
.pk-sidenav__group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-height: 0 !important;
  margin-top: 0.75rem;
  padding: 0.5rem 0.75rem 0.25rem !important;
  font-size: 0.72rem !important;
  font-weight: 700;
  letter-spacing: 0;
  color: var(--pk-muted) !important;
  opacity: 1 !important;
}

.pk-sidenav__group::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--pk-line);
}

.pk-sidenav__item {
  border-radius: 10px;
  color: var(--pk-muted) !important;
  min-height: 40px;
  margin-bottom: 3px;
}

.pk-sidenav__item :deep(.v-icon) {
  color: var(--pk-muted);
  transition: color 0.15s ease;
}

.pk-sidenav__item:hover {
  background: var(--pk-mist);
  color: var(--pk-steel) !important;
}

.pk-sidenav__item:hover :deep(.v-icon) {
  color: var(--pk-steel);
}

.pk-sidenav__item.v-list-item--active {
  background: var(--pk-soft-blue) !important;
  color: var(--pk-steel-dark) !important;
  font-weight: 700;
}

.pk-sidenav__item.v-list-item--active :deep(.v-icon) {
  color: var(--pk-steel);
}
</style>
