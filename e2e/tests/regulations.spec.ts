import { test, expect, login, ACCOUNTS } from './support'

// 法規区分（高圧ガス・ボイラーなど）: 設備がどの法規の対象かが分かり、法定検査の周期が点検計画の起点になる。
// 適用法規の付け外しはデータを書き換えるため、ここでは表示までを確認する（付け外しはバックエンドのテストが検証）
test('設備台帳に適用法規が表示され、設備詳細の「適用法規」タブで法定検査の周期が見える', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '設備台帳', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '設備台帳' })).toBeVisible()

  await test.step('一覧の適用法規の列に区分が出る', async () => {
    await expect(page.getByRole('columnheader', { name: '適用法規' })).toBeVisible()
    await expect(page.locator('tbody tr').first().locator('.v-chip').first()).toBeVisible()
  })

  await test.step('ボイラー設備の詳細で、ボイラー・電気事業法の法定検査と周期が見える', async () => {
    await page.locator('tbody tr', { hasText: 'ボイラー設備' }).first().click()
    await expect(page).toHaveURL(/\/equipments\/\d+/)
    await page.getByRole('tab', { name: '適用法規' }).click()
    await expect(page.getByText('ボイラー・第一種圧力容器').last()).toBeVisible()
    await expect(page.getByRole('row', { name: /定期自主検査.*1か月ごと.*法定/ })).toBeVisible()
    await expect(page.getByRole('row', { name: /蒸気タービンの定期事業者検査.*4年ごと/ })).toBeVisible()
  })
})

test('点検計画の追加で設備を選ぶと、適用される法定検査が周期の目安として出て、押すと計画名と周期に入る', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '点検計画', exact: true }).click()
  await page.getByRole('button', { name: '計画を追加' }).click()

  // 「設備」は絞り込み欄にもあるため、ダイアログ内に限定して先頭の設備を選ぶ
  const dialog = page.getByRole('dialog')
  await dialog.locator('.v-field', { has: page.getByLabel('設備', { exact: true }) }).click()
  await page.getByRole('option').first().click()
  await expect(page.getByText('この設備に適用される法定検査')).toBeVisible()

  await dialog.locator('.v-chip', { hasText: /（.+）/ }).first().click()
  await expect(dialog.getByLabel('計画名')).not.toHaveValue('')
})
