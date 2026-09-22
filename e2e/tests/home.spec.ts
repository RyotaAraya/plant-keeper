import { test, expect } from './support'

// 公開トップは、プラナで始められる実在の仕事を先に示し、その土台として
// PlantKeeperの保全管理機能と権限を説明する。回答しない相談欄は置かない。
test('ヒーローは現場メモから記録へ進む流れと、確認が必要な表示例を示す', async ({ page }) => {
  await page.goto('/')

  const hero = page.locator('.landing-hero')
  await expect(hero.getByRole('heading', { level: 1 })).toHaveText('現場のメモから、次につながる記録へ。')
  await expect(hero).toContainText('報告を整える。似た事例を探す。対応を残す。')

  const example = hero.locator('.landing-example')
  await expect(example).toContainText('表示例')
  await expect(example).toContainText('流量指示低下・導圧管閉塞の疑い')
  await expect(example).toContainText('内容を確認してから、記録に反映')
})

test('トップから実装済みの3つの仕事を選べる', async ({ page }) => {
  await page.goto('/')

  await expect(page.locator('.landing-work h3')).toHaveText([
    '不具合報告の下書き',
    '過去の類似トラブル',
    '対応記録の下書き',
  ])
  const links = page.locator('.landing-work a')
  await expect(links).toHaveCount(3)
  for (let i = 0; i < 3; i++) await expect(links.nth(i)).toHaveAttribute('href', /\/plana\?task=/)
})

test('AIの仕事のあとに、保全管理の土台と権限の説明が続く', async ({ page }) => {
  await page.goto('/')

  await expect(page.locator('.landing-foundation-grid h3')).toHaveText([
    '設備と記録をつなぐ',
    '保全の仕事を進める',
    '資材まで見渡す',
  ])
  await expect(page.getByRole('heading', { name: '自社も協力会社も、同じ記録で。' })).toBeVisible()
  await expect(page.locator('#permissions')).toContainText('所属と権限に合わせて')
})

test('ログイン前に仕事を始めると、選んだ仕事を復帰先にしてログインへ進む', async ({ page }) => {
  await page.goto('/')
  await page.getByRole('link', { name: /過去の類似トラブル.*この仕事を始める/ }).click()

  await expect(page).toHaveURL(/\/login\?redirect=/)
  expect(new URL(page.url()).searchParams.get('redirect')).toBe('/plana?task=similar-troubles')
})

test('ヒーローのCTAから作業ホームを復帰先にしてログインへ進む', async ({ page }) => {
  await page.goto('/')
  await page.getByRole('link', { name: 'プラナを試す', exact: true }).click()

  await expect(page).toHaveURL(/\/login\?redirect=/)
  expect(new URL(page.url()).searchParams.get('redirect')).toBe('/plana')
})

test('トップページは、スマホの幅でも横にはみ出さない', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()

  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)
  expect(overflow).toBe(0)
})
