import { test as base, expect, type Page } from '@playwright/test'

// シードのデモアカウント（backend/db/seeds）
export const ACCOUNTS = {
  admin: { email: 'admin@example.com', password: 'password' },
  member: { email: 'sato@example.com', password: 'password' },
  // ログアウトするテスト専用。ログアウトするとそのユーザーの全セッションが失効する（JTIMatcher）ため、
  // 他のテストと共有すると並列実行時に巻き込んでしまう
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
