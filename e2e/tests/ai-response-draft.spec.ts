import { test, expect, login, openListRow, requireFakeAi, ACCOUNTS } from './support'

// 対応記録のAI支援（要求仕様書 2.5.2）。**本物のAPIは呼ばない**（fake のバックエンドでだけ実行する。requireFakeAi）。
// 実行のたびに、シードのトラブル「FT-301 オリフィス閉塞疑い」に、対応記録（内容が `E2E ` で始まる）が1件ずつ増える
test('対応メモからAIの下書きを作り、反映すると入力欄に入る（提案のIDは保存時に送られる）', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  const statusResponse = page.waitForResponse((r) => r.url().endsWith('/api/v1/ai/status'))
  await openListRow(page, 'FT-301 オリフィス閉塞疑い')
  requireFakeAi((await (await statusResponse).json()).data.provider)

  await page.getByRole('button', { name: '対応記録' }).click()
  await expect(page.getByTestId('ai-response-assist')).toBeVisible()

  // メモが空のうちは押せない
  const button = page.getByTestId('ai-response-button')
  await expect(button).toBeDisabled()
  await page.getByLabel('対応メモ（プラナで整える）').fill('オリフィスの上流側を清掃した。スケールが付着していた。')
  await expect(button).toBeEnabled()
  await button.click()

  const draft = page.getByTestId('ai-response-draft')
  await expect(draft).toBeVisible()
  await expect(draft).toContainText('プラナの下書きです')

  // 反映するまで、入力欄は変わらない
  const description = page.getByLabel('対応内容 *')
  await expect(description).toHaveValue('')

  await page.getByTestId('ai-response-apply').click()
  await expect(draft).toHaveCount(0)
  await expect(description).toHaveValue(/オリフィスの上流側を清掃した/)

  // 人が直してから記録する。AIの提案のIDが、保存のリクエストに含まれる
  const text = `E2E ${Date.now()} AI下書きから`
  await description.fill(text)
  const request = page.waitForRequest((r) => r.url().endsWith('/api/v1/trouble_responses') && r.method() === 'POST')
  await page.getByRole('button', { name: '記録', exact: true }).click()
  const body = (await request).postDataJSON()
  expect(body.trouble_response.ai_suggestion_id).toEqual(expect.any(Number))

  // 人が直した内容で、対応履歴に載る
  await expect(page.getByText(text)).toBeVisible()
})
