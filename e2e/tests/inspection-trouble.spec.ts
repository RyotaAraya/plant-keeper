import { test, expect, login, selectFirstOption, ACCOUNTS } from './support'

// 保全の主要フロー: 点検で不具合を報告 → トラブル管理に自動で登録される
test('点検で不具合を報告すると、トラブル管理に登録される', async ({ page }) => {
  const title = `E2E ${Date.now()} 指示値のふらつき`
  await login(page, ACCOUNTS.member)

  await page.goto('/inspections/new')
  await expect(page.getByRole('heading', { level: 1, name: '新規点検記録' })).toBeVisible()

  await selectFirstOption(page, '設備 *')
  await selectFirstOption(page, '部署 *')

  await page.getByRole('button', { name: '項目追加' }).click()
  await page.getByLabel('内容', { exact: true }).fill('圧力指示値の確認')
  await page.getByRole('checkbox', { name: '不具合あり' }).check()
  await page.getByLabel('トラブルタイトル').fill(title)

  await page.getByRole('button', { name: '提出' }).click()
  await expect(page).toHaveURL(/\/inspections$/)

  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await page.getByRole('textbox', { name: 'タイトル検索' }).fill(title)
  await expect(page.getByRole('row', { name: new RegExp(title) })).toBeVisible()
})
