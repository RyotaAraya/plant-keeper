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

  for (const path of ['/equipments', '/inspections/new', '/plana', '/home', '/plans']) {
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

// スマホ（600px 以下）以外では、メニューは開いた状態で始まる（Vuetify の既定だと 1280px 未満でも閉じてしまう）
test.describe('タブレット・小さめのノートPCの幅', () => {
  for (const width of [768, 1024]) {
    test(`${width}px 幅では、メニューが開いた状態で始まる`, async ({ page }) => {
      await page.setViewportSize({ width, height: 800 })
      await login(page, ACCOUNTS.admin)
      await expect(page.getByRole('link', { name: '設備台帳', exact: true })).toBeInViewport()
    })
  }
})
