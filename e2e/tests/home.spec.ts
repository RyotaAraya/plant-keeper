import { test, expect } from './support'

// 公開トップは、プラナで始められる実在の仕事を先に示し、その土台として
// PlantKeeperの保全管理機能と権限を説明する。回答しない相談欄は置かない。
test('ヒーローは紹介とプラナに絞り、具体例は次の段に表示する', async ({ page }) => {
  await page.goto('/')
  const hero = page.locator('.landing-hero')
  await expect(hero.getByRole('heading', { level: 1 })).toHaveText('プラナと進める、設備保全。')
  await expect(hero.getByRole('img')).toBeVisible()
  await expect(hero.locator('.landing-example')).toHaveCount(0)
  await expect(page.getByRole('tabpanel')).toContainText('架空のメモ・記録による表示例')
  await expect(page.getByRole('tabpanel')).toContainText('FT-301 流量指示の低下')
})

test('不具合の相談の例は、計器の一次点検の定型項目とプラナ固有の確認事項を分けて示す', async ({ page }) => {
  await page.goto('/')
  const panel = page.getByRole('tabpanel')
  await expect(panel).toContainText('一次点検の定型項目')
  await expect(panel).toContainText('ゼロ点ズレの確認')
  await expect(panel).toContainText('プラナが挙げた確認したい点')
  await expect(panel).toContainText('現場の流量と、FT-301の指示は一致しているか？')
})

test('3つの仕事の表示例を切り替え、選んだ仕事を試せる', async ({ page }) => {
  const aiCalls: string[] = []
  page.on('request', (request) => {
    if (request.method() === 'POST' && request.url().includes('/ai/')) aiCalls.push(request.url())
  })
  await page.goto('/')
  const choices = [
    ['不具合を相談する', 'FT-301 流量指示の低下', 'defect-draft'],
    ['似た事例を探す', '流量計の信号途絶', 'similar-troubles'],
    ['対応を記録する', '端子の増し締め・指示の復旧確認', 'response-draft'],
  ]
  for (const [label, title, task] of choices) {
    await page.getByRole('tab', { name: label }).click()
    await expect(page.getByRole('tab', { name: label })).toHaveAttribute('aria-selected', 'true')
    await expect(page.getByRole('tabpanel')).toContainText(title)
    await expect(page.getByRole('link', { name: 'この仕事を試す' })).toHaveAttribute('href', `/plana?task=${task}`)
  }
  await page.getByRole('tab', { name: '対応を記録する' }).press('ArrowLeft')
  await expect(page.getByRole('tab', { name: '似た事例を探す' })).toBeFocused()
  expect(aiCalls).toEqual([])
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
  await page.getByRole('tab', { name: '似た事例を探す' }).click()
  await page.getByRole('link', { name: 'この仕事を試す' }).click()

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


test('体験条件を案内し、詳細権限は必要なときに開ける', async ({ page }) => {
  await page.goto('/')
  await expect(page.locator('#try-guide')).toContainText('上の表示例は自動入力されません')
  await expect(page.locator('#try-guide')).toContainText('1日の利用上限')
  await expect(page.locator('#permissions')).toContainText('技能員')
  const matrix = page.locator('#permissions table')
  await expect(matrix).toBeHidden()
  await page.getByText('業務機能の詳しい権限を見る', { exact: true }).click()
  await expect(matrix).toBeVisible()
  await expect(page.locator('.landing-product img')).toBeVisible()
  expect(await page.locator('.landing-product img').evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth > 0)).toBe(true)
  await page.getByRole('link', { name: 'デモアカウントで始める' }).click()
  await expect(page).toHaveURL(/\/login\?redirect=/)
})
