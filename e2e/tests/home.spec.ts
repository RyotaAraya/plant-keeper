import { test, expect } from './support'

// トップページ: ヒーローで「何のシステムか」を説明し、直下にプラナ（AIアシスタント）の帯、「主な機能」は
// 設備から発注までの流れ → 保全管理・資材管理・組織管理・プラナの提案（プラナは主役ではなく、業務機能を呼び出せる助手）。
// スマホで横にはみ出さないこと
test('ヒーローは、何を一元管理するシステムかを説明し、その下にプラナの帯が続く', async ({ page }) => {
  await page.goto('/')
  const hero = page.locator('.pk-hero')
  await expect(hero).toContainText('設備保全に必要な情報を、ひとつの場所へ。')
  await expect(hero).toContainText('設備・点検・トラブル・修理・資材・在庫・発注まで、保全業務に必要な情報を一元管理します。')

  // プラナの帯はヒーローより下（PlantKeeperの説明が先）
  const heroBox = await hero.boundingBox()
  const planaBox = await page.locator('#plana').boundingBox()
  expect(planaBox!.y).toBeGreaterThanOrEqual(heroBox!.y + heroBox!.height - 1)
  await expect(page.locator('#plana')).toContainText('過去の記録から、次の判断をサポート。')
})

test('主な機能の頭に、設備から発注までの業務の流れが並ぶ', async ({ page }) => {
  await page.goto('/')
  await expect(page.locator('.pk-flow__step .pk-flow__name')).toHaveText(['設備', '点検', 'トラブル', '修理', '資材', '在庫', '発注'])
})

test('トップページの主な機能に、保全管理・資材管理・組織管理に続けて、プラナの提案が載っている', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('PlantKeeper')

  await expect(page.locator('.pk-feature-row h3')).toHaveText(['保全管理', '資材管理', '組織管理', 'プラナの提案'])
  const ai = page.locator('.pk-feature-row', { has: page.getByRole('heading', { name: 'プラナの提案' }) })
  await expect(ai).toContainText('応急処置の手順や、運転を続けてよいかの判断は出しません')
  await expect(ai.getByRole('img')).toHaveAttribute('alt', /AIの下書き/)
})

test('ヒーローの「プラナ AI」を押すと、すぐ下のプラナの帯に移る', async ({ page }) => {
  await page.goto('/')
  await page.locator('.pk-hero__ai').click()

  await expect(page.locator('#plana')).toBeInViewport()
  await expect(page.locator('#plana').getByRole('heading', { name: 'プラナ AI' })).toBeVisible()
})

test('ログイン前は、プラナの相談欄に入れて送るとログイン画面へ移る（案内も出ている）', async ({ page }) => {
  await page.goto('/')
  const plana = page.locator('#plana')
  await expect(plana).toContainText('プラナはログイン後に使えます')

  await plana.getByLabel('プラナに相談する').fill('PT-100の過去のトラブルを教えてください')
  await plana.getByRole('button', { name: '相談する' }).click()

  await expect(page).toHaveURL(/\/login$/)
})

test('トップページは、スマホの幅でも横にはみ出さない', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()

  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)
  expect(overflow).toBe(0)
})
