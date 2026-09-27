import { test, expect, login, apiBaseUrl, selectFirstOption, ACCOUNTS, selectOption, openPlans } from './support'
import type { Page } from '@playwright/test'

const WORKER = { email: 'honda@example.com', password: 'password' }

async function apiGet(page: Page, path: string) {
  const token = await page.evaluate(() => localStorage.getItem('jwt'))
  const res = await page.request.get(`${apiBaseUrl()}${path}`, { headers: { Authorization: `Bearer ${token}` } })
  expect(res.ok()).toBeTruthy()
  return (await res.json()).data
}

// 基準器（校正に使う圧力校正器・マルチテスタなど）の台帳: 校正の状態（期限切れ・期限間近・不合格）が一覧で分かる。
// シードの基準器に依存する（川崎製油所: RS-KW-001〜007）
test('基準器の一覧で、校正の状態（期限切れ・期限間近・不合格・校正済み）と最終校正が分かり、キーワードで絞り込める', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '基準器', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '基準器' })).toBeVisible()

  const row = (number: string) => page.locator('tbody tr', { hasText: number })
  await expect(row('RS-KW-001').locator('.v-chip', { hasText: '校正済み' })).toBeVisible()
  await expect(row('RS-KW-002').locator('.v-chip', { hasText: '期限間近' })).toBeVisible()
  await expect(row('RS-KW-003').locator('.v-chip', { hasText: '期限切れ' })).toBeVisible()
  await expect(row('RS-KW-007').locator('.v-chip', { hasText: '校正不合格' })).toBeVisible()
  await expect(row('RS-KW-006').locator('.v-chip', { hasText: '校正中' })).toBeVisible()
  await expect(row('RS-KW-001')).toContainText('計測機器メーカー 校正センター')

  await page.getByRole('textbox', { name: '管理番号・名称・型式・製造番号' }).fill('デッドウェイト')
  await expect(page.locator('tbody tr')).toHaveCount(1)
  await expect(row('RS-KW-004')).toBeVisible()
})

test('基準器の詳細に校正の履歴が出て、最新の校正が不合格なら、影響を確認すべき点検が示される', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '基準器', exact: true }).click()
  await page.locator('tbody tr', { hasText: 'RS-KW-007' }).click()

  await expect(page.getByTestId('calibration-impact')).toContainText('この基準器を使った点検が')
  await expect(page.getByRole('row', { name: /CAL-K-0619.*不合格/ })).toBeVisible()
  await expect(page.getByRole('row', { name: /CAL-K-0118.*合格（メーカー点検済み）/ })).toBeVisible()

  await page.getByRole('tab', { name: '使った点検' }).click()
  await expect(page.locator('tbody tr', { hasText: '影響あり' })).toHaveCount(1)
})

test('基準器の年次校正が点検計画に載り、「校正を記録」で基準器の校正記録ダイアログが開く（記録はしない）', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await openPlans(page, '点検の期限順')

  const plan = page.locator('tbody tr', { hasText: '温度校正器（ドライブロック） 年次校正' })
  await expect(plan.locator('.v-chip', { hasText: '基準器' })).toBeVisible()
  await expect(plan).toContainText('日超過') // 校正の有効期限が切れている
  await plan.getByRole('button', { name: '校正を記録' }).click()

  await expect(page).toHaveURL(/\/reference-standards\/\d+\?record=1/)
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByText('校正を記録').first()).toBeVisible()
  await expect(dialog.getByLabel('有効期限 *')).not.toHaveValue('')
  await expect(dialog.getByLabel('校正した機関（メーカー）*')).toHaveValue('計測機器メーカー 校正センター')
})

test('協力会社の技能員も基準器を見られるが、登録・編集・校正の記録はできない', async ({ page }) => {
  await login(page, WORKER)
  await page.getByRole('link', { name: '基準器', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '基準器' })).toBeVisible()
  await expect(page.getByRole('button', { name: '新規登録' })).toHaveCount(0)
  await page.locator('tbody tr').first().click()
  await expect(page.getByRole('heading', { level: 1 }).or(page.getByTestId('calibration-state'))).toBeVisible()
  await expect(page.getByRole('button', { name: '校正を記録' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: '編集' })).toHaveCount(0)
})

// 保存はしない。点検日に使えない基準器（期限切れ）や、取引用の計器に使えない基準器（トレーサビリティなし）が、選んだ時点で分かる
test('点検で基準器を選ぶと、点検日に使えるかが分かり、使えない基準器を含めると提出できない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections/new')
  await expect(page.getByRole('heading', { level: 1, name: '新規点検記録' })).toBeVisible()
  await selectOption(page, '設備 *', '常圧蒸留装置')
  await selectFirstOption(page, '部署 *')

  const section = page.getByTestId('reference-standards-section')
  const addStandard = async (number: string) => {
    await section.getByRole('combobox').first().click()
    await page.getByRole('option', { name: new RegExp(number) }).click()
  }

  await test.step('有効な基準器は理由なしで、校正した機関・証明書番号・有効期限が出る', async () => {
    await addStandard('RS-KW-001')
    const valid = section.getByTestId('reference-standard-RS-KW-001')
    await expect(valid).toContainText('CAL-K-0142')
    await expect(valid.locator('.text-error')).toHaveCount(0)
    await expect(valid).toContainText('未確認') // 使用前の1点チェックは、OK/NGを選ぶまで未確認
    await valid.getByRole('button', { name: 'OK', exact: true }).click()
    await expect(valid).not.toContainText('未確認')
    // もう一度押して選択を外すと、未確認に戻る（表示も、送る値も）
    await valid.getByRole('button', { name: 'OK', exact: true }).click()
    await expect(valid).toContainText('未確認')
    await valid.getByRole('button', { name: 'OK', exact: true }).click()
    await expect(valid).not.toContainText('未確認')
  })

  await test.step('校正の有効期限が切れた基準器は、使えない理由が出る', async () => {
    await addStandard('RS-KW-003')
    await expect(section.getByTestId('reference-standard-RS-KW-003').locator('.text-error')).toContainText('有効期限')
  })

  await test.step('提出すると、使えない基準器が理由つきで拒否され、点検は保存されない', async () => {
    await section.getByTestId('reference-standard-RS-KW-003').getByRole('button', { name: 'OK', exact: true }).click()
    await page.getByRole('button', { name: '提出' }).click()
    await expect(page.getByRole('alert').filter({ hasText: '有効期限' })).toContainText('RS-KW-003')
    await expect(page).toHaveURL(/\/inspections\/new/)
  })

  await test.step('基準器を外せる', async () => {
    await section.getByTestId('reference-standard-RS-KW-003').getByRole('button', { name: '基準器を外す' }).click()
    await expect(section.getByTestId('reference-standard-RS-KW-003')).toHaveCount(0)
  })
})

test('取引用の計器の点検では、トレーサビリティのない基準器は使えないと分かる', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections/new')
  await selectOption(page, '設備 *', 'タンク設備')
  await selectOption(page, '計器（任意）', 'LT-1001')

  const section = page.getByTestId('reference-standards-section')
  await expect(section).toContainText('取引用の計器が含まれるため')
  await section.getByRole('combobox').first().click()
  await page.getByRole('option', { name: /RS-KW-005/ }).click()
  await expect(section.getByTestId('reference-standard-RS-KW-005').locator('.text-error')).toContainText('トレーサビリティ')
  await section.getByRole('combobox').first().click()
  await page.getByRole('option', { name: /RS-KW-004/ }).click()
  await expect(section.getByTestId('reference-standard-RS-KW-004').locator('.text-error')).toHaveCount(0)
})

// シードの記録: FT-301の年次校正で、圧力校正器とマルチテスタを使用前の1点チェックのうえ使った。無い環境（シード前のstgなど）ではスキップ
test('承認済みの5点校正の記録に、使用した基準器と点検日時点の校正・使用前の1点チェックが表示される', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  const instruments = (await apiGet(page, '/instruments?q=FT-301')).filter((i: any) => i.tag_number === 'FT-301')
  const inspections = instruments.length ? await apiGet(page, `/inspections?instrument_id=${instruments[0].id}&per_page=100`) : []
  // 同じチェックリストの下書き（校正結果の取り込みのE2Eが残す）と取り違えないよう、承認済みに絞る
  const calibration = inspections.find((i: any) => i.checklist_template?.name === '伝送器 年次点検' && i.status === 'approved')
  const detail = calibration ? await apiGet(page, `/inspections/${calibration.id}`) : null
  test.skip(!detail?.inspection_reference_standards?.length, 'シードの基準器の使用実績がない環境')

  await page.goto(`/inspections/${calibration.id}?tab=standards`)
  const used = page.getByTestId('reference-standards-used')
  await expect(used).toContainText('RS-KW-001')
  await expect(used).toContainText('CAL-K-0142')
  await expect(used).toContainText('トレーサビリティあり')
  await expect(used.getByRole('row', { name: /RS-KW-002/ })).toContainText('OK')
  await used.getByText(/RS-KW-001/).first().click()
  await expect(page).toHaveURL(/\/reference-standards\/\d+/)
})
