import { computed, type ComputedRef } from 'vue'
import { useAuthStore } from '@/stores/auth'

export interface RoleContext {
  role?: string | null
  companyType?: string | null
}

// 役割（system_role）と会社種別から、使える機能を決める。バックエンドの Pundit ポリシーに対応する。
// メニュー・ボタンの出し分け（usePermissions）と、権限マトリクスの表示（PermissionMatrix）が
// 同じ判定を使うことで、画面の説明と実際の挙動が食い違わないようにする
export function permissionsFor({ role, companyType }: RoleContext) {
  const isAdmin = role === 'admin'
  const isManager = role === 'manager'
  const isWorker = role === 'worker'
  const isOwnerCompany = companyType === 'owner'
  const isOwnerManager = isManager && isOwnerCompany
  const isContractorManager = isManager && companyType === 'contractor'

  // admin || owner_manager が共通パターン
  const canManageCore = isAdmin || isOwnerManager

  return {
    isAdmin,
    isManager,
    isOwnerManager,
    isOwnerCompany,
    isWorker,

    // 全員（ログインしていれば誰でも）
    canViewRecords: true,
    canInputInspection: true,

    // SideNav 用
    canManageUsers: isAdmin,
    canViewAuditLogs: isAdmin,
    canAccessSettings: isAdmin,
    canManageOrders: canManageCore,
    canManageRepairs: canManageCore,
    canViewStocks: isOwnerCompany,
    canViewMaterials: !isWorker,

    // 各ビュー内ボタン制御用
    canManageSite: isAdmin,
    canManageEquipment: canManageCore,
    canManageInspectionPlan: canManageCore,
    // バックエンドの InspectionPolicy#approve? に対応（承認・差し戻しは管理者/マネージャー）
    canApproveInspection: isAdmin || isManager,
    canManageMaintenance: canManageCore,
    canManageEquipmentAssignment: canManageCore,
    canManageMaterial: canManageCore,
    canManageStockTransaction: canManageCore,
    canCreateTrouble: !isWorker,
    canUpdateTrouble: isAdmin || isOwnerManager || isContractorManager,
    canCreateTroubleResponse: !isWorker,
  }
}

export type Permissions = ReturnType<typeof permissionsFor>

export function usePermissions() {
  const authStore = useAuthStore()

  const current = computed(() =>
    permissionsFor({
      role: authStore.user?.system_role,
      companyType: authStore.user?.company?.company_type,
    })
  )

  return Object.fromEntries(
    (Object.keys(current.value) as (keyof Permissions)[]).map((key) => [key, computed(() => current.value[key])])
  ) as { [K in keyof Permissions]: ComputedRef<Permissions[K]> }
}
