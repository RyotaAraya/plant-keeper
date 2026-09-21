// プラナ（AIアシスタント）ができること。専用ページ（/plana）が読む。説明は「〜を作成します」「〜を探します」の言い回しにそろえる。
// できることを増やすとき（設備の履歴の要約・マニュアル検索など）は、ここに足す。
// 実装済みのものだけを載せる（できないことは載せない）
export interface PlanaCapability {
  key: string
  title: string
  summary: string
  // 使う場所への入口（プラナは各画面の中で呼び出す）
  to: string
  linkLabel: string
  icon: string
}

export const planaCapabilities: PlanaCapability[] = [
  {
    key: 'defect-draft',
    title: '不具合報告の下書き',
    summary: '点検中のメモから、トラブル報告の下書きを作成します。',
    to: '/inspections/new',
    linkLabel: '点検を入力する',
    icon: 'mdi-clipboard-edit-outline',
  },
  {
    key: 'similar-troubles',
    title: '過去の類似トラブル',
    summary: '現在の症状に似た過去のトラブルと対応履歴を探します。',
    to: '/troubles',
    linkLabel: 'トラブル管理を開く',
    icon: 'mdi-history',
  },
  {
    key: 'response-draft',
    title: '対応記録の下書き',
    summary: '対応内容のメモをもとに、対応記録の下書きを作成します。',
    to: '/troubles',
    linkLabel: 'トラブル管理を開く',
    icon: 'mdi-text-box-edit-outline',
  },
]
