import type { Page } from '@playwright/test'
import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'

// トラブル管理から、同じ計器の過去のトラブル・点検をたどれる（AIを使わない導線）。
// 履歴は新しい順に5件だけ出すため、シードの計器 FT-301 のトラブルは、ほかのテスト（スマホの不具合報告など）が FT-301 に足すトラブルに押し出されうる。
// そのため、トラブルの履歴を確かめるテストは、実行のたびにAPIで自分用の計器（タグ番号が `E2E-H` で始まる）と、そのトラブル2件・点検1件（`E2E ` で始まる）を作る

type HistoryData = { tag: string, older: { id: number, title: string }, newer: { id: number, title: string } }

async function createHistoryData(page: Page): Promise<HistoryData> {
  const api = apiBaseUrl()
  const loginRes = await page.request.post(`${api}/login`, { data: { user: ACCOUNTS.admin } })
  const headers = { Authorization: loginRes.headers()['authorization'] }
  const get = async (path: string) => (await page.request.get(`${api}${path}`, { headers })).json()
  const post = async (path: string, data: object) => {
    const res = await page.request.post(`${api}${path}`, { headers, data })
    expect(res.ok()).toBeTruthy()
    return (await res.json()).data
  }

  const me = (await get('/current_user')).user
  const equipments = (await get(`/equipments?per_page=1000&site_ids[]=${me.site_id}`)).data
  const equipment = equipments.find((e: any) => e.name === 'タンク設備') ?? equipments[0]
  const department = (await get(`/departments?site_id=${me.site_id}`)).data[0]
  const stamp = Date.now()
  const tag = `E2E-H${stamp}`
  const instrument = await post('/instruments', { instrument: { equipment_id: equipment.id, tag_number: tag, instrument_type: 'pressure_transmitter' } })

  const trouble = async (title: string, reportedAt: Date) => ({
    id: (await post('/troubles', {
      trouble: { equipment_id: equipment.id, instrument_id: instrument.id, title, description: '計器の履歴の確認', priority: 'medium', reported_at: reportedAt.toISOString() },
    })).id,
    title,
  })
  const older = await trouble(`E2E ${stamp} 履歴 配線断線`, new Date(Date.now() - 24 * 60 * 60 * 1000))
  const newer = await trouble(`E2E ${stamp} 履歴 指示低下`, new Date())
  await post('/inspections', {
    inspection: { equipment_id: equipment.id, instrument_id: instrument.id, department_id: department.id, inspection_type: 'routine', status: 'draft', inspected_at: new Date().toISOString(), notes: `E2E ${stamp} 計器の履歴の確認` },
  })
  return { tag, older, newer }
}

test('トラブル詳細に、この計器の過去のトラブルと点検が出る（自分自身は除く）。行から詳細へ移れる', async ({ page }) => {
  const data = await createHistoryData(page)
  await login(page, ACCOUNTS.member)
  await page.goto(`/troubles/${data.newer.id}`)
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(data.newer.title)

  await page.getByRole('tab', { name: 'この計器の履歴' }).click() // 関連の一覧はタブ（詳細は「頭 → 概要 → タブ」）
  const section = page.getByTestId('instrument-history')
  await expect(section).toBeVisible()
  const troubles = section.getByTestId('instrument-history-troubles')
  await expect(troubles).toContainText(data.older.title)
  await expect(troubles).not.toContainText(data.newer.title) // 開いているトラブル自身は出ない
  await expect(section.getByTestId('instrument-history-inspections').getByTestId('instrument-history-row').first()).toBeVisible()

  // 過去のトラブルの行から、そのトラブルの詳細へ
  await troubles.getByTestId('instrument-history-row').filter({ hasText: data.older.title }).click()
  await expect(page).toHaveURL(new RegExp(`/troubles/${data.older.id}$`))
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(data.older.title)
})

test('計器のリンクから計器の詳細へ移り、履歴の「すべて見る」で、その計器で絞り込んだ一覧を開ける（×で外せる）', async ({ page }) => {
  const data = await createHistoryData(page)
  await login(page, ACCOUNTS.member)
  await page.goto(`/troubles/${data.newer.id}`)

  // 詳細画面の計器のリンク（情報欄）から、計器の詳細へ。Ctrl/Cmd-クリックなら、今の画面を残して新しいタブで開く
  const instrumentLink = page.getByRole('link', { name: data.tag, exact: true }).first()
  const [newTab] = await Promise.all([page.context().waitForEvent('page'), instrumentLink.click({ modifiers: ['ControlOrMeta'] })])
  await expect(newTab).toHaveURL(/\/instruments\/\d+$/)
  await newTab.close()
  await expect(page).toHaveURL(/\/troubles\/\d+$/)
  await instrumentLink.click()
  await expect(page).toHaveURL(/\/instruments\/\d+$/)

  // 計器の詳細のトラブル履歴。行は詳細へのリンク
  await page.getByRole('tab', { name: 'トラブル履歴' }).click()
  const history = page.getByTestId('instrument-history-troubles')
  await expect(history.getByTestId('instrument-history-row').filter({ hasText: data.newer.title })).toBeVisible()
  await expect(history.getByTestId('instrument-history-row').filter({ hasText: data.older.title })).toBeVisible()

  // すべて見る → その計器で絞り込んだトラブル一覧（全拠点）
  await history.getByTestId('instrument-history-all').click()
  await expect(page).toHaveURL(/\/troubles\?.*instrument_id=\d+/)
  await expect(page).toHaveURL(/site_ids=all/)
  const chip = page.getByTestId('instrument-filter-chip')
  await expect(chip).toContainText(`計器: ${data.tag}`)
  const rows = page.locator('tbody tr')
  await expect(rows.filter({ hasText: data.older.title })).toBeVisible()
  await expect(rows).toHaveCount(2) // 別の計器のトラブルは出ない

  // ×で計器の絞り込みを外すと、ほかの計器のトラブルも出る
  await chip.getByRole('button').click()
  await expect(chip).toHaveCount(0)
  await expect(rows.filter({ hasNotText: data.tag }).first()).toBeVisible()
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
