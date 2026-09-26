import { test, expect } from './support'

// 公開トップは「PlantKeeperとは何か」→「プラナとは何か」→「1件のトラブルでのプラナの仕事」の順に見せる。
// プラナの3つの仕事は、同じトラブル（FT-301の指示低下）の流れでつなげる
test('ヒーローで、PlantKeeperが何を一元管理するシステムかを先に示す', async ({ page }) => {
  await page.goto('/')
  const hero = page.locator('.landing-hero')
  await expect(hero.getByRole('heading', { level: 1 })).toHaveText('PlantKeeper')
  await expect(hero).toContainText('設備保全に必要な情報を、ひとつの場所へ。')
  await expect(hero.getByRole('img')).toBeVisible()
  expect(await hero.getByRole('img').evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth > 0)).toBe(true)
})

test('保全業務の流れ・プラナの紹介・1件のトラブルの流れの順に並ぶ', async ({ page }) => {
  await page.goto('/')
  await expect(page.locator('.landing-flow strong')).toHaveText(['設備', '点検', 'トラブル', '修理', '資材', '在庫', '発注'])
  await expect(page.locator('.landing-foundation-grid h3')).toHaveText(['設備と記録をつなぐ', '保全の仕事を進める', '資材まで見渡す'])

  const order = await page.evaluate(() => ['#features', '#safety', '#plana', '#plana-work', '#try-guide', '#permissions']
    .map((selector) => document.querySelector(selector)!.getBoundingClientRect().top))
  expect([...order].sort((a, b) => a - b)).toEqual(order)

  await expect(page.locator('#plana').getByRole('heading', { level: 2 })).toHaveText('プラナ')
  await expect(page.locator('#plana')).toContainText('運転を続けてよいかの判断は出しません')
})

test('インターロックのバイパスの節で、申請から復帰の確認までの流れと、戻し忘れを防ぐ仕組みを実際の画面つきで示す', async ({ page }) => {
  await page.goto('/')
  const safety = page.locator('#safety')
  await expect(safety.getByRole('heading', { level: 2 })).toHaveText('インターロックのバイパスを、戻し忘れない。')
  await expect(safety.locator('.landing-bypass-steps strong')).toHaveText(['申請', '承認', 'バイパス', '復帰', '復帰の確認'])
  await expect(safety).toContainText('代替措置')
  await expect(safety).toContainText('復帰期限超過')
  await expect(safety).toContainText('検収へ進めません')
  const img = safety.getByRole('img')
  await expect(img).toBeVisible()
  expect(await img.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0)).toBe(true)
})

test('ヒーローのプラナの入口から、プラナの紹介へ移る', async ({ page }) => {
  await page.goto('/')
  await page.getByRole('link', { name: /AIアシスタント「プラナ」/ }).click()
  await expect(page).toHaveURL(/#plana$/)
  await expect(page.locator('#plana').getByRole('heading', { level: 2 })).toBeInViewport()
})

test('3つの仕事は、同じFT-301のトラブルを、気づく → 過去の事例 → 対応の記録の順にたどる', async ({ page }) => {
  const aiCalls: string[] = []
  page.on('request', (request) => {
    if (request.method() === 'POST' && request.url().includes('/ai/')) aiCalls.push(request.url())
  })
  await page.goto('/')
  const steps = page.locator('.landing-step')
  await expect(steps.locator('h3')).toHaveText(['点検で気づく', '過去の事例を見る', '対応を記録する'])
  for (let i = 0; i < 3; i++) await expect(steps.nth(i)).toContainText('FT-301')

  // 1: 定型項目とプラナの提案（見立て・確認したい点）。「プラナ」を名乗るのはカードの案内文1箇所だけ
  const defect = steps.nth(0)
  await expect(defect).toContainText('一次点検の定型項目')
  await expect(defect).toContainText('ゼロ点ズレの確認')
  await expect(defect.locator('.pk-plana-card')).toContainText('プラナが整理しました')
  await expect(defect.getByText('見立て', { exact: true })).toBeVisible()
  await expect(defect).toContainText('導圧管の閉塞の可能性')

  // 2: 過去の事例が、1の見立て（導圧管）の手がかりになる
  const similar = steps.nth(1)
  await expect(similar).toContainText('似ている点:')
  await expect(similar).toContainText('過去の対応:')
  await expect(similar).toContainText('導圧管')

  // 3: 口語のメモが、対応種別・使用資材・確認したい点に整理される（メモの言い換え止まりにしない）
  const response = steps.nth(2)
  await expect(response).toContainText('対応種別: 修理')
  await expect(response).toContainText('使用資材:')
  await expect(response.getByText('確認したい点', { exact: true })).toBeVisible()

  const links = [
    ['不具合報告の整理を試す', 'defect-draft'],
    ['過去の類似トラブルを試す', 'similar-troubles'],
    ['対応記録の整理を試す', 'response-draft'],
  ]
  for (const [name, task] of links) {
    await expect(page.getByRole('link', { name })).toHaveAttribute('href', `/plana?task=${task}`)
  }
  expect(aiCalls).toEqual([])
})

test('ログイン前に仕事を始めると、選んだ仕事を復帰先にしてログインへ進む', async ({ page }) => {
  await page.goto('/')
  await page.getByRole('link', { name: '過去の類似トラブルを試す' }).click()

  await expect(page).toHaveURL(/\/login\?redirect=/)
  expect(new URL(page.url()).searchParams.get('redirect')).toBe('/plana?task=similar-troubles')
})

test('ヒーローのCTAから作業ホームを復帰先にしてログインへ進む', async ({ page }) => {
  await page.goto('/')
  await page.getByRole('link', { name: 'デモアカウントで試す', exact: true }).click()

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
  await expect(page.getByRole('heading', { name: '自社も協力会社も、同じ記録で。' })).toBeVisible()
  await expect(page.locator('#permissions')).toContainText('技能員')
  const matrix = page.locator('#permissions table')
  await expect(matrix).toBeHidden()
  await page.getByText('業務機能の詳しい権限を見る', { exact: true }).click()
  await expect(matrix).toBeVisible()
  await page.getByRole('link', { name: 'デモアカウントで始める' }).click()
  await expect(page).toHaveURL(/\/login\?redirect=/)
})
