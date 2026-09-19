import { test as base, expect, type Page } from '@playwright/test'

// シードのデモアカウント（backend/db/seeds）
export const ACCOUNTS = {
  admin: { email: 'admin@example.com', password: 'password' },
  member: { email: 'sato@example.com', password: 'password' },
  // ログアウトするテスト専用（ログアウトの副作用を他のテストから切り離しておく）。
  // トークンは端末（ログイン）ごとに失効するため、他のテストと共有しても巻き込みはしない
  logout: { email: 'suzuki@example.com', password: 'password' },
}

export async function login(page: Page, account: { email: string; password: string }) {
  await page.goto('/login')
  await page.getByLabel('メールアドレス').fill(account.email)
  await page.getByLabel('パスワード').fill(account.password)
  await page.getByRole('button', { name: 'ログイン', exact: true }).click()
  await expect(page).toHaveURL(/\/dashboard/)
}

// Vuetifyのv-selectは入力要素が別要素に覆われていて直接クリックできないため、入力欄（.v-field）を操作して先頭の選択肢を選ぶ
export async function selectFirstOption(page: Page, label: string) {
  await page.locator('.v-field', { has: page.getByLabel(label, { exact: true }) }).click()
  await page.getByRole('option').first().click()
}

// トラブル管理の先頭行から詳細画面を開く。一覧は初期表示の再取得で行が差し替わることがあり、
// クリックが空振りしうるため、詳細画面に遷移するまでクリックをリトライする。
// 「詳細画面に到達していないのに、ボタンがないことの確認だけ通る」状態を防ぐため、到達も検証する
export async function openFirstTrouble(page: Page) {
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await expect(async () => {
    await page.locator('tbody tr').first().click()
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

export { expect }
