// 法規区分の色（区分コード → Vuetify の色）。一覧でひと目で区別できるよう、区分ごとに固定する。
// 期限の状態（赤=超過・橙=間近・緑=余裕）と紛れないよう、赤・緑は使わない
const REGULATION_COLORS: Record<string, string> = {
  high_pressure_gas: 'deep-purple',
  boiler_pressure_vessel: 'deep-orange',
  electricity: 'blue',
  fire_service: 'teal',
  measurement_law: 'brown',
}

export function regulationColor(code: string | undefined): string {
  return (code && REGULATION_COLORS[code]) || 'grey'
}
