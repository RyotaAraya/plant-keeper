// 点検周期（日数）を、現場の言い方（1か月・1年・4年など）で表示する。区切りのよい日数だけ言い換え、それ以外は「N日」
export function intervalLabel(days: number): string {
  if (days >= 365 && days % 365 === 0) return `${days / 365}年`
  if (days >= 30 && days % 30 === 0 && days < 365) return `${days / 30}か月`
  if (days >= 7 && days % 7 === 0 && days < 30) return `${days / 7}週間`
  return `${days}日`
}
