import { test, expect, login } from './support'
import type { Page } from '@playwright/test'

// 資材マスタは全拠点共通。自拠点になければ他拠点にあるかを、同じ行で探せる（シードの資材・在庫に依存する）
const ACCOUNTS = {
  ownerManager: { email: 'yamamoto@example.com', password: 'password' }, // 川崎製油所
  contractorManager: { email: 'yoshida@example.com', password: 'password' },
}

async function openMaterials(page: Page) {
  await page.getByRole('link', { name: '資材管理', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '資材管理' })).toBeVisible()
}

// 一覧の行をクリックして詳細画面を開く（初期表示の再描画でクリックが空振りすることがあるため、遷移するまでリトライする）
async function openMaterialDetail(page: Page, partNumber: RegExp) {
  await expect(async () => {
    await page.getByRole('row', { name: partNumber }).click()
    await expect(page).toHaveURL(/\/materials\/\d+$/, { timeout: 2_000 })
  }).toPass({ timeout: 15_000 })
}

async function pickStockFilter(page: Page, option: string) {
  await page.locator('.v-field', { has: page.getByLabel('在庫', { exact: true }) }).click()
  await page.getByRole('option', { name: option }).click()
}

test('自社は資材ごとの自拠点・他拠点の在庫が見え、自拠点になくて他拠点にある資材を絞り込める', async ({ page }) => {
  await login(page, ACCOUNTS.ownerManager)
  await openMaterials(page)

  await expect(page.getByRole('columnheader', { name: '自拠点の在庫' })).toBeVisible()
  await expect(page.getByRole('columnheader', { name: '他拠点の在庫' })).toBeVisible()

  // 他拠点にだけ在庫がある資材（レベル伝送器は堺・和歌山にだけある）
  await pickStockFilter(page, '他拠点にだけ在庫あり')
  const transmitter = page.getByRole('row', { name: /3301HA/ })
  await expect(transmitter).toBeVisible()
  await expect(transmitter).toContainText('堺')
  await expect(transmitter).toContainText('和歌山')
  await expect(page.getByRole('row', { name: /GK-NB10/ })).toHaveCount(0)

  // 自拠点に在庫がある資材
  await pickStockFilter(page, '自拠点に在庫あり')
  await expect(page.getByRole('row', { name: /GK-NB10/ })).toBeVisible()
  await expect(page.getByRole('row', { name: /3301HA/ })).toHaveCount(0)

  // 詳細画面では、拠点付きの倉庫ごとの在庫が見える
  await pickStockFilter(page, '他拠点にだけ在庫あり')
  await openMaterialDetail(page, /3301HA/)
  await expect(page.getByRole('heading', { name: '在庫状況' })).toBeVisible()
  await expect(page.getByRole('cell', { name: /堺製油所 堺第1倉庫/ })).toBeVisible()
  await expect(page.getByRole('cell', { name: /和歌山製油所 和歌山倉庫/ })).toBeVisible()
})

test('在庫を見られない協力会社には、資材の在庫の列・絞り込み・在庫状況が出ない', async ({ page }) => {
  await login(page, ACCOUNTS.contractorManager)
  await openMaterials(page)

  await expect(page.getByRole('columnheader', { name: '型番' })).toBeVisible()
  await expect(page.getByRole('columnheader', { name: '自拠点の在庫' })).toHaveCount(0)
  await expect(page.getByRole('columnheader', { name: '他拠点の在庫' })).toHaveCount(0)
  await expect(page.getByLabel('在庫', { exact: true })).toHaveCount(0)

  await openMaterialDetail(page, /3301HA/)
  // 詳細画面は開けるが、在庫状況は出ない（最近の発注は出る）
  await expect(page.getByRole('heading', { name: '最近の発注' })).toBeVisible()
  await expect(page.getByRole('heading', { name: '在庫状況' })).toHaveCount(0)
})
