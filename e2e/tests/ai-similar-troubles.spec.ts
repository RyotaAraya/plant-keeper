import { test, expect, login, openListRow, selectFirstOption, requireFakeAi, ACCOUNTS } from './support'

// 類似トラブルのAI支援（要求仕様書 2.5.1）。**本物のAPIは呼ばない**（fake のバックエンドでだけ実行する。requireFakeAi）。
// fake は先頭の候補（いちばん関連が深いもの）を返す。何も保存しないので、繰り返し実行してもデータは増えない
test('トラブルの詳細から、過去の類似トラブルを探すと、別のトラブルが対応の要約つきで出る', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  const statusResponse = page.waitForResponse((r) => r.url().endsWith('/api/v1/ai/status'))
  await openListRow(page, 'FT-301 オリフィス閉塞疑い')
  requireFakeAi((await (await statusResponse).json()).data.provider)
  await expect(page).toHaveURL(/\/troubles\/\d+$/)
  const ownPath = new URL(page.url()).pathname

  await page.getByTestId('ai-similar-button').click()

  const result = page.getByTestId('ai-similar-result')
  await expect(result).toBeVisible()
  await expect(result).toContainText('プラナが選んだ候補です')
  const found = page.getByTestId('ai-similar-case').first()
  await expect(found).toContainText('FT-301') // 同じ計器の別のトラブル
  await expect(found).toContainText('似ている点')
  await expect(found).toContainText('過去の対応')

  // 開いているトラブル自身は出ない。リンクは別のトラブルの詳細で、別のタブで開く（元の画面を離れない）
  await expect(found).not.toContainText('FT-301 オリフィス閉塞疑い')
  const link = found.getByRole('link')
  await expect(link).toHaveAttribute('href', /\/troubles\/\d+$/)
  await expect(link).not.toHaveAttribute('href', ownPath)
  await expect(link).toHaveAttribute('target', '_blank')

  await result.getByRole('button', { name: '閉じる' }).click()
  await expect(result).toHaveCount(0)
})

test('点検フォームの不具合入力から、現場メモで過去の類似トラブルを探せる（メモが空のうちは押せない）', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  const statusResponse = page.waitForResponse((r) => r.url().endsWith('/api/v1/ai/status'))
  await page.goto('/inspections/new')
  requireFakeAi((await (await statusResponse).json()).data.provider)
  await selectFirstOption(page, '設備 *')
  await selectFirstOption(page, '部署 *')
  await page.getByRole('button', { name: '項目追加' }).click()
  await page.getByLabel('内容', { exact: true }).fill('圧力指示値の確認')
  await page.getByRole('checkbox', { name: '不具合あり' }).check()

  const button = page.getByTestId('ai-similar-button')
  await expect(button).toBeDisabled()
  await page.getByLabel('現場メモ（プラナで整える）').fill('指示値が数秒おきに上下している')
  await expect(button).toBeEnabled()
  await button.click()

  // 選んだ設備にトラブルの履歴があるかは環境のデータ次第のため、結果の枠（候補の件数の説明つき）が出ることを確かめる
  const result = page.getByTestId('ai-similar-result')
  await expect(result).toBeVisible()
  await expect(result).toContainText('過去のトラブル')
  // 探しただけで、入力欄は変わらない
  await expect(page.getByLabel('トラブルタイトル')).toHaveValue('')

  // メモを変えたら、前のメモに対する結果は消える（今の入力への結果に見えないように）
  await page.getByLabel('現場メモ（プラナで整える）').fill('指示値が急に振り切れた')
  await expect(result).toHaveCount(0)
})
