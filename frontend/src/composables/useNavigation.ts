import { computed } from 'vue'
import { usePermissions } from '@/composables/usePermissions'

export function useNavigation() {
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

  // 日々の作業と、参照する台帳・組織設定を分ける。画面名と権限はヘッダーでも共用する。
  // 見出しは、見える項目が1つもないグループでは出さない（協力会社や一般ユーザ向けの整理）。
  const navGroups: NavGroup[] = [
    {
      items: [{ title: 'ダッシュボード', icon: 'mdi-view-dashboard-outline', to: '/dashboard' }],
    },
    {
      label: '日々の保全',
      items: [
        { title: '朝会・夕会ボード', icon: 'mdi-clipboard-text-clock-outline', to: '/meeting-board' },
        { title: '点検計画', icon: 'mdi-calendar-alert', to: '/inspection-plans' },
        { title: '点検・作業記録', icon: 'mdi-clipboard-check-outline', to: '/inspections' },
        { title: 'トラブル管理', icon: 'mdi-alert-circle-outline', to: '/troubles' },
        { title: 'インターロック', icon: 'mdi-shield-alert-outline', to: '/interlocks' },
        { title: '定期整備', icon: 'mdi-wrench-outline', to: '/maintenances' },
      ],
    },
    {
      label: '設備の台帳',
      items: [
        { title: '設備台帳', icon: 'mdi-factory', to: '/equipments' },
        { title: '装置・計器', icon: 'mdi-gauge', to: '/instruments' },
        { title: '基準器', icon: 'mdi-ruler-square', to: '/reference-standards' },
      ],
    },
    {
      label: '資材と調達',
      items: [
        { title: '資材管理', icon: 'mdi-package-variant', to: '/materials', permission: canViewMaterials },
        { title: '在庫管理', icon: 'mdi-warehouse', to: '/stocks', permission: canViewStocks },
        { title: '修理管理', icon: 'mdi-hammer-wrench', to: '/repairs', permission: canManageRepairs },
        { title: '発注管理', icon: 'mdi-cart-outline', to: '/orders', permission: canManageOrders },
      ],
    },
    {
      label: '組織と設定',
      items: [
        { title: '拠点管理', icon: 'mdi-domain', to: '/sites', permission: canViewSites },
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

  return { visibleGroups, items: computed(() => visibleGroups.value.flatMap((group) => group.items)) }
}
