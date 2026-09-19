import { permissionsFor, type Permissions } from '@/composables/usePermissions'

// 権限マトリクス（トップページ・ログイン画面）の定義。
// 「できる/できない」は permissionsFor（メニューやボタンの出し分けと同じ判定）から求めるので、ここに直接は書かない

export interface MatrixRole {
  key: string
  groupLabel: string
  label: string
  // 列見出しの折り返し位置（狭い列で「システム管/理者」のように語の途中で折れないように、行ごとに指定する）
  labelLines: string[]
  role: string
  companyType: string
}

// 列。デモアカウントも、この5つの権限に1人ずつ用意している
export const MATRIX_ROLES: MatrixRole[] = [
  { key: 'owner:admin', groupLabel: '自社', label: 'システム管理者', labelLines: ['システム', '管理者'], role: 'admin', companyType: 'owner' },
  { key: 'owner:manager', groupLabel: '自社', label: '業務管理者', labelLines: ['業務管理者'], role: 'manager', companyType: 'owner' },
  { key: 'owner:member', groupLabel: '自社', label: '一般', labelLines: ['一般'], role: 'member', companyType: 'owner' },
  { key: 'contractor:manager', groupLabel: '協力会社', label: '業務管理者', labelLines: ['業務管理者'], role: 'manager', companyType: 'contractor' },
  { key: 'contractor:worker', groupLabel: '協力会社', label: '技能員', labelLines: ['技能員'], role: 'worker', companyType: 'contractor' },
]

export interface MatrixRow {
  label: string
  allowed: (p: Permissions) => boolean
}

export interface MatrixGroup {
  title: string
  rows: MatrixRow[]
}

export const MATRIX_GROUPS: MatrixGroup[] = [
  {
    title: '保全',
    rows: [
      { label: '設備・点検・トラブルの記録を見る', allowed: (p) => p.canViewRecords },
      { label: '点検を入力して提出する', allowed: (p) => p.canInputInspection },
      { label: '点検を承認・差し戻す', allowed: (p) => p.canApproveInspection },
      { label: 'トラブルを報告する', allowed: (p) => p.canCreateTrouble },
      { label: 'トラブルの状態・担当を更新する', allowed: (p) => p.canUpdateTrouble },
      { label: '設備・計器・点検計画・定期整備を登録する', allowed: (p) => p.canManageEquipment },
    ],
  },
  {
    title: '資材',
    rows: [
      { label: '資材を見る', allowed: (p) => p.canViewMaterials },
      { label: '在庫を見る', allowed: (p) => p.canViewStocks },
      { label: '資材の登録・入出庫を記録する', allowed: (p) => p.canManageStockTransaction },
      { label: '発注・修理を管理する', allowed: (p) => p.canManageOrders },
    ],
  },
  {
    title: '管理',
    rows: [{ label: '拠点・ユーザ・部署・監査ログ・設定を管理する', allowed: (p) => p.canManageUsers }],
  },
]

export function roleKeyOf(companyType: string | null | undefined, systemRole: string): string {
  return `${companyType ?? 'owner'}:${systemRole}`
}

export function isAllowed(row: MatrixRow, role: MatrixRole): boolean {
  return row.allowed(permissionsFor({ role: role.role, companyType: role.companyType }))
}
