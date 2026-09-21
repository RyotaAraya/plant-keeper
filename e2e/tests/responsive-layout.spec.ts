import { test, expect, login, ACCOUNTS } from './support'

test.use({ viewport: { width: 390, height: 844 } })

test('スマホではメニューを開いて画面を選ぶと閉じ、一覧と入力画面が画面幅に収まる', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  const equipmentLink = page.getByRole('link', { name: '設備台帳', exact: true })
  await expect(equipmentLink).not.toBeInViewport()
  await page.getByRole('button', { name: 'メニューを開閉' }).click()
  await equipmentLink.click()
  await expect(page.getByRole('heading', { level: 1, name: '設備台帳' })).toBeVisible()
  await expect(equipmentLink).not.toBeInViewport()

  for (const path of ['/equipments', '/inspections/new', '/plana', '/dashboard']) {
    await page.goto(path)
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    expect(await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)).toBe(0)
  }
})

test('スマホの一覧から作成ダイアログを開いて閉じられる', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.goto('/equipments')
  await page.getByRole('button', { name: '新規作成' }).click()
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByLabel('設備名')).toBeVisible()
  await expect(dialog.getByRole('button', { name: '保存', exact: true })).toBeVisible()
  await dialog.getByRole('button', { name: 'キャンセル' }).click()
  await expect(dialog).not.toBeVisible()
})
