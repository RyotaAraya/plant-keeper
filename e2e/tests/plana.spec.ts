import { test, expect, login, ACCOUNTS } from './support'

// プラナ（AIアシスタント）の入口。AIは呼ばない（このページが呼ぶのは GET /ai/status だけ）ので、
// バックエンドのAIが fake でも本物でも無効でも、同じように実行できる
test('ヘッダーのプラナから専用ページを開くと、できること3つが、使う場所への入口つきで並ぶ', async ({ page }) => {
  await login(page, ACCOUNTS.member)

  await page.getByTestId('plana-call').click()
  await expect(page).toHaveURL(/\/plana$/)
  await expect(page.getByRole('heading', { level: 1, name: 'プラナ AI' })).toBeVisible()
  await expect(page.getByRole('heading', { name: 'プラナでできること' })).toBeVisible()
  await expect(page.getByTestId('plana-capability')).toHaveCount(3)
  await expect(page.getByRole('heading', { name: '不具合報告の下書き' })).toBeVisible()

  // 各機能は、使う画面へ案内する（プラナは各画面の中で呼び出す）
  await page.getByRole('link', { name: '点検を入力する' }).click()
  await expect(page).toHaveURL(/\/inspections\/new$/)
})

test('相談欄に入れた文は、専用ページで「いただいた相談」として表示され、まだ答えられないことを伝える', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/plana')

  await expect(page.getByTestId('plana-question')).toHaveCount(0)
  await page.getByLabel('プラナに相談する').fill('PT-100の過去のトラブルを教えてください')
  await page.getByRole('button', { name: '相談する' }).click()

  await expect(page).toHaveURL(/\/plana\?q=/)
  const question = page.getByTestId('plana-question')
  await expect(question).toContainText('PT-100の過去のトラブルを教えてください')
  await expect(question).toContainText('文章での質問への回答は、まだ用意できていません')
})

test('ログイン済みでトップページから相談すると、専用ページに移って相談内容が出る', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/')

  const plana = page.locator('#plana')
  await expect(plana).not.toContainText('プラナはログイン後に使えます')
  await plana.getByLabel('プラナに相談する').fill('点検結果の傾向を知りたい')
  await plana.getByRole('button', { name: '相談する' }).click()

  await expect(page).toHaveURL(/\/plana\?q=/)
  await expect(page.getByTestId('plana-question')).toContainText('点検結果の傾向を知りたい')
})
