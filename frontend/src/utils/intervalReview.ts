// 点検計画の周期の見直しの候補の表示
export const REVIEW_LABEL: Record<string, string> = { extend: '延長の候補', shorten: '短縮の候補' }
export const REVIEW_COLOR: Record<string, string> = { extend: 'success', shorten: 'warning' }
export const REVIEW_FILTER_OPTIONS = [
  { title: '見直しの候補あり', value: 'any' },
  { title: '延長の候補', value: 'extend' },
  { title: '短縮の候補', value: 'shorten' },
]
