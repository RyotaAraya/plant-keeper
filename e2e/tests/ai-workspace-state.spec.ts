import { test, expect, login, openFirstTrouble, ACCOUNTS } from './support'

// AI生成を呼ばず、利用状況と入力保持だけを検証する。
const available = { enabled: true, provider: 'fake', remaining_today: 5, daily_limit: 20, max_memo_length: 1000 }

test('点検メモは開閉・別項目の削除・離脱の取消で保持される', async ({ page }) => {
  await page.route('**/api/v1/ai/status', (r) => r.fulfill({ json: { data: available } }))
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections/new')
  await page.getByRole('button', { name: '項目追加' }).click()
  await page.getByRole('button', { name: '項目追加' }).click()
  const checks = page.getByRole('checkbox', { name: '不具合あり' })
  const memos = page.getByLabel('現場メモ', { exact: true })
  await checks.first().check()
  await memos.first().fill('一つ目のメモ')
  await checks.nth(1).check()
  await memos.nth(1).fill('二つ目のメモ')
  await checks.nth(1).uncheck()
  await checks.nth(1).check()
  await expect(memos.nth(1)).toHaveValue('二つ目のメモ')
  page.once('dialog', (d) => d.accept())
  await page.getByRole('button', { name: '項目 1 を削除' }).click()
  await expect(memos).toHaveValue('二つ目のメモ')
  page.once('dialog', (d) => d.dismiss())
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await expect(page).toHaveURL(/\/inspections\/new$/)
  await expect(memos).toHaveValue('二つ目のメモ')
  page.once('dialog', (d) => d.accept())
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await expect(page).toHaveURL(/\/troubles$/)
})

test('対応記録はキャンセルを取り消すと入力が残り、破棄後は空になる', async ({ page }) => {
  await page.route('**/api/v1/ai/status', (r) => r.fulfill({ json: { data: available } }))
  await login(page, ACCOUNTS.member)
  await openFirstTrouble(page)
  await page.getByRole('button', { name: '対応記録', exact: true }).click()
  const memo = page.getByLabel('対応メモ', { exact: true })
  const record = page.getByLabel('対応内容 *', { exact: true })
  await memo.fill('清掃した')
  await record.fill('入力途中の記録')
  page.once('dialog', (d) => d.dismiss())
  await page.keyboard.press('Escape')
  await expect(memo).toHaveValue('清掃した')
  await expect(record).toHaveValue('入力途中の記録')
  page.once('dialog', (d) => d.accept())
  await page.getByRole('button', { name: 'キャンセル', exact: true }).click()
  await expect(page.getByRole('dialog')).not.toBeVisible()
  await page.getByRole('button', { name: '対応記録', exact: true }).click()
  await expect(memo).toHaveValue('')
  await expect(record).toHaveValue('')
})

test('AI状況の再確認と上限到達で手入力を失わない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  let fail = true
  await page.route('**/api/v1/ai/status', (r) => fail ? r.abort('failed') : r.fulfill({ json: { data: { ...available, remaining_today: 0 } } }))
  await page.goto('/inspections/new')
  await page.getByRole('button', { name: '項目追加' }).click()
  await page.getByRole('checkbox', { name: '不具合あり' }).check()
  await expect(page.getByText('AIの利用状況を取得できませんでした。記録の入力は続けられます。')).toBeVisible()
  await page.getByLabel('トラブルタイトル').fill('手入力の報告')
  fail = false
  await page.getByRole('button', { name: '再確認', exact: true }).click()
  await expect(page.getByText('今日のAI利用回数の上限に達しました。', { exact: false })).toBeVisible()
  await page.getByLabel('現場メモ', { exact: true }).fill('残しておくメモ')
  await expect(page.getByTestId('ai-draft-button')).toBeDisabled()
  await expect(page.getByLabel('トラブルタイトル')).toHaveValue('手入力の報告')
  await expect(page.getByLabel('現場メモ', { exact: true })).toHaveValue('残しておくメモ')
})

test('初期データの取得中は点検フォームを操作できない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  let release!: () => void
  const gate = new Promise<void>((resolve) => (release = resolve))
  await page.route('**/api/v1/checklist_templates**', async (route) => {
    await gate
    await route.continue()
  })
  await page.goto('/inspections/new')
  await expect(page.getByText('点検入力を準備しています。')).toBeVisible()
  await expect(page.getByLabel('備考')).toHaveCount(0)
  release()
  await expect(page.getByLabel('備考')).toBeVisible()
})

test('未保存の点検入力があるとログアウト前に破棄を確認する', async ({ page }) => {
  await login(page, ACCOUNTS.logout)
  await page.goto('/inspections/new')
  await page.getByLabel('備考').fill('保存前の点検メモ')
  await page.getByRole('button', { name: 'アカウントメニュー' }).click()
  page.once('dialog', (dialog) => dialog.dismiss())
  await page.getByText('ログアウト', { exact: true }).click()
  await expect(page).toHaveURL(/\/inspections\/new$/)
  await expect(page.getByLabel('備考')).toHaveValue('保存前の点検メモ')

  await page.getByRole('button', { name: 'アカウントメニュー' }).click()
  const logoutResponse = page.waitForResponse(
    (response) => response.url().endsWith('/api/v1/logout') && response.request().method() === 'DELETE',
  )
  page.once('dialog', (dialog) => dialog.accept())
  await page.getByText('ログアウト', { exact: true }).click()
  expect((await logoutResponse).status()).toBe(204)
  await expect(page).toHaveURL(/\/login$/)
})
