// ダイアログを閉じたとき、開いたボタンへフォーカスを戻す（アプリ全体で1か所。main.ts から1回だけ呼ぶ。#136）。
// Vuetify の v-dialog は、activator を使わず v-model だけで開くと、閉じたときにフォーカスを <body> に落とす。
// キーボード・読み上げで操作する人がページの先頭からたどり直さずに済むよう、ダイアログの外で最後にフォーカス（押下）した要素を覚えておき、
// ダイアログがすべて閉じてフォーカスが <body>（か閉じたダイアログの中）に残っていたら、そこへ戻す。
// - 画面のコードや Vuetify（activator のあるダイアログ）がフォーカスを移したときは、何もしない
// - 覚えた要素が画面から消えていたら（一覧の再取得で行のボタンが作り直された、など）、同じ data-testid の要素、
//   なければ同じ読み上げ名の同じ種類の要素のうち同じ順番のものへ。どちらもなければ画面の見出し（h1）へ
// - 保存と同時に画面を読み込み直すと、閉じた時点では戻し先がまだ無いことがある（詳細がスケルトンに置き換わる、など）。
//   そのときは戻し先が現れるまで待ち（RESTORE_WAIT_MS）、それでも無ければ見出しへ戻す
// - 戻したあとしばらく（RECREATE_WINDOW_MS）は、戻した要素が作り直されて消えたら、もう一度探して戻す。
//   見出しへ戻したあとに、本来の戻し先が現れたときも、そちらへ移す（保存後の再取得は閉じたあとに終わるため）
// - フォーカスできない場所（一覧の行など）を押して開いたときは、見出しへ戻す（前に押した関係のないボタンへ戻さない）
// - 別の画面に移っていたら戻さない（画面の移動は、ダイアログを閉じることとは別の話のため）

const OVERLAY = '.v-overlay-container'
const ACTIVE_DIALOG = '.v-dialog.v-overlay--active'
const FOCUSABLE = 'button, a[href], input, select, textarea, [role="button"], [tabindex]:not([tabindex="-1"])'
const RESTORE_WAIT_MS = 1000
const RECREATE_WINDOW_MS = 3000

interface Opener {
  el: HTMLElement
  path: string
  testid: string | null
  tag: string
  label: string
  index: number
}

const outsideOverlay = (el: Element) => !el.closest(OVERLAY)
const labelOf = (el: Element) => (el.getAttribute('aria-label') ?? el.textContent ?? '').replace(/\s+/g, ' ').trim()
const visible = (el: HTMLElement) => el.isConnected && el.getClientRects().length > 0
// フォーカスを戻せる要素（一覧の行の <tr> のように、押せてもフォーカスできないものは除く）
const focusable = (el: HTMLElement) => visible(el) && el.tabIndex >= 0

// 同じ種類・同じ読み上げ名の要素（ダイアログの外）。一覧の行の編集ボタンのように同じものが並ぶため、何番目かで見分ける
function sameLabelElements(tag: string, label: string): HTMLElement[] {
  return Array.from(document.querySelectorAll<HTMLElement>(tag))
    .filter((el) => outsideOverlay(el) && labelOf(el) === label)
}

// フォーカスできない要素（押した一覧の行など）は、戻し先の見出しを選ぶためだけに覚える（名前・順番は調べない。クリックのたびに全体を数えないため）
function remember(el: HTMLElement): Opener {
  const tag = el.tagName.toLowerCase()
  const label = el.tabIndex >= 0 ? labelOf(el) : ''
  return {
    el, tag, label,
    path: location.pathname,
    testid: el.tabIndex >= 0 ? el.getAttribute('data-testid') : null,
    index: label ? sameLabelElements(tag, label).indexOf(el) : -1,
  }
}

// 覚えた要素、作り直された同じ要素、画面の見出しの順に探す
function resolve(opener: Opener): { el: HTMLElement; fallback: boolean } | null {
  if (focusable(opener.el)) return { el: opener.el, fallback: false }
  if (opener.testid) {
    const same = Array.from(document.querySelectorAll<HTMLElement>(`[data-testid="${CSS.escape(opener.testid)}"]`)).find(outsideOverlay)
    if (same && focusable(same)) return { el: same, fallback: false }
  }
  if (opener.label && opener.index >= 0) {
    const same = sameLabelElements(opener.tag, opener.label)[opener.index]
    if (same && focusable(same)) return { el: same, fallback: false }
  }
  const heading = Array.from(document.querySelectorAll<HTMLElement>('h1')).find((h) => outsideOverlay(h) && visible(h))
  if (!heading) return null
  if (!heading.hasAttribute('tabindex')) heading.setAttribute('tabindex', '-1')
  return { el: heading, fallback: true }
}

// フォーカスがどこにもない（<body>）か、閉じたダイアログの中に残っている
function focusIsLost() {
  const active = document.activeElement
  return !active || active === document.body || !active.isConnected || !outsideOverlay(active)
}

let installed = false

export function installDialogFocusReturn() {
  if (installed || typeof document === 'undefined') return
  installed = true

  let opener: Opener | null = null
  let dialogOpen = false
  // 戻したあと、作り直されたら追いかける間の情報
  let restored: { opener: Opener; el: HTMLElement; fallback: boolean; until: number } | null = null

  const note = (el: Element | null) => {
    if (!(el instanceof HTMLElement) || el === document.body || !outsideOverlay(el)) return
    opener = remember(el)
  }
  // ボタンを押しただけではフォーカスが移らないブラウザ（Safari）があるため、押下でも覚える
  document.addEventListener('focusin', (e) => note(e.target as Element), true)
  document.addEventListener('pointerdown', (e) => {
    const target = e.target instanceof Element ? e.target : null
    if (!target || !outsideOverlay(target)) return
    note(target.closest(FOCUSABLE) ?? target)
  }, true)

  const focus = (opener: Opener, target: { el: HTMLElement; fallback: boolean }) => {
    target.el.focus({ preventScroll: target.fallback })
    restored = { opener, el: target.el, fallback: target.fallback, until: performance.now() + RECREATE_WINDOW_MS }
  }

  function restore() {
    const current = opener
    if (!current || current.path !== location.pathname) return
    const started = performance.now()
    const tick = () => {
      if (document.querySelector(ACTIVE_DIALOG) || current.path !== location.pathname) return // 別のダイアログが開いた・別の画面に移った
      const waiting = performance.now() - started < RESTORE_WAIT_MS
      // 画面のコード・Vuetify がフォーカスを移したときは、そのまま（閉じる動きの間はまだダイアログの中にあるため、少し待つ）
      if (!focusIsLost()) {
        if (waiting) requestAnimationFrame(tick)
        return
      }
      const target = resolve(current)
      if (target && !target.fallback) focus(current, target)
      else if (waiting) requestAnimationFrame(tick) // 戻し先がまだ描かれていない（読み込み直しの途中）
      else if (target) focus(current, target)
    }
    requestAnimationFrame(tick)
  }

  new MutationObserver(() => {
    const open = !!document.querySelector(ACTIVE_DIALOG)
    if (open && !dialogOpen) restored = null
    if (!open && dialogOpen) restore()
    dialogOpen = open

    // 戻した要素が、保存後の再取得などで作り直されて消えたら、もう一度探す。見出しへ戻したあとに本来の戻し先が現れたら、そちらへ
    if (restored && !open && performance.now() < restored.until && restored.opener.path === location.pathname) {
      const lost = !restored.el.isConnected && focusIsLost()
      const onFallback = restored.fallback && document.activeElement === restored.el
      if (lost || onFallback) {
        const target = resolve(restored.opener)
        if (target && (lost || !target.fallback)) focus(restored.opener, target)
      }
    }
  }).observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ['class'] })
}
