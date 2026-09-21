import { test, expect, login, selectFirstOption, requireFakeAi, ACCOUNTS } from './support'

// 不具合報告のAI支援（要求仕様書 2.5）。**本物のAPIは呼ばない**（fake のバックエンドでだけ実行する。requireFakeAi）
test('現場メモからAIの下書きを作り、反映すると入力欄に入る（提案のIDは保存時に送られる）', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  const statusResponse = page.waitForResponse((r) => r.url().endsWith('/api/v1/ai/status'))
  await page.goto('/inspections/new')
  requireFakeAi((await (await statusResponse).json()).data.provider)
  await selectFirstOption(page, '設備 *')
  await selectFirstOption(page, '部署 *')
  await page.getByRole('button', { name: '項目追加' }).click()
  await page.getByLabel('内容', { exact: true }).fill('圧力指示値の確認')

  // 不具合を付けるまで、AIの入力欄は出ない
  await expect(page.getByTestId('ai-assist')).toHaveCount(0)
  await page.getByRole('checkbox', { name: '不具合あり' }).check()

  await expect(page.getByTestId('ai-assist')).toBeVisible()

  // メモが空のうちは押せない
  const button = page.getByTestId('ai-draft-button')
  await expect(button).toBeDisabled()
  await page.getByLabel('現場メモ（プラナで整える）').fill('PT-101の指示値が数秒おきに上下している。昨日の夕方から。')
  await expect(button).toBeEnabled()
  await button.click()

  const draft = page.getByTestId('ai-draft')
  await expect(draft).toBeVisible()
  await expect(draft).toContainText('プラナの下書きです')
  const draftTitle = (await draft.innerText()).match(/タイトル:\s*(.+)/)?.[1].trim()
  expect(draftTitle).toBeTruthy()

  // 反映するまで、入力欄は変わらない
  const titleInput = page.getByLabel('トラブルタイトル')
  await expect(titleInput).toHaveValue('')

  await page.getByTestId('ai-apply').click()
  await expect(draft).toHaveCount(0)
  await expect(titleInput).toHaveValue(draftTitle!)

  // 人が直してから保存する。AIの提案のIDが、保存のリクエストに含まれる
  const title = `E2E ${Date.now()} AI下書きから`
  await titleInput.fill(title)
  const request = page.waitForRequest((r) => r.url().endsWith('/api/v1/inspections') && r.method() === 'POST')
  await page.getByRole('button', { name: '下書き保存' }).click()
  const body = (await request).postDataJSON()
  expect(body.inspection.items[0].ai_suggestion_id).toEqual(expect.any(Number))
  await expect(page).toHaveURL(/\/inspections$/)

  // 人が直したタイトルでトラブルができている
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await page.getByRole('textbox', { name: 'タイトル検索' }).fill(title)
  await expect(page.getByRole('row', { name: new RegExp(title) })).toBeVisible()
})

// 下書きは設備についてのもの。設備（代表の設備）を変えたら消える（別の設備の下書きを反映してしまわないように）
test('設備を変えると、前の設備についての下書きは消える', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  const statusResponse = page.waitForResponse((r) => r.url().endsWith('/api/v1/ai/status'))
  await page.goto('/inspections/new')
  requireFakeAi((await (await statusResponse).json()).data.provider)
  await selectFirstOption(page, '設備 *')
  await selectFirstOption(page, '部署 *')
  await page.getByRole('button', { name: '項目追加' }).click()
  await page.getByLabel('内容', { exact: true }).fill('圧力指示値の確認')
  await page.getByRole('checkbox', { name: '不具合あり' }).check()
  await page.getByLabel('現場メモ（プラナで整える）').fill('PT-101の指示値が数秒おきに上下している。')
  await page.getByTestId('ai-draft-button').click()
  await expect(page.getByTestId('ai-draft')).toBeVisible()

  // 選んだ設備を外して、別の設備（2番目の選択肢）を選ぶ
  await page.locator('.v-field', { has: page.getByLabel('設備 *', { exact: true }) }).locator('.v-chip__close').click()
  await expect(page.getByTestId('ai-draft')).toHaveCount(0)
  await page.locator('.v-field', { has: page.getByLabel('設備 *', { exact: true }) }).click()
  await page.getByRole('option').nth(1).click()
  await page.keyboard.press('Escape')
  await expect(page.getByTestId('ai-draft')).toHaveCount(0)
})
