import { computed } from 'vue'
import { useAuthStore } from '@/stores/auth'

export function usePermissions() {
  const authStore = useAuthStore()

  const role = computed(() => authStore.user?.system_role)
  const companyType = computed(() => authStore.user?.company?.company_type)

  const isAdmin = computed(() => role.value === 'admin')
  const isOwnerManager = computed(() => role.value === 'manager' && companyType.value === 'owner')
  const isContractorManager = computed(() => role.value === 'manager' && companyType.value === 'contractor')
  const isOwnerCompany = computed(() => companyType.value === 'owner')
  const isWorker = computed(() => role.value === 'worker')

  // admin || owner_manager が共通パターン
  const canManageCore = computed(() => isAdmin.value || isOwnerManager.value)

  return {
    isAdmin,
    isOwnerManager,
    isOwnerCompany,
    isWorker,

    // SideNav 用
    canManageUsers: isAdmin,
    canViewAuditLogs: isAdmin,
    canAccessSettings: isAdmin,
    canManageOrders: canManageCore,
    canViewStocks: isOwnerCompany,
    canViewMaterials: computed(() => !isWorker.value),

    // 各ビュー内ボタン制御用
    canManageSite: isAdmin,
    canManageEquipment: canManageCore,
    canManageMaintenance: canManageCore,
    canManageEquipmentAssignment: canManageCore,
    canManageMaterial: canManageCore,
    canManageStockTransaction: canManageCore,
    canCreateTrouble: computed(() => !isWorker.value),
    canUpdateTrouble: computed(() => isAdmin.value || isOwnerManager.value || isContractorManager.value),
    canCreateTroubleResponse: computed(() => !isWorker.value),
  }
}
