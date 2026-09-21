// トラブル・点検の状態などの、画面に出す呼び方と色（一覧・詳細・履歴・類似トラブルで共有する。新しい画面でも、ここから import する）
export const troubleStatusLabel: Record<string, string> = { open: '未対応', in_progress: '対応中', deferred: '定修待ち', resolved: '解決済', closed: '完了' }
export const troubleStatusColor: Record<string, string> = { open: 'error', in_progress: 'warning', deferred: 'deep-purple', resolved: 'info', closed: 'success' }
export const priorityLabel: Record<string, string> = { low: '低', medium: '中', high: '高', critical: '緊急' }
export const priorityColor: Record<string, string> = { low: 'success', medium: 'info', high: 'warning', critical: 'error' }
export const inspectionTypeLabel: Record<string, string> = { routine: '日常点検', periodic: '定期点検', telemetry: 'テレメトリ', operation_check: '運転チェック' }
export const inspectionStatusLabel: Record<string, string> = { draft: '下書き', submitted: '提出済', approval_requested: '承認待ち', approved: '承認済' }
export const inspectionStatusColor: Record<string, string> = { draft: 'grey', submitted: 'info', approval_requested: 'warning', approved: 'success' }
