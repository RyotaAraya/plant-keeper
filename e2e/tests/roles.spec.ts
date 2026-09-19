import { test, expect, login, openFirstTrouble } from './support'

// ロール（自社/協力会社 × マネージャー/作業員）ごとのメニューと操作ボタンの出し分け。
// フロントの権限判定はログインAPIが返す user.company に依存する（バックエンドの Pundit と対応）
const ACCOUNTS = {
  ownerManager: { email: 'yamamoto@example.com', password: 'password' },
  contractorManager: { email: 'yoshida@example.com', password: 'password' },
  contractorWorker: { email: 'honda@example.com', password: 'password' },
}

test('自社のマネージャーは管理系メニューと操作ボタンが使える', async ({ page }) => {
  await login(page, ACCOUNTS.ownerManager)

  for (const [menu, heading] of [
    ['在庫管理', '在庫管理'],
    ['修理管理', '修理管理'],
    ['発注管理', '発注管理'],
  ]) {
    await page.getByRole('link', { name: menu, exact: true }).click()
    await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible()
  }

  await page.getByRole('link', { name: '設備台帳', exact: true }).click()
  await expect(page.getByRole('button', { name: '新規作成' })).toBeVisible()

  await openFirstTrouble(page)
  await expect(page.getByRole('button', { name: '編集' })).toBeVisible()
})

test('協力会社のマネージャーは自社限定メニューが使えず、トラブルの編集だけができる', async ({ page }) => {
  await login(page, ACCOUNTS.contractorManager)

  for (const menu of ['在庫管理', '修理管理', '発注管理']) {
    await expect(page.getByRole('link', { name: menu, exact: true })).toHaveCount(0)
  }

  await page.getByRole('link', { name: '設備台帳', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '設備台帳' })).toBeVisible()
  await expect(page.getByRole('button', { name: '新規作成' })).toHaveCount(0)

  await openFirstTrouble(page)
  await expect(page.getByRole('button', { name: '編集' })).toBeVisible()
})

test('協力会社の作業員は資材管理が使えず、トラブルの編集もできない', async ({ page }) => {
  await login(page, ACCOUNTS.contractorWorker)

  await expect(page.getByRole('link', { name: '資材管理', exact: true })).toHaveCount(0)

  await openFirstTrouble(page)
  await expect(page.getByRole('button', { name: '対応記録' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: '編集' })).toHaveCount(0)
})
