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

test('トークンが期限切れ・失効していると、ログイン画面に戻り、その旨が表示される', async ({ page }) => {
  await login(page, ACCOUNTS.member)

  // 24時間の有効期限が切れた状態を、無効なトークンで再現する
  await page.evaluate(() => localStorage.setItem('jwt', 'invalid.token.value'))
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()

  await expect(page).toHaveURL(/\/login\?expired=1/)
  await expect(page.getByText('有効期限が切れました')).toBeVisible()
  expect(await page.evaluate(() => localStorage.getItem('jwt'))).toBeNull()
})

test('同じユーザが2つの端末でログインでき、片方でログアウトしても他方は使い続けられる', async ({ browser }) => {
  const pc = await (await browser.newContext()).newPage()
  const tablet = await (await browser.newContext()).newPage()
  await login(pc, ACCOUNTS.member)
  await login(tablet, ACCOUNTS.member)

  await pc.getByRole('button', { name: 'ログアウト' }).click()
  await expect(pc).toHaveURL(/\/login/)

  // 別端末のセッションは生きている（再読み込みしてもログインしたまま）
  await tablet.reload()
  await expect(tablet.getByRole('heading', { level: 1, name: /ようこそ/ })).toBeVisible()

  await pc.context().close()
  await tablet.context().close()
})
