<script setup lang="ts">
defineProps<{
  modelValue: boolean
}>()

defineEmits<{
  'update:modelValue': [value: boolean]
}>()

const navItems = [
  { title: 'ダッシュボード', icon: 'mdi-view-dashboard', to: '/' },
  { title: '拠点管理', icon: 'mdi-domain', to: '/sites' },
  { title: '設備台帳', icon: 'mdi-factory', to: '/equipments' },
  { title: '装置・計器', icon: 'mdi-gauge', to: '/instruments' },
  { title: '点検・作業記録', icon: 'mdi-clipboard-check', to: '/' },
  { title: 'トラブル管理', icon: 'mdi-alert-circle', to: '/' },
  { title: '定期整備', icon: 'mdi-wrench', to: '/' },
  { title: '資材管理', icon: 'mdi-package-variant', to: '/' },
  { title: '在庫管理', icon: 'mdi-warehouse', to: '/' },
  { title: '発注管理', icon: 'mdi-cart', to: '/' },
  { title: 'ユーザ管理', icon: 'mdi-account-group', to: '/' },
  { title: '監査ログ', icon: 'mdi-file-document', to: '/' },
  { title: '設定', icon: 'mdi-cog', to: '/settings' },
]
</script>

<template>
  <v-navigation-drawer
    :model-value="modelValue"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <v-list nav dense>
      <v-list-item
        v-for="item in navItems"
        :key="item.title"
        :to="item.to"
        :prepend-icon="item.icon"
        :title="item.title"
      />
    </v-list>
  </v-navigation-drawer>
</template>
