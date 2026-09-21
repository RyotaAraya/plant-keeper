import { test as base, expect, type Page } from '@playwright/test'

// シードのデモアカウント（backend/db/seeds）
export const ACCOUNTS = {
  admin: { email: 'admin@example.com', password: 'password' },
  member: { email: 'sato@example.com', password: 'password' },
  // ログアウトするテスト専用（ログアウトの副作用を他のテストから切り離しておく）。
  // トークンは端末（ログイン）ごとに失効するため、他のテストと共有しても巻き込みはしない
  logout: { email: 'suzuki@example.com', password: 'password' },
}

// バックエンドAPIのURL。E2E_API_URL で指定するか、画面のURL（E2E_BASE_URL）から推定する（stg。ローカル/CIは :3000）
export function apiBaseUrl(): string {
  if (process.env.E2E_API_URL) return process.env.E2E_API_URL
  if ((process.env.E2E_BASE_URL ?? '').includes('plant-keeper-web-stg')) return 'https://plant-keeper-api-stg.onrender.com/api/v1'
  return 'http://localhost:3000/api/v1'
}

// 別のアカウントでログインし直す前に、保存済みのトークンを消す。
// アプリを起動しない静的ファイルのページで消すこと（`/login` を開いてから消すと、トークンが残ったままアプリが
// ダッシュボードへ移って取得を始め、消した直後にトークンなしの401になり、未捕捉の例外として検出される）
export async function resetSession(page: Page) {
  await page.context().clearCookies()
  await page.goto('/vite.svg')
  await page.evaluate(() => localStorage.clear())
}

export async function login(page: Page, account: { email: string; password: string }) {
  await page.goto('/login')
  await page.getByLabel('メールアドレス').fill(account.email)
  await page.getByLabel('パスワード').fill(account.password)
  await page.getByRole('button', { name: 'ログイン', exact: true }).click()
  await expect(page).toHaveURL(/\/dashboard/)
}

// Vuetifyのv-selectは入力要素が別要素に覆われていて直接クリックできないため、入力欄（.v-field）を操作して先頭の選択肢を選ぶ
// 選択肢を選んだあと、Escapeでメニューを閉じる（複数選択のメニューは、選んでも開いたままで、次の操作を邪魔するため。
// 単一選択では既に閉じていて、何も起きない）
export async function selectFirstOption(page: Page, label: string) {
  await page.locator('.v-field', { has: page.getByLabel(label, { exact: true }) }).click()
  await page.getByRole('option').first().click()
  await page.keyboard.press('Escape')
}

// exact: 選択肢の名前が、ほかの選択肢の名前に含まれるとき（「巡回点検」と「根岸 巡回点検」など）は true にする
export async function selectOption(page: Page, label: string, optionName: string, { exact = false } = {}) {
  await page.locator('.v-field', { has: page.getByLabel(label, { exact: true }) }).click()
  await page.getByRole('option', { name: optionName, exact }).click()
  await page.keyboard.press('Escape')
}

// トラブル管理の先頭行から詳細画面を開く。一覧は初期表示の再取得で行が差し替わることがあり、
// クリックが空振りしうるため、詳細画面に遷移するまでクリックをリトライする。
// 「詳細画面に到達していないのに、ボタンがないことの確認だけ通る」状態を防ぐため、到達も検証する
// 一覧（ページ分けされた表）から、名前に title を含む行を探して開く。繰り返し実行して「E2E 」の行が溜まっても、後ろのページまで探す。
// 作成直後は一覧の再取得が終わるまで行が出ないため、最初のページから探し直しながら待つ
export async function openListRow(page: Page, title: string) {
  const row = page.getByRole('row', { name: new RegExp(title) })
  const first = page.getByRole('button', { name: '最初のページ' })
  const next = page.getByRole('button', { name: '次のページ' })
  await expect(async () => {
    await page.locator('tbody tr.v-data-table__tr').first().waitFor({ timeout: 2000 }) // 読み込み中は次のページのボタンが無効なため、行が出るのを待つ
    if (await first.isEnabled()) await first.click()
    for (let i = 0; i < 100 && !(await row.isVisible()) && (await next.isEnabled()); i++) await next.click()
    await expect(row).toBeVisible({ timeout: 1000 })
  }).toPass({ timeout: 20_000 })
  // 行の端を押す（行の中には、計器の詳細へのリンクなどがあり、中央を押すとそちらに当たることがある）
  await row.click({ position: { x: 8, y: 8 } })
}

export async function openFirstTrouble(page: Page) {
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await expect(async () => {
    // 行の中の計器へのリンクを押して別の画面に移ってしまうことがあるため、行の端を押し、移ってしまったら一覧に戻る
    if (!/\/troubles(\/|$)/.test(page.url())) await page.goto('/troubles')
    await page.locator('tbody tr').first().click({ position: { x: 8, y: 8 } })
    await expect(page).toHaveURL(/\/troubles\/\d+/, { timeout: 2_000 })
  }).toPass({ timeout: 15_000 })
  await expect(page.getByRole('heading', { level: 1 })).not.toHaveText('トラブル管理')
}

// 全テスト共通: 未捕捉のJS例外・APIの5xxが出ていないことを保証する
// （依存更新でフロントが壊れたときに、画面の見た目の確認だけでは気づけない不具合を拾う）
export const test = base.extend<{ runtimeGuard: void }>({
  runtimeGuard: [
    async ({ page }, use) => {
      const problems: string[] = []
      page.on('pageerror', (e) => problems.push(`JS例外: ${e.message}`))
      page.on('response', (r) => {
        if (r.url().includes('/api/v1/') && r.status() >= 500) {
          problems.push(`API ${r.status()}: ${r.request().method()} ${r.url()}`)
        }
      })
      await use()
      expect(problems, '画面操作中にJS例外またはAPI 5xxが発生').toEqual([])
    },
    { auto: true },
  ],
})

// AI支援のE2Eは、本物のAPIを呼ばない: バックエンドが AI_PROVIDER=fake（APIを呼ばないダミー）のときだけ実行し、
// 本物のAI（キーあり。stg など）や無効（キーなし）ではスキップする。provider は /ai/status の値。
// CI は fake で起動するため実行する（fake でなければ、AIの画面が検証されないまま黙ってスキップされないよう、失敗にする）
export function requireFakeAi(provider: string | null | undefined) {
  if (provider === 'fake') return
  expect(process.env.CI, 'CIでは、バックエンドを AI_PROVIDER=fake で起動する').toBeFalsy()
  test.skip(true, `本物のAIは呼ばない（バックエンドが AI_PROVIDER=fake のときだけ実行する。いまは ${provider ?? '無効'}）`)
}

export { expect }
