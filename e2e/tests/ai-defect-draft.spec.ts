import { test, expect, login, selectFirstOption, ACCOUNTS } from './support'

// 不具合報告のAI支援（要求仕様書 2.5）。ローカル・CIはバックエンドを AI_PROVIDER=fake（APIを呼ばないダミー）で動かす。
// stg（APIキーあり）で実行すると本物のAIを呼ぶため、下書きの中身は決まらない（画面に出た下書きと入力欄が一致することだけを確かめる）
test('現場メモからAIの下書きを作り、反映すると入力欄に入る（提案のIDは保存時に送られる）', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections/new')
  await selectFirstOption(page, '設備 *')
  await selectFirstOption(page, '部署 *')
  await page.getByRole('button', { name: '項目追加' }).click()
  await page.getByLabel('内容', { exact: true }).fill('圧力指示値の確認')

  // 不具合を付けるまで、AIの入力欄は出ない
  await expect(page.getByTestId('ai-assist')).toHaveCount(0)
  await page.getByRole('checkbox', { name: '不具合あり' }).check()

  const assist = page.getByTestId('ai-assist')
  const visible = await assist.waitFor({ state: 'visible', timeout: 5_000 }).then(() => true, () => false)
  if (!visible) {
    // CIで黙ってスキップされて、AIの画面が検証されないままになるのを防ぐ
    expect(process.env.CI, 'CIでは、バックエンドを AI_PROVIDER=fake で起動する').toBeFalsy()
    test.skip(true, 'AI機能が使えない環境（ANTHROPIC_API_KEY・AI_PROVIDER が未設定）')
  }

  // メモが空のうちは押せない
  const button = page.getByTestId('ai-draft-button')
  await expect(button).toBeDisabled()
  await page.getByLabel('現場メモ（AIで整える）').fill('PT-101の指示値が数秒おきに上下している。昨日の夕方から。')
  await expect(button).toBeEnabled()
  await button.click()

  const draft = page.getByTestId('ai-draft')
  await expect(draft).toBeVisible()
  await expect(draft).toContainText('AIの下書きです')
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
