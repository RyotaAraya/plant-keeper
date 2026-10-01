import { test, expect, login, apiBaseUrl, selectOption, ACCOUNTS } from './support'

// 運転員の巡回は、装置ごとではなく、いくつかの装置をまとめて1件で記録する。異常があったときだけ、その設備の不具合として記録する
test('複数の設備をまとめて巡回点検を記録し、異常があった設備のトラブルとして登録される', async ({ page }) => {
  const title = `E2E ${Date.now()} 巡回で見つけた漏れ`
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections/new')
  await expect(page.getByRole('heading', { level: 1, name: '新規点検記録' })).toBeVisible()

  await selectOption(page, '設備 *', '常圧蒸留装置') // 最初に選んだ設備が代表の設備
  await selectOption(page, '設備 *', '重油間接脱硫装置')
  await selectOption(page, 'テンプレート（任意）', '巡回点検', { exact: true })

  // 単独の計器ではなく、装置の巡回。指示値の確認の項目はない
  await expect(page.getByLabel('計器（任意）')).toHaveCount(0)
  await expect(page.getByText(/^漏れ（継手/)).toBeVisible()
  await expect(page.locator('.pk-item-content', { hasText: '指示値' })).toHaveCount(0)

  // 異常のあった項目にだけ、不具合を付ける。どの設備の不具合かを選ぶ（初期値は代表の設備）
  await page.getByRole('button', { name: '不具合あり' }).first().click()
  const defectEquipment = page.locator('.v-field', { has: page.getByLabel('不具合の設備 *') })
  await expect(defectEquipment).toContainText('常圧蒸留装置')
  await selectOption(page, '不具合の設備 *', '重油間接脱硫装置')
  await page.getByLabel('トラブルタイトル').fill(title)

  const saved = page.waitForRequest((r) => r.url().endsWith('/api/v1/inspections') && r.method() === 'POST')
  await page.getByRole('button', { name: '下書き保存' }).click()
  const body = (await saved).postDataJSON()
  expect(body.inspection.equipment_ids).toHaveLength(2)
  await expect(page).toHaveURL(/\/inspections\/\d+\?.*saved=/)

  await page.getByRole('link', { name: '点検・作業記録', exact: true }).click()

  await test.step('一覧に、まとめた設備が並ぶ（代表の設備が先頭）', async () => {
    await expect(page.getByRole('row', { name: /常圧蒸留装置、重油間接脱硫装置/ }).first()).toBeVisible()
  })

  await test.step('トラブルは、不具合として選んだ設備のものになる', async () => {
    await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
    await page.getByRole('textbox', { name: 'タイトル検索' }).fill(title)
    await expect(page.getByRole('row', { name: new RegExp(title) })).toContainText('重油間接脱硫装置')
  })
})

// 前のテストが作った点検には頼らない（テスト単位で別のジョブ・ワーカーに振り分けられるため）。実行のたびに、APIで設備2つの点検（備考が `E2E ` で始まる下書き）を1件作る
test('点検の詳細には、まとめて点検した設備がすべて出る', async ({ page }) => {
  const api = apiBaseUrl()
  const loginRes = await page.request.post(`${api}/login`, { data: { user: ACCOUNTS.member } })
  const headers = { Authorization: loginRes.headers()['authorization'] }
  const get = async (path: string) => (await page.request.get(`${api}${path}`, { headers })).json()
  const me = (await get('/current_user')).user
  const equipments = (await get(`/equipments?per_page=1000&site_ids[]=${me.site_id}`)).data
  const ids = ['常圧蒸留装置', '重油間接脱硫装置'].map((name) => equipments.find((e: any) => e.name === name).id)
  const department = (await get(`/departments?site_id=${me.site_id}`)).data[0]
  const created = await page.request.post(`${api}/inspections`, {
    headers,
    data: { inspection: { equipment_ids: ids, department_id: department.id, inspection_type: 'routine', status: 'draft', inspected_at: new Date().toISOString(), notes: `E2E ${Date.now()} 設備をまとめた点検` } },
  })
  expect(created.ok()).toBeTruthy()
  const id = (await created.json()).data.id

  await login(page, ACCOUNTS.member)
  await page.goto(`/inspections/${id}`)
  const shown = page.getByTestId('inspection-equipment')
  await expect(shown).toHaveCount(2)
  await expect(shown.first()).toContainText('常圧蒸留装置')
  await expect(shown.nth(1)).toContainText('重油間接脱硫装置')
})
