import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'

// 詳細画面の頭（DetailHeader）と状態チップの規則（StatusChip）。デザインガイド「詳細画面」「状態の表示」
test('どの詳細画面も、戻る → 種類 → 名前の同じ形の頭で始まる', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  const token = await page.evaluate(() => localStorage.getItem('jwt'))
  const get = async (path: string) => (await (await page.request.get(`${apiBaseUrl()}${path}`, { headers: { Authorization: `Bearer ${token}` } })).json()).data
  const first = async (path: string) => (await get(path))[0]
  const details: [string, string, string][] = [
    ['トラブル', `/troubles/${(await first('/troubles?per_page=1')).id}`, 'トラブル管理'],
    ['点検記録', `/inspections/${(await first('/inspections?per_page=1')).id}`, '点検・作業記録'],
    ['設備', `/equipments/${(await first('/equipments?per_page=1')).id}`, '設備台帳'],
    ['計器', `/instruments/${(await first('/instruments?per_page=1')).id}`, '装置・計器'],
    ['インターロック', `/interlocks/${(await first('/interlocks?per_page=1')).id}`, 'インターロック'],
    ['定期整備', `/maintenances/${(await first('/scheduled_maintenances?per_page=1')).id}`, '計画'],
    ['基準器', `/reference-standards/${(await first('/reference_standards?per_page=1')).id}`, '基準器'],
    ['資材', `/materials/${(await first('/materials?per_page=1')).id}`, '資材管理'],
    ['在庫', `/stocks/${(await first('/stocks?per_page=1')).id}`, '在庫管理'],
    ['修理', `/repairs/${(await first('/repairs?per_page=1')).id}`, '修理管理'],
    ['拠点', `/sites/${(await first('/sites?per_page=1')).id}`, '拠点管理'],
    ['ユーザ', `/users/${(await get('/users'))[0].id}`, 'ユーザ管理'],
  ]
  for (const [kind, path, back] of details) {
    await test.step(kind, async () => {
      await page.goto(path)
      const header = page.locator('.pk-detail-header')
      await expect(header.locator('.pk-detail-header__kind')).toHaveText(kind)
      await expect(header.getByRole('heading', { level: 1 })).not.toBeEmpty()
      await expect(header.getByRole('link', { name: `${back}に戻る` })).toBeVisible()
    })
  }
})

test('状態のチップは淡い色で、緊急だけ塗りつぶす。トラブル詳細のタブは URL で保たれる', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/troubles?priority=critical,medium')
  const critical = page.locator('tbody tr .pk-status-chip', { hasText: /^緊急$/ }).first()
  const medium = page.locator('tbody tr .pk-status-chip', { hasText: /^中$/ }).first()
  await expect(critical).toHaveClass(/v-chip--variant-flat/)
  await expect(medium).toHaveClass(/v-chip--variant-tonal/)

  await page.locator('tbody tr').first().click({ position: { x: 8, y: 8 } })
  await expect(page).toHaveURL(/\/troubles\/\d+$/)
  await page.getByRole('tab', { name: '変更履歴' }).click()
  await expect(page).toHaveURL(/tab=changes/)
  await page.reload()
  await expect(page.getByRole('tab', { name: '変更履歴' })).toHaveAttribute('aria-selected', 'true')
})
