import { readFileSync } from 'node:fs'
import { test, expect, login, openPlans, ACCOUNTS } from './support'

// FT-301（川崎。差圧0〜100kPa・許容差±0.5%・伝送器は比例出力（4-20mA）・DCSは平方根（0〜500t/h））を、
// 使える基準器 RS-KW-001 で校正した記録と、見つからない計器の記録を1件ずつ持つファイル。
// 同じ計器・実施日時の記録は2回取り込めないため、実行のたびに実施日時（過去50日以内）を変える。
// extra は FT-301 の記録に足す項目（作業指示の計画のID）
function calibrationFile(extra: Record<string, unknown> = {}) {
  const performedAt = new Date(Date.now() - 60 * 60 * 1000 - Math.floor(Math.random() * 50 * 24 * 60 * 60) * 1000)
  performedAt.setMilliseconds(0)
  const points = [0, 25, 50, 75, 100].map((percent) => {
    const reading = { output: 4 + 16 * (percent / 100), dcs: 500 * Math.sqrt(percent / 100) }
    return { percent, up: reading, down: reading }
  })
  const record = (tag: string) => ({
    site: '川崎製油所', tag_number: tag, performed_at: performedAt.toISOString(), performed_by: 'E2E 実施者',
    reference_standards: ['RS-KW-001'], adjusted: false, stages: { as_found: { points } },
  })
  const document = {
    format: 'plant-keeper-calibration', version: 1, calibrator: { model: 'E2E キャリブレータ', serial_number: 'E2E-001' },
    records: [{ ...record('FT-301'), ...extra }, record('E2E-NONE')],
  }
  return { name: 'e2e-calibration.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(document)) }
}

test('校正結果のファイルを確認してから取り込むと、取り込める記録だけが5点校正の下書きになり、出所が残る', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: '点検・作業記録', exact: true }).click()
  await page.getByRole('button', { name: '校正結果の取り込み' }).click()

  const dialog = page.getByTestId('calibration-import')
  await expect(dialog.getByRole('combobox')).toHaveCount(0)
  await expect(dialog.getByText('記録する部署は、あなたの所属部署になります。')).toBeVisible()
  const previewRequest = page.waitForRequest((request) => request.url().endsWith('/calibration_imports/preview'))
  await dialog.locator('input[type="file"]').setInputFiles(calibrationFile())
  expect((await previewRequest).postDataJSON()).not.toHaveProperty('department_id')

  const rows = dialog.getByTestId('calibration-import-rows').locator('tbody tr')
  await expect(rows).toHaveCount(2)
  await expect(rows.nth(0)).toContainText('FT-301')
  await expect(rows.nth(0)).toContainText('合格')
  await expect(rows.nth(0)).toContainText('取り込む')
  await expect(rows.nth(1)).toContainText('取り込まない')
  await expect(rows.nth(1)).toContainText('計器が見つかりません')

  await dialog.getByRole('button', { name: '1件を下書きとして取り込む' }).click()
  const result = dialog.getByTestId('calibration-import-result')
  await expect(result).toContainText('1件を下書きとして取り込みました')

  await result.getByRole('link', { name: 'FT-301' }).click()
  await expect(page).toHaveURL(/\/inspections\/\d+$/)
  await expect(page.getByTestId('import-source')).toContainText('e2e-calibration.json')
  await expect(page.getByTestId('import-source')).toContainText('E2E キャリブレータ / E2E-001')
  await expect(page.getByTestId('detail-summary')).toContainText('FT-301')
})

test('校正の作業指示を書き出し、計画のIDを入れた結果を取り込むと、その計画の点検の下書きになる', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await openPlans(page, '点検の期限順')
  await page.getByRole('button', { name: '校正の作業指示', exact: true }).click()

  const dialog = page.getByTestId('calibration-work-order')
  const plan = 'FT-301 流量伝送器 年次校正'
  await dialog.getByRole('row', { name: new RegExp(plan) }).locator('input[type="checkbox"]').check()
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    dialog.getByRole('button', { name: /件を書き出す$/ }).click(),
  ])
  expect(download.suggestedFilename()).toMatch(/^calibration-work-orders-\d{8}-\d{4}\.json$/)
  await expect(dialog.getByTestId('calibration-work-order-result')).toContainText('書き出しました')
  const document = JSON.parse(readFileSync((await download.path())!, 'utf8'))
  expect(document.format).toBe('plant-keeper-calibration-work-order')
  const order = document.work_orders.find((o: any) => o.plan_name === plan)
  expect(order).toMatchObject({ site: '川崎製油所', tag_number: 'FT-301' })
  expect(order.calibration.tolerance_percent).toBe(0.5)
  await dialog.getByRole('button', { name: '閉じる' }).click()

  // 校正ソフトが返した結果として、作業指示の計画のIDを FT-301 の記録に入れて取り込む
  await page.getByRole('link', { name: '点検・作業記録', exact: true }).click()
  await page.getByRole('button', { name: '校正結果の取り込み' }).click()
  const importDialog = page.getByTestId('calibration-import')
  await importDialog.locator('input[type="file"]').setInputFiles(calibrationFile({ inspection_plan_id: order.inspection_plan_id }))
  const rows = importDialog.getByTestId('calibration-import-rows').locator('tbody tr')
  await expect(rows.nth(0)).toContainText(`計画: ${plan}`)
  await expect(rows.nth(0)).toContainText('取り込む')

  await importDialog.getByRole('button', { name: '1件を下書きとして取り込む' }).click()
  await importDialog.getByTestId('calibration-import-result').getByRole('link', { name: 'FT-301' }).click()
  await expect(page).toHaveURL(/\/inspections\/\d+$/)
  await expect(page.getByTestId('import-source')).toContainText('e2e-calibration.json')
})

for (const mobile of [false, true]) {
  test(`${mobile ? 'スマホ' : 'PC'}で取り込みの手順とエラーを確認し、開き直すとファイルをリセットする`, async ({ page }) => {
    if (mobile) await page.setViewportSize({ width: 390, height: 844 })
    await login(page, ACCOUNTS.member)
    await page.goto('/inspections')
    await page.getByRole('button', { name: '校正結果の取り込み' }).click()
    const dialog = page.getByTestId('calibration-import')
    await expect(dialog.getByRole('list', { name: '取り込みの手順' })).toBeVisible()
    await expect(dialog.getByRole('button', { name: '下書きとして取り込む', exact: true })).toBeDisabled()
    await dialog.getByText('初めて使う方へ・ファイルの用意').click()
    await expect(dialog.getByRole('button', { name: '見本のファイル' })).toBeVisible()
    await dialog.locator('input[type="file"]').setInputFiles({ name: 'invalid.json', mimeType: 'application/json', buffer: Buffer.from('invalid') })
    await expect(dialog.getByRole('alert')).toBeVisible()
    await dialog.locator('input[type="file"]').setInputFiles(calibrationFile())
    await expect(dialog.getByTestId('calibration-import-rows').locator('tbody tr')).toHaveCount(2)
    await expect(dialog.getByRole('button', { name: '1件を下書きとして取り込む' })).toBeEnabled()
    expect(await dialog.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(1)
    expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(1)
    await dialog.getByRole('button', { name: '閉じる', exact: true }).click()
    await page.getByRole('button', { name: '校正結果の取り込み' }).click()
    await expect(dialog.getByTestId('calibration-import-rows')).toHaveCount(0)
    await expect(dialog.getByRole('button', { name: '下書きとして取り込む', exact: true })).toBeDisabled()
  })
}

test('所属部署のない協力会社には部署選択だけを補い、選ぶまで取り込まない', async ({ page }) => {
  await login(page, { email: 'honda@example.com', password: 'password' })
  await page.goto('/inspections')
  await page.getByRole('button', { name: '校正結果の取り込み' }).click()
  const dialog = page.getByTestId('calibration-import')
  await expect(dialog.getByText('所属部署がないため、作業を依頼した部署を選んでください。')).toBeVisible()
  await dialog.locator('input[type="file"]').setInputFiles(calibrationFile())
  await expect(dialog.getByRole('button', { name: '下書きとして取り込む', exact: true })).toBeDisabled()
  const request = page.waitForRequest((request) => request.url().endsWith('/calibration_imports/preview'))
  // 単一選択後は確認中になり、追加のEscapeは親ダイアログを閉じるので送らない。
  await dialog.locator('.v-field', { has: page.getByLabel('記録する部署 *', { exact: true }) }).click()
  await page.getByRole('option').first().click()
  expect((await request).postDataJSON().department_id).toEqual(expect.any(Number))
  await expect(dialog.getByTestId('calibration-import-rows')).toBeVisible()
})

test('確認中に閉じて開き直すと、古い確認結果を表示しない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections')
  let release!: () => void
  const pending = new Promise<void>((resolve) => { release = resolve })
  await page.route('**/calibration_imports/preview', async (route) => {
    const response = await route.fetch()
    await pending
    await route.fulfill({ response })
  })
  await page.getByRole('button', { name: '校正結果の取り込み' }).click()
  const dialog = page.getByTestId('calibration-import')
  await dialog.locator('input[type="file"]').setInputFiles(calibrationFile())
  await expect(dialog.getByRole('status')).toContainText('ファイルを確認しています')
  await dialog.getByRole('button', { name: '閉じる', exact: true }).click()
  await page.getByRole('button', { name: '校正結果の取り込み' }).click()
  const response = page.waitForResponse((res) => res.url().endsWith('/calibration_imports/preview'))
  release()
  await response
  await expect(dialog.getByTestId('calibration-import-rows')).toHaveCount(0)
  await expect(dialog.getByRole('button', { name: '下書きとして取り込む', exact: true })).toBeDisabled()
})
