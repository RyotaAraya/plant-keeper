import { test, expect, login, ACCOUNTS, selectFirstOption, requireFakeAi, openFirstTrouble } from './support'
import type { Page } from '@playwright/test'

async function submitLogin(page: Page) {
  await page.getByLabel('メールアドレス').fill(ACCOUNTS.member.email)
  await page.getByLabel('パスワード').fill(ACCOUNTS.member.password)
  await page.getByRole('button', { name: 'ログイン', exact: true }).click()
}

test('ログインするとプラナの作業場が開き、初期表示ではAIを呼ばない', async ({ page }) => {
  const calls: string[] = []
  page.on('request', (r) => { if (r.method() === 'POST' && r.url().includes('/ai/')) calls.push(r.url()) })
  await login(page, ACCOUNTS.member)
  await expect(page.getByRole('heading', { level: 1, name: '今日は、何から始めますか？' })).toBeVisible()
  await expect(page.getByTestId('plana-task')).toHaveCount(3)
  await expect(page.getByLabel('いま起きている症状')).toBeVisible()
  await page.waitForLoadState('networkidle')
  expect(calls).toEqual([])
})

test('公開トップで選んだ仕事を、通常ログイン後に引き継ぐ', async ({ page }) => {
  await page.goto('/')
  await page.getByRole('link', { name: /対応記録の下書き.*この仕事を始める/ }).click()
  await expect(page).toHaveURL(/\/login\?redirect=/)
  await submitLogin(page)
  await expect(page).toHaveURL(/\/plana\?task=response-draft$/)
  await expect(page.getByRole('textbox', { name: 'トラブルのタイトルで検索', exact: true })).toBeVisible()
})

test('デモログインでも目的を引き継ぎ、技能員には対応記録の入口を出さない', async ({ page }) => {
  await page.goto('/plana?task=response-draft')
  await page.locator('.pk-demo-item').filter({ hasText: '技能員' }).click()
  await expect(page.getByText('この権限では対応記録を作成できません。', { exact: false })).toBeVisible()
  await expect(page.getByTestId('plana-task')).toHaveCount(2)
  await expect(page.getByRole('textbox', { name: 'トラブルのタイトルで検索', exact: true })).toHaveCount(0)
  await expect(page.getByRole('button', { name: '表示する拠点を選ぶ' })).toHaveCount(0)
})

test('外部URLや存在しない画面を認証後の復帰先に使わない', async ({ page }) => {
  await page.goto('/login?redirect=https%3A%2F%2Fexample.com')
  await submitLogin(page)
  await expect(page).toHaveURL(/\/plana$/)
  for (const destination of ['//example.com', '/login', '/not-a-route', '/\\example.com']) {
    await page.goto(`/login?redirect=${encodeURIComponent(destination)}`)
    await expect(page).toHaveURL(/\/plana$/)
  }
})

test('期限切れのトークンでログイン画面を開いても復帰先を保ってログインできる', async ({ page }) => {
  await page.goto('/vite.svg')
  await page.evaluate(() => localStorage.setItem('jwt', 'expired.token.value'))
  await page.goto('/login?redirect=%2Fplana%3Ftask%3Ddefect-draft')
  await expect(page.getByLabel('メールアドレス')).toBeVisible()
  await submitLogin(page)
  await expect(page).toHaveURL(/\/plana\?task=defect-draft$/)
})

test('プラナで選んだ設備と計器を点検に引き継ぎ、不具合欄から始める', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByTestId('plana-task').filter({ hasText: '不具合報告の下書き' }).click()
  await selectFirstOption(page, '対象の設備')
  await selectFirstOption(page, '対象の計器（任意）')
  const selectedTag = await page.getByRole('combobox', { name: '対象の計器（任意）' }).inputValue()
  await page.getByRole('button', { name: '不具合の記録を始める' }).click()
  await expect(page).toHaveURL(/\/inspections\/new\?plana=defect-draft/)
  await expect(page.getByTestId('from-plana')).toBeVisible()
  await expect(page.getByRole('checkbox', { name: '不具合あり' })).toBeChecked()
  await expect(page.getByRole('combobox', { name: '計器（任意）', exact: true })).toHaveValue(selectedTag)
  await expect(page.getByLabel('トラブルタイトル')).toBeVisible()
})

test('トラブルを探して対応記録の入力を直接開ける', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByTestId('plana-task').filter({ hasText: '対応記録の下書き' }).click()
  await page.getByRole('textbox', { name: 'トラブルのタイトルで検索', exact: true }).fill('FT-301')
  await page.getByRole('button', { name: '検索', exact: true }).click()
  await page.locator('.plana-records a').first().click()
  await expect(page).toHaveURL(/\/troubles\/\d+\?plana=response-draft/)
  await expect(page.getByRole('dialog', { name: '対応記録追加' })).toBeVisible()
  await expect(page.getByLabel('対応内容 *')).toHaveValue('')
  await page.getByRole('button', { name: 'キャンセル', exact: true }).click()
  await expect(page.getByRole('dialog')).toHaveCount(0)
})

test('技能員が対応記録の直接URLを開いてもダイアログは開かない', async ({ page }) => {
  await login(page, { email: 'honda@example.com', password: 'password' })
  await openFirstTrouble(page)
  await expect(page).toHaveURL(/\/troubles\/\d+$/)
  await page.goto(`${page.url()}?plana=response-draft`)
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
  await page.waitForLoadState('networkidle')
  await expect(page.getByRole('dialog')).toHaveCount(0)
})

test('プラナの作業場で類似事例を検索し、メモを変えると古い結果を消す', async ({ page }) => {
  const status = page.waitForResponse((r) => r.url().endsWith('/ai/status'))
  await login(page, ACCOUNTS.member)
  requireFakeAi((await (await status).json()).data.provider)
  await selectFirstOption(page, '対象の設備')
  await page.getByLabel('いま起きている症状').fill('流量指示が低い。導圧管のつまりが疑われる。')
  await page.getByTestId('plana-search').click()
  await expect(page.getByTestId('ai-similar-result')).toBeVisible()
  await expect(page.getByLabel('いま起きている症状')).toHaveValue('流量指示が低い。導圧管のつまりが疑われる。')
  await page.getByLabel('いま起きている症状').fill('温度の指示が高い')
  await expect(page.getByTestId('ai-similar-result')).toHaveCount(0)
})

test('AI無効でもメモと対象を保ったまま仕事を切り替え、通常入力へ進める', async ({ page }) => {
  await page.route('**/api/v1/ai/status', (route) => route.fulfill({ json: { data: { enabled: false, remaining_today: 0, daily_limit: 20, max_memo_length: 1000 } } }))
  await login(page, ACCOUNTS.member)
  await expect(page.getByTestId('plana-disabled')).toBeVisible()
  await selectFirstOption(page, '対象の設備')
  await page.getByLabel('いま起きている症状').fill('残しておきたいメモ')
  await expect(page.getByTestId('plana-search')).toBeDisabled()
  await page.getByTestId('plana-task').filter({ hasText: '不具合報告の下書き' }).click()
  await expect(page.getByRole('button', { name: '不具合の記録を始める' })).toBeEnabled()
  await page.getByTestId('plana-task').filter({ hasText: '過去の類似トラブル' }).click()
  await expect(page.getByLabel('いま起きている症状')).toHaveValue('残しておきたいメモ')
  page.once('dialog', (dialog) => dialog.dismiss())
  await page.getByRole('link', { name: '記録を自分で探す' }).click()
  await expect(page).toHaveURL(/\/plana\?task=similar-troubles$/)
  await expect(page.getByLabel('いま起きている症状')).toHaveValue('残しておきたいメモ')
})

test('利用状況の取得に失敗しても、メモを残して再確認できる', async ({ page }) => {
  await page.route('**/api/v1/ai/status', (route) => route.abort('failed'), { times: 1 })
  await login(page, ACCOUNTS.member)
  await expect(page.getByText('AIの利用状況を確認できません。', { exact: false })).toBeVisible()
  await page.getByLabel('いま起きている症状').fill('取得が失敗しても残すメモ')
  await page.getByRole('button', { name: '利用状況を再確認' }).click()
  await expect(page.getByRole('button', { name: '利用状況を再確認' })).toHaveCount(0)
  await expect(page.getByLabel('いま起きている症状')).toHaveValue('取得が失敗しても残すメモ')
})

test('検索中にメモを変更すると古い検索結果を表示せず、残り回数だけを更新する', async ({ page }) => {
  // AIの応答はすべてスタブ。実APIを呼ばず、応答の順序だけを制御する。
  await page.route('**/api/v1/ai/status', (route) => route.fulfill({ json: { data: { enabled: true, provider: 'fake', remaining_today: 20, daily_limit: 20, max_memo_length: 1000 } } }))
  let release!: () => void
  const gate = new Promise<void>((resolve) => { release = resolve })
  await page.route('**/api/v1/ai/similar_troubles', async (route) => {
    await gate
    await route.fulfill({ json: { data: { cases: [], candidates_count: 1, remaining_today: 19 } } })
  })
  await login(page, ACCOUNTS.member)
  await selectFirstOption(page, '対象の設備')
  await page.getByLabel('いま起きている症状').fill('変更前の症状')
  const request = page.waitForRequest((r) => r.url().endsWith('/ai/similar_troubles') && r.method() === 'POST')
  await page.getByTestId('plana-search').click()
  await request
  await page.getByLabel('いま起きている症状').fill('変更後の症状')
  const response = page.waitForResponse((r) => r.url().endsWith('/ai/similar_troubles'))
  release()
  await response
  await expect(page.getByTestId('plana-remaining')).toContainText('19 / 20')
  await expect(page.getByTestId('ai-similar-result')).toHaveCount(0)
  await expect(page.getByTestId('plana-search')).toBeEnabled()
})
