import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'

// 詳細画面の「変更履歴」は、DBのカラム名やIDでなく、日本語のラベルと呼び方で出す。
// APIでトラブルを作って更新し（実行のたびに、タイトルが `E2E ` で始まるトラブルが1件増える）、その履歴を確かめる
test('トラブル詳細の変更履歴は、日本語のラベルと状態の呼び方で出て、カラム名やIDは出ない', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  const token = await page.evaluate(() => localStorage.getItem('jwt'))
  const headers = { Authorization: `Bearer ${token}` }
  const api = apiBaseUrl()

  const equipments = await (await page.request.get(`${api}/equipments?per_page=1`, { headers })).json()
  const title = `E2E ${Date.now()} 変更履歴の表示`
  const created = await page.request.post(`${api}/troubles`, {
    headers,
    data: { trouble: { equipment_id: equipments.data[0].id, title, description: '履歴の表示の確認', priority: 'high', reported_at: new Date().toISOString() } },
  })
  expect(created.ok()).toBeTruthy()
  const id = (await created.json()).data.id
  const updated = await page.request.patch(`${api}/troubles/${id}`, { headers, data: { trouble: { status: 'in_progress' } } })
  expect(updated.ok()).toBeTruthy()

  await page.goto(`/troubles/${id}`)
  const history = page.getByTestId('resource-history')
  await expect(history).toContainText('更新')

  // 更新: ラベル「状態」と、値の呼び方「未対応 → 対応中」
  await expect(history).toContainText('状態:')
  await expect(history).toContainText('未対応')
  await expect(history).toContainText('対応中')
  // 作成: 優先度は「高」、タイトルはそのまま
  await expect(history).toContainText('優先度:')
  await expect(history).toContainText(title)

  // カラム名（status / priority / reported_by_id など）と、IDの生の値は出ない
  const text = await history.innerText()
  expect(text).not.toMatch(/\b(status|priority|title|description|reported_at|equipment_id|reported_by_id)\b/)
  expect(text).not.toMatch(/\d{4}-\d{2}-\d{2}T/) // 日時はISOのまま出さない
})
