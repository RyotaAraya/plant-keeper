import { test, expect, login, ACCOUNTS } from './support'

test('未ログインでダッシュボードを開くとログイン画面に移動する', async ({ page }) => {
  await page.goto('/dashboard')

  await expect(page).toHaveURL(/\/login/)
  await expect(page.getByRole('heading', { name: 'ログイン' })).toBeVisible()
})

test('パスワードが違うとエラーが表示され、ログインできない', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('メールアドレス').fill(ACCOUNTS.admin.email)
  await page.getByLabel('パスワード').fill('wrong-password')
  await page.getByRole('button', { name: 'ログイン', exact: true }).click()

  await expect(page.locator('.v-alert')).toContainText('メールアドレスまたはパスワードが正しくありません')
  await expect(page).toHaveURL(/\/login/)
})

test('ログイン → ダッシュボード表示 → ログアウトでログイン画面に戻り、再アクセスもできない', async ({ page }) => {
  await login(page, ACCOUNTS.logout)
  await expect(page.getByRole('heading', { level: 1, name: /ようこそ/ })).toBeVisible()

  // フロントがサーバー側の失効（DELETE /logout → 204）まで行っていること
  const logoutResponse = page.waitForResponse(
    (r) => r.url().endsWith('/api/v1/logout') && r.request().method() === 'DELETE',
  )
  await page.getByRole('button', { name: 'ログアウト' }).click()
  expect((await logoutResponse).status()).toBe(204)
  await expect(page).toHaveURL(/\/login/)

  await page.goto('/dashboard')
  await expect(page).toHaveURL(/\/login/)
})
