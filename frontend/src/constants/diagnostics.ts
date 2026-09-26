// 機器の自己診断（NAMUR NE 107）の状態の呼び方・記号・色・アイコン（計器の一覧・詳細、外部連携の画面で共用）。
// 色は NE 107 の慣例に合わせる（故障=赤、機能点検中=橙、仕様外=黄、保守要求=青）。バックエンドは InstrumentDiagnostic::STATUSES
export type DiagnosticStatus = 'good' | 'failure' | 'function_check' | 'out_of_specification' | 'maintenance_required'

export const DIAGNOSTIC_STATUS: Record<DiagnosticStatus, { label: string; letter: string; color: string; icon: string; hint: string }> = {
  failure: { label: '故障', letter: 'F', color: 'error', icon: 'mdi-close-octagon', hint: '機器が故障を検出。測定値・出力は信頼できない' },
  function_check: { label: '機能点検中', letter: 'C', color: 'deep-orange', icon: 'mdi-progress-wrench', hint: '点検・校正・手動操作などの作業中。一時的に出力が正しくない' },
  out_of_specification: { label: '仕様外', letter: 'S', color: 'amber-darken-2', icon: 'mdi-help-rhombus', hint: '仕様の範囲の外で動いている。測定値が不確かな可能性' },
  maintenance_required: { label: '保守要求', letter: 'M', color: 'blue', icon: 'mdi-oil', hint: 'まだ測定はできるが、保守（校正・清掃・交換など）が必要' },
  good: { label: '正常', letter: 'N', color: 'success', icon: 'mdi-check-circle-outline', hint: '異常は検出されていない' },
}

// 絞り込みの選択肢（異常の重い順。未受信は、機器管理システムから一度も受け取っていない計器）
export const DIAGNOSTIC_FILTER_OPTIONS = [
  ...(['failure', 'function_check', 'out_of_specification', 'maintenance_required', 'good'] as DiagnosticStatus[])
    .map((value) => ({ title: `${DIAGNOSTIC_STATUS[value].letter} ${DIAGNOSTIC_STATUS[value].label}`, value })),
  { title: '未受信', value: 'none' },
]
