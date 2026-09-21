import { test, expect, login, ACCOUNTS, selectOption } from './support'

test('組織を階層で選べ、親の変更で子が解除され、定期整備は拠点全体のまま', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await expect(page.getByRole('heading', { name: '保全部の要対応' })).toBeVisible()
  const maintenanceCounts = await page.locator('.pk-maintenance__stats').innerText()

  await selectOption(page, '課', '計装保全課', { exact: true })
  await selectOption(page, 'チーム', '計器Aチーム', { exact: true })
  await expect(page.getByRole('heading', { name: '計器Aチームの要対応' })).toBeVisible()
  await expect(page.locator('.pk-maintenance__stats')).toHaveText(maintenanceCounts, { useInnerText: true })

  await selectOption(page, '課', '電気保全課', { exact: true })
  await expect(page.getByRole('heading', { name: '電気保全課の要対応' })).toBeVisible()
  await expect(page.getByRole('combobox', { name: 'チーム', exact: true })).toHaveValue('すべて')

  await selectOption(page, '拠点', '根岸製油所', { exact: true })
  await expect(page.getByRole('heading', { name: '拠点全体の要対応' })).toBeVisible()
  await expect(page.getByRole('combobox', { name: '部', exact: true })).toHaveValue('すべて')
  await expect(page.getByRole('combobox', { name: '課', exact: true })).toBeDisabled()
  await expect(page.getByRole('combobox', { name: 'チーム', exact: true })).toBeDisabled()
  await expect(page.getByRole('region', { name: '拠点の定期整備' })).toContainText('根岸製油所全体')

  // 拠点全体のリンクも選んだ拠点を引き継ぐ。
  await page.getByRole('link', { name: 'すべて見る', exact: true }).click()
  await expect(page.getByRole('button', { name: '表示する拠点を選ぶ' })).toContainText('根岸製油所')
  await page.goBack()
  await selectOption(page, '拠点', '根岸製油所', { exact: true })
  await page.getByRole('button', { name: '自分の所属に戻す' }).click()
  await expect(page.getByRole('combobox', { name: '拠点', exact: true })).toHaveValue('川崎製油所')
  await expect(page.getByRole('combobox', { name: '部', exact: true })).toHaveValue('保全部')
  await expect(page.getByRole('heading', { name: '保全部の要対応' })).toBeVisible()

  await selectOption(page, '拠点', '全拠点', { exact: true })
  await expect(page.getByRole('heading', { name: '全拠点の要対応' })).toBeVisible()
})

test('チーム所属の人は自分のチームから始まり、協力会社は拠点全体から始まる', async ({ page, browser }) => {
  await login(page, ACCOUNTS.member)
  await expect(page.getByRole('heading', { name: '計器Aチームの要対応' })).toBeVisible()
  await expect(page.getByRole('combobox', { name: '課', exact: true })).toHaveValue('計装保全課')
  await expect(page.getByRole('combobox', { name: 'チーム', exact: true })).toHaveValue('計器Aチーム')

  const context = await browser.newContext()
  const contractor = await context.newPage()
  await login(contractor, { email: 'honda@example.com', password: 'password' })
  await expect(contractor.getByRole('heading', { name: '拠点全体の要対応' })).toBeVisible()
  await expect(contractor.getByRole('combobox', { name: '拠点', exact: true })).toHaveCount(0)
  await expect(contractor.getByRole('region', { name: '表示する組織を選ぶ' })).toContainText('川崎製油所')
  await context.close()
})

test('取得に失敗した場合は古い数字を出さず、再読み込みで復帰できる', async ({ page }) => {
  await page.route('**/api/v1/dashboard?*', async (route) => { await route.abort('failed') }, { times: 1 })
  await login(page, ACCOUNTS.admin)
  await expect(page.getByRole('alert')).toContainText('ダッシュボードを読み込めませんでした')
  await expect(page.getByRole('link', { name: /未対応トラブル/ })).toHaveCount(0)
  await page.getByRole('button', { name: '再読み込み', exact: true }).click()
  await expect(page.getByRole('link', { name: /未対応トラブル/ })).toBeVisible()
  await expect(page.getByRole('alert')).toHaveCount(0)
})
