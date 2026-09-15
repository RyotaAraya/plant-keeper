<script setup lang="ts">
import { computed } from 'vue'
import { usePermissions } from '@/composables/usePermissions'

defineProps<{
  modelValue: boolean
}>()

defineEmits<{
  'update:modelValue': [value: boolean]
}>()

const { canManageUsers, canViewAuditLogs, canAccessSettings, canManageOrders, canViewStocks, canViewMaterials } =
  usePermissions()

const navItems = [
  { title: 'ダッシュボード', icon: 'mdi-view-dashboard-outline', to: '/dashboard' },
  { title: '拠点管理', icon: 'mdi-domain', to: '/sites' },
  { title: '設備台帳', icon: 'mdi-factory', to: '/equipments' },
  { title: '装置・計器', icon: 'mdi-gauge', to: '/instruments' },
  { title: '点検・作業記録', icon: 'mdi-clipboard-check-outline', to: '/inspections' },
  { title: 'トラブル管理', icon: 'mdi-alert-circle-outline', to: '/troubles' },
  { title: '定期整備', icon: 'mdi-wrench-outline', to: '/maintenances' },
  { title: '資材管理', icon: 'mdi-package-variant', to: '/materials', permission: canViewMaterials },
  { title: '在庫管理', icon: 'mdi-warehouse', to: '/stocks', permission: canViewStocks },
  { title: '発注管理', icon: 'mdi-cart-outline', to: '/orders', permission: canManageOrders },
  { title: '部署管理', icon: 'mdi-office-building-outline', to: '/departments', permission: canManageUsers },
  { title: 'ユーザ管理', icon: 'mdi-account-group-outline', to: '/users', permission: canManageUsers },
  { title: '監査ログ', icon: 'mdi-file-document-outline', to: '/audit-logs', permission: canViewAuditLogs },
  { title: '設定', icon: 'mdi-cog-outline', to: '/settings', permission: canAccessSettings },
]

const filteredNavItems = computed(() => navItems.filter((item) => !item.permission || item.permission.value))
</script>

<template>
  <v-navigation-drawer
    :model-value="modelValue"
    permanent
    class="pk-sidenav"
    width="248"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="pk-sidenav__brand">
      <v-icon size="20" color="#E7B778">mdi-gauge-full</v-icon>
      <span class="pk-sidenav__brand-text">PlantKeeper</span>
    </div>
    <v-list nav class="pk-sidenav__list">
      <v-list-item
        v-for="item in filteredNavItems"
        :key="item.title"
        :to="item.to"
        :prepend-icon="item.icon"
        :title="item.title"
        class="pk-sidenav__item"
      />
    </v-list>
  </v-navigation-drawer>
</template>

<style scoped>
.pk-sidenav {
  background: var(--pk-ink) !important;
  border-right: none !important;
}

.pk-sidenav__brand {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1.25rem 1rem 1rem;
}

.pk-sidenav__brand-text {
  font-family: var(--pk-font-display);
  font-weight: 700;
  font-size: 1.05rem;
  color: #f2f4f3;
  letter-spacing: 0.01em;
}

.pk-sidenav__list {
  padding: 0.5rem 0.5rem;
}

.pk-sidenav__item {
  border-radius: 0;
  border-left: 2px solid transparent;
  color: #aab4b8 !important;
  min-height: 42px;
  margin-bottom: 2px;
}

.pk-sidenav__item :deep(.v-icon) {
  color: #7f8c91;
  transition: color 0.15s ease;
}

.pk-sidenav__item:hover {
  background: rgba(255, 255, 255, 0.04);
  color: #f2f4f3 !important;
}

.pk-sidenav__item:hover :deep(.v-icon) {
  color: #cfd6d8;
}

.pk-sidenav__item.v-list-item--active {
  background: rgba(255, 255, 255, 0.06) !important;
  border-left-color: #e7b778;
  color: #f2f4f3 !important;
}

.pk-sidenav__item.v-list-item--active :deep(.v-icon) {
  color: #e7b778;
}
</style>
