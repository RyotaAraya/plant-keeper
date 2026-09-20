import { test, expect, login, selectOption, ACCOUNTS } from './support'

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
  await expect(page.locator('input[value^="漏れ"]')).toBeVisible()
  await expect(page.locator('input[value*="指示値"]')).toHaveCount(0)

  // 異常のあった項目にだけ、不具合を付ける。どの設備の不具合かを選ぶ（初期値は代表の設備）
  await page.getByRole('checkbox', { name: '不具合あり' }).first().check()
  const defectEquipment = page.locator('.v-field', { has: page.getByLabel('不具合の設備 *') })
  await expect(defectEquipment).toContainText('常圧蒸留装置')
  await selectOption(page, '不具合の設備 *', '重油間接脱硫装置')
  await page.getByLabel('トラブルタイトル').fill(title)

  const saved = page.waitForRequest((r) => r.url().endsWith('/api/v1/inspections') && r.method() === 'POST')
  await page.getByRole('button', { name: '下書き保存' }).click()
  const body = (await saved).postDataJSON()
  expect(body.inspection.equipment_ids).toHaveLength(2)
  await expect(page).toHaveURL(/\/inspections$/)

  await test.step('一覧に、まとめた設備が並ぶ（代表の設備が先頭）', async () => {
    await expect(page.getByRole('row', { name: /常圧蒸留装置、重油間接脱硫装置/ }).first()).toBeVisible()
  })

  await test.step('トラブルは、不具合として選んだ設備のものになる', async () => {
    await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
    await page.getByRole('textbox', { name: 'タイトル検索' }).fill(title)
    await expect(page.getByRole('row', { name: new RegExp(title) })).toContainText('重油間接脱硫装置')
  })
})

test('点検の詳細には、まとめて点検した設備がすべて出る', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections')
  await page.getByRole('row', { name: /常圧蒸留装置、重油間接脱硫装置/ }).first().click()

  await expect(page).toHaveURL(/\/inspections\/\d+/)
  await expect(page.getByTestId('inspection-equipment')).toHaveCount(2)
})
