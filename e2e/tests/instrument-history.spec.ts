import type { Page } from '@playwright/test'
import { test, expect, login, openListRow, ACCOUNTS } from './support'

// トラブル管理から、同じ計器の過去のトラブル・点検をたどれる（AIを使わない導線）。
// シードの計器 FT-301（トラブル2件「オリフィス閉塞疑い」「配線断線」・点検1件）を使う。何も保存しないので、繰り返し実行してもデータは増えない
test('トラブル詳細に、この計器の過去のトラブルと点検が出る（自分自身は除く）。行から詳細へ移れる', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await openListRow(page, 'FT-301 オリフィス閉塞疑い')

  await page.getByRole('tab', { name: 'この計器の履歴' }).click() // 関連の一覧はタブ（詳細は「頭 → 概要 → タブ」）
  const section = page.getByTestId('instrument-history')
  await expect(section).toBeVisible()
  const troubles = section.getByTestId('instrument-history-troubles')
  await expect(troubles).toContainText('FT-301 配線断線')
  await expect(troubles).not.toContainText('FT-301 オリフィス閉塞疑い') // 開いているトラブル自身は出ない
  await expect(section.getByTestId('instrument-history-inspections').getByTestId('instrument-history-row').first()).toBeVisible()

  // 過去のトラブルの行から、そのトラブルの詳細へ
  await troubles.getByTestId('instrument-history-row').filter({ hasText: 'FT-301 配線断線' }).click()
  await expect(page).toHaveURL(/\/troubles\/\d+$/)
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('FT-301 配線断線')
})

test('計器のリンクから計器の詳細へ移り、履歴の「すべて見る」で、その計器で絞り込んだ一覧を開ける（×で外せる）', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await openListRow(page, 'FT-301 オリフィス閉塞疑い')

  // 詳細画面の計器のリンク（情報欄）から、計器の詳細へ。Ctrl/Cmd-クリックなら、今の画面を残して新しいタブで開く
  const instrumentLink = page.getByRole('link', { name: 'FT-301', exact: true }).first()
  const [newTab] = await Promise.all([page.context().waitForEvent('page'), instrumentLink.click({ modifiers: ['ControlOrMeta'] })])
  await expect(newTab).toHaveURL(/\/instruments\/\d+$/)
  await newTab.close()
  await expect(page).toHaveURL(/\/troubles\/\d+$/)
  await instrumentLink.click()
  await expect(page).toHaveURL(/\/instruments\/\d+$/)

  // 計器の詳細のトラブル履歴。行は詳細へのリンク
  await page.getByRole('tab', { name: 'トラブル履歴' }).click()
  const history = page.getByTestId('instrument-history-troubles')
  await expect(history.getByTestId('instrument-history-row').filter({ hasText: 'FT-301 オリフィス閉塞疑い' })).toBeVisible()
  await expect(history.getByTestId('instrument-history-row').filter({ hasText: 'FT-301 配線断線' })).toBeVisible()

  // すべて見る → その計器で絞り込んだトラブル一覧（全拠点）
  await history.getByTestId('instrument-history-all').click()
  await expect(page).toHaveURL(/\/troubles\?.*instrument_id=\d+/)
  await expect(page).toHaveURL(/site_ids=all/)
  const chip = page.getByTestId('instrument-filter-chip')
  await expect(chip).toContainText('計器: FT-301')
  const rows = page.locator('tbody tr')
  await expect(rows.filter({ hasText: 'FT-301 配線断線' })).toBeVisible()
  for (const text of await rows.allInnerTexts()) expect(text).toContain('FT-301') // 別の計器は出ない

  // ×で計器の絞り込みを外すと、ほかの計器のトラブルも出る
  await chip.getByRole('button').click()
  await expect(chip).toHaveCount(0)
  await expect(rows.filter({ hasNotText: 'FT-301' }).first()).toBeVisible()
})

test('計器の詳細の点検履歴から、その計器で絞り込んだ点検一覧を開ける。トラブル一覧の計器の列から計器の詳細へ移れる', async ({ page }) => {
  await login(page, ACCOUNTS.member)

  // トラブル一覧の計器の列のリンクは、トラブルの詳細でなく、計器の詳細へ
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await page.getByRole('textbox', { name: 'タイトル検索' }).fill('FT-301 オリフィス閉塞疑い')
  const row = page.getByRole('row', { name: /FT-301 オリフィス閉塞疑い/ })
  await row.getByRole('link', { name: 'FT-301', exact: true }).click()
  await expect(page).toHaveURL(/\/instruments\/\d+$/)

  await page.getByRole('tab', { name: '点検履歴' }).click()
  const history = page.getByTestId('instrument-history-inspections')
  await expect(history.getByTestId('instrument-history-row').first()).toBeVisible()
  await history.getByTestId('instrument-history-all').click()

  await expect(page).toHaveURL(/\/inspections\?.*instrument_id=\d+/)
  await expect(page.getByTestId('instrument-filter-chip')).toContainText('計器: FT-301')
  await expect(page.locator('tbody tr').first()).toBeVisible()
})

// トラブル一覧の計器の列のリンクから、シードの計器 FT-301 の詳細へ
async function openFt301Page(page: Page) {
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await page.getByRole('textbox', { name: 'タイトル検索' }).fill('FT-301 オリフィス閉塞疑い')
  await page.getByRole('row', { name: /FT-301 オリフィス閉塞疑い/ }).getByRole('link', { name: 'FT-301', exact: true }).click()
  await expect(page).toHaveURL(/\/instruments\/\d+$/)
}

test('計器で絞り込んだ一覧を開いたまま、サイドバーから開き直すと、絞り込みが外れる（トラブル一覧・点検一覧）', async ({ page }) => {
  await login(page, ACCOUNTS.member)

  // トラブル一覧: 同じ一覧のままクエリだけが変わる（画面は使い回される）。絞り込みの印が消え、ほかの計器のトラブルも並ぶ
  await openFt301Page(page)
  await page.getByRole('tab', { name: 'トラブル履歴' }).click()
  await page.getByTestId('instrument-history-troubles').getByTestId('instrument-history-all').click()
  await expect(page.getByTestId('instrument-filter-chip')).toBeVisible()
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await expect(page).toHaveURL(/\/troubles$/)
  await expect(page.getByTestId('instrument-filter-chip')).toHaveCount(0)
  await expect(page.locator('tbody tr').filter({ hasNotText: 'FT-301' }).first()).toBeVisible()

  // 点検一覧も同じ
  await openFt301Page(page)
  await page.getByRole('tab', { name: '点検履歴' }).click()
  await page.getByTestId('instrument-history-inspections').getByTestId('instrument-history-all').click()
  await expect(page.getByTestId('instrument-filter-chip')).toBeVisible()
  await page.getByRole('link', { name: '点検・作業記録', exact: true }).click()
  await expect(page).toHaveURL(/\/inspections$/)
  await expect(page.getByTestId('instrument-filter-chip')).toHaveCount(0)
})
