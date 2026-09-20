import { test, expect } from './support'

// トップページ: 「主な機能」の4つ目にAI支援が並ぶ（主役ではなく、機能の1つ）。スマホで横にはみ出さないこと
test('トップページの主な機能に、保全管理・資材管理・組織管理に続けて、AI支援が載っている', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('PlantKeeper')

  await expect(page.locator('.pk-feature-row h3')).toHaveText(['保全管理', '資材管理', '組織管理', 'AI支援'])
  const ai = page.locator('.pk-feature-row', { has: page.getByRole('heading', { name: 'AI支援' }) })
  await expect(ai).toContainText('応急処置の手順や、運転を続けてよいかの判断は出しません')
  await expect(ai.getByRole('img')).toHaveAttribute('alt', /AIの下書き/)
})

test('ヒーローの「AI支援」を押すと、機能の並びのAI支援の行に移る', async ({ page }) => {
  await page.goto('/')
  await page.locator('.pk-hero__ai').click()

  await expect(page.locator('#ai')).toBeInViewport()
  await expect(page.locator('#ai').getByRole('heading', { name: 'AI支援' })).toBeVisible()
})

test('トップページは、スマホの幅でも横にはみ出さない', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()

  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)
  expect(overflow).toBe(0)
})
