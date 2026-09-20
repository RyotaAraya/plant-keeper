import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'
import type { Page } from '@playwright/test'

// FT-301（差圧式の流量計）: 差圧0〜100kPa・許容差±0.5%・伝送器は比例出力（4-20mA）・DCSは平方根（0〜500t/h）
const POINTS = [0, 25, 50, 75, 100]
const EXPECTED_OUTPUT = [4, 8, 12, 16, 20]
const EXPECTED_DCS = POINTS.map((p) => 500 * Math.sqrt(p / 100))

async function apiGet(page: Page, path: string) {
  const token = await page.evaluate(() => localStorage.getItem('jwt'))
  const res = await page.request.get(`${apiBaseUrl()}${path}`, { headers: { Authorization: `Bearer ${token}` } })
  expect(res.ok()).toBeTruthy()
  return (await res.json()).data
}

// Vuetifyのv-selectは入力要素が覆われているため、入力欄（.v-field）を操作して名前で選ぶ
async function selectOption(page: Page, label: string, optionName: string) {
  await page.locator('.v-field', { has: page.getByLabel(label, { exact: true }) }).click()
  await page.getByRole('option', { name: optionName }).click()
}

test('計器の詳細に校正の条件が表示され、編集ダイアログで校正範囲・許容差・DCS換算を設定できる', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '装置・計器', exact: true }).click()
  await page.getByRole('textbox', { name: 'タグ番号・種別・設置場所' }).fill('FT-301')
  await page.locator('tbody tr', { hasText: 'FT-301' }).first().click()

  const conditions = page.getByTestId('calibration-conditions')
  await expect(conditions).toContainText('0〜100 kPa')
  await expect(conditions).toContainText('許容差 ±0.5%スパン')
  await expect(conditions).toContainText('DCS 平方根')

  await page.getByRole('button', { name: '編集' }).click()
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByLabel('校正範囲 上限')).toHaveValue('100')
  await expect(dialog.getByLabel('許容差（%スパン）')).toHaveValue('0.5')
  await expect(dialog.getByLabel('DCS範囲 上限')).toHaveValue('500')
  await expect(dialog.getByLabel('取引用（トレーサビリティが必要）')).not.toBeChecked()
})

test('計器一覧の区分に、テレメータ計器と取引用の計器が表示される', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '装置・計器', exact: true }).click()
  const search = page.getByRole('textbox', { name: 'タグ番号・種別・設置場所' })

  await search.fill('FT-701')
  await expect(page.locator('tbody tr', { hasText: 'FT-701' }).first().locator('.v-chip', { hasText: 'テレメータ' })).toBeVisible()
  await search.fill('LT-1001')
  await expect(page.locator('tbody tr', { hasText: 'LT-1001' }).first().locator('.v-chip', { hasText: '取引用' })).toBeVisible()
})

// 保存はしない（データを増やさない）。判定はバックエンドのテストが検証し、ここでは画面の計算が同じ結果になることを確かめる
test('点検で5点校正を入力すると、期待値どおりなら合格、許容差を超えると不合格と表示される', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections/new')
  await expect(page.getByRole('heading', { level: 1, name: '新規点検記録' })).toBeVisible()

  await selectOption(page, '設備 *', '常圧蒸留装置')
  await selectOption(page, '計器（任意）', 'FT-301')
  await selectOption(page, 'テンプレート（任意）', '伝送器 年次点検')

  await expect(page.getByText('許容差 ±0.5%スパン')).toBeVisible()
  await expect(page.getByTestId('calibration-result')).toContainText('未入力')

  for (const [i, percent] of POINTS.entries()) {
    for (const dir of ['上昇', '下降']) {
      await page.getByLabel(`調整前 ${percent}% ${dir} 出力`).fill(String(EXPECTED_OUTPUT[i]))
      await page.getByLabel(`調整前 ${percent}% ${dir} DCS`).fill(String(EXPECTED_DCS[i]))
    }
  }
  await expect(page.getByTestId('calibration-result')).toContainText('合格')

  await test.step('25%の上昇の出力が8.2mA（+1.25%）だと不合格', async () => {
    await page.getByLabel('調整前 25% 上昇 出力').fill('8.2')
    await expect(page.getByTestId('calibration-result')).toContainText('不合格')
    await expect(page.getByText('NG').first()).toBeVisible()
  })

  await test.step('調整して調整後が許容内なら、最終判定は合格に戻る', async () => {
    await page.getByLabel('調整した（調整後の値も記録）').check()
    await page.getByRole('button', { name: /調整後/ }).click()
    for (const [i, percent] of POINTS.entries()) {
      for (const dir of ['上昇', '下降']) {
        await page.getByLabel(`調整後 ${percent}% ${dir} 出力`).fill(String(EXPECTED_OUTPUT[i]))
        await page.getByLabel(`調整後 ${percent}% ${dir} DCS`).fill(String(EXPECTED_DCS[i]))
      }
    }
    await expect(page.getByTestId('calibration-result')).toContainText('合格')
    await page.getByRole('button', { name: /調整前/ }).click()
    await expect(page.getByText('NG').first()).toBeVisible() // 調整前は不合格のまま残る
  })
})

// シードの記録: 調整前は高流量側で不合格、スパンを調整して調整後は合格（承認済み）。校正の記録が無い環境（シード前のstgなど）ではスキップ
test('承認済みの5点校正の記録に、調整前（不合格）と調整後（合格）の表と最終判定が表示される', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  const instruments = (await apiGet(page, '/instruments?q=FT-301')).filter((i: any) => i.tag_number === 'FT-301')
  const inspections = instruments.length ? await apiGet(page, `/inspections?instrument_id=${instruments[0].id}&per_page=100`) : []
  const calibration = inspections.find((i: any) => i.checklist_template?.name === '伝送器 年次点検')
  test.skip(!calibration, 'シードの5点校正の記録がない環境')

  await page.goto(`/inspections/${calibration.id}`)
  await expect(page.getByTestId('calibration-result')).toContainText('最終判定: 合格')
  await expect(page.getByRole('row', { name: /5点校正/ })).toContainText('合格')

  await page.getByRole('button', { name: /調整前/ }).click()
  await expect(page.getByText('NG').first()).toBeVisible()
  await page.getByRole('button', { name: /調整後/ }).click()
  await expect(page.getByText('NG')).toHaveCount(0)
  await expect(page.locator('.pk-calibration tbody tr').filter({ hasText: '100%' }).first()).toContainText('OK')
})
