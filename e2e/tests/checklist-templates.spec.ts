import { test, expect, login, ACCOUNTS } from './support'
import type { Page } from '@playwright/test'

async function selectOption(page: Page, label: string, optionName: string) {
  await page.locator('.v-field', { has: page.getByLabel(label, { exact: true }) }).click()
  await page.getByRole('option', { name: optionName }).click()
}

// チェックリストは「機器の種類 × 周期」（巡回・月次・年次・定修）。廃止した旧テンプレートは、点検の選択肢に出ない
test('設定のチェックリストに、機器の種類 × 周期のテンプレートが並び、項目数が多すぎない', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '設定', exact: true }).click()
  await page.getByRole('tab', { name: 'チェックリスト' }).click()

  // 1テンプレートの項目数は4〜12件（点検が過剰にならないように）
  for (const name of ['伝送器 巡回点検', '伝送器 月次点検', '伝送器 年次点検', '伝送器 定修点検', '調節弁 年次点検', '遮断弁・インターロック 年次点検', '安全弁 定修点検', 'タンク液面計 年次点検']) {
    const row = page.getByRole('row', { name: new RegExp(`^${name}`) })
    await expect(row, name).toBeVisible()
    const count = Number(await row.getByRole('cell').nth(3).innerText())
    expect(count, name).toBeGreaterThanOrEqual(4)
    expect(count, name).toBeLessThanOrEqual(12)
  }
})

test('点検フォームのテンプレートの選択肢は機器の種類 × 周期の名前で、旧テンプレート（〜チェックリスト）は出ない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections/new')
  await page.locator('.v-field', { has: page.getByLabel('テンプレート（任意）', { exact: true }) }).click()

  await expect(page.getByRole('option', { name: '伝送器 年次点検' })).toBeVisible()
  await expect(page.getByRole('option', { name: '安全弁 定修点検' })).toBeVisible()
  await expect(page.getByRole('option', { name: /チェックリスト/ })).toHaveCount(0)
})

test('運転中の点検（伝送器の月次）には、制御を手動にしたら戻す確認と、インターロックのバイパス申請番号・解除の項目がある', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections/new')
  await selectOption(page, '設備 *', '常圧蒸留装置')
  await selectOption(page, 'テンプレート（任意）', '伝送器 月次点検')

  await expect(page.locator('input[value^="ゼロ点確認"]')).toBeVisible()
  await expect(page.locator('input[value*="自動に戻したことを確認"]')).toBeVisible()
  await expect(page.locator('input[value*="バイパス申請番号"]')).toBeVisible()
  await expect(page.locator('input[value*="バイパスを解除し"]')).toBeVisible()
})

test('調節弁の年次点検では、ポジショナの5点校正の表が出る（調節弁の計器を選んだとき）', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspections/new')
  await selectOption(page, '設備 *', '常圧蒸留装置')
  await selectOption(page, '計器（任意）', 'PV-201')
  await selectOption(page, 'テンプレート（任意）', '調節弁 年次点検')

  await expect(page.getByText('調節弁のポジショナ')).toBeVisible()
  await expect(page.getByLabel('調整前 50% 上昇 出力')).toBeVisible()
})

test('点検計画から「点検を実施」を開くと、計画のテンプレートの項目が読み込まれる（ボイラー安全弁の年次点検）', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: '点検計画', exact: true }).click()
  const plan = page.locator('tbody tr', { hasText: 'ボイラー安全弁 年次点検' })
  await expect(plan).toBeVisible()
  await plan.getByRole('button', { name: '点検を実施' }).click()

  await expect(page.getByRole('heading', { level: 1, name: '新規点検記録' })).toBeVisible()
  await expect(page.locator('input[value*="吹出し圧力を記録"]')).toBeVisible()
  await expect(page.locator('input[value*="吹止まり圧力を記録"]')).toBeVisible()
})
