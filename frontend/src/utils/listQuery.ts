// ダッシュボードなどから一覧を開くときに、拠点や絞り込みをURLのクエリで渡すための変換。
// 拠点は `site_ids=1,2`、全拠点は `site_ids=all`（クエリなしは、一覧の既定＝自拠点）。ステータスなどは `status=open,in_progress`

export function siteIdsToQuery(ids: number[]): string {
  return ids.length ? ids.join(',') : 'all'
}

export function siteIdsFromQuery(value: unknown, fallback: number[]): number[] {
  if (typeof value !== 'string' || !value) return fallback
  if (value === 'all') return []
  const ids = value.split(',').map(Number).filter((n) => Number.isInteger(n) && n > 0)
  return ids.length ? ids : fallback
}

export function listFromQuery(value: unknown): string[] {
  return typeof value === 'string' ? value.split(',').filter(Boolean) : []
}
