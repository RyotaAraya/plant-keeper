// プラナの提案を反映したあと、反映先の区画を見える位置に出し、区画の中の入力欄へフォーカスを移す。
// スマホ幅では反映先が提案の下にあり、押しても画面の外で変わるだけで、どこに入ったか分からないため。
// すでに見えているとき（PCで左右に並ぶとき）は動かさない（nearest）。
// 区画の上の余白は、呼び出し側の CSS の scroll-margin-top で決める（固定のヘッダーに隠れないように）
export function revealApplied(section: HTMLElement | null | undefined, fieldSelector: string) {
  if (!section) return
  section.scrollIntoView({ block: 'nearest' })
  section.querySelector<HTMLElement>(fieldSelector)?.focus({ preventScroll: true })
}
