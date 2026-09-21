// 公開トップとプラナの作業入口で共用する、実装済みの仕事。
// できることを増やすとき（設備の履歴の要約・マニュアル検索など）は、ここに足す。
// 実装済みのものだけを載せる（できないことは載せない）
export interface PlanaCapability {
  key: string
  title: string
  summary: string
  // プラナの作業ホームで、この仕事を選ぶ入口
  to: string
  icon: string
}

export const planaCapabilities: PlanaCapability[] = [
  {
    key: 'defect-draft',
    title: '不具合報告の下書き',
    summary: '点検中のメモから、トラブル報告の下書きを作成します。',
    to: '/plana?task=defect-draft',
    icon: 'mdi-clipboard-edit-outline',
  },
  {
    key: 'similar-troubles',
    title: '過去の類似トラブル',
    summary: '現在の症状に似た過去のトラブルと対応履歴を探します。',
    to: '/plana?task=similar-troubles',
    icon: 'mdi-history',
  },
  {
    key: 'response-draft',
    title: '対応記録の下書き',
    summary: '対応内容のメモをもとに、対応記録の下書きを作成します。',
    to: '/plana?task=response-draft',
    icon: 'mdi-text-box-edit-outline',
  },
]
