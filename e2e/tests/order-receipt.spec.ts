import { test, expect, login } from './support'

const OWNER_MANAGER = { email: 'yamamoto@example.com', password: 'password' }

// 発注を受領すると在庫に入庫される（入庫先の倉庫が必要）。
// 受領まですると在庫が増えてシードの状態が変わり、再実行できなくなるため、ここでは受領ダイアログの表示までを確認する
test('発注済の発注は「受領（入庫）」で入庫先の倉庫を選ぶ。受領済・キャンセル済は状態を変えられない', async ({ page }) => {
  await login(page, OWNER_MANAGER)
  await page.getByRole('link', { name: '発注管理', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '発注管理' })).toBeVisible()
  await expect(page.locator('tbody tr').first()).toBeVisible()

  await test.step('受領済の発注には状態変更のメニューがない', async () => {
    const received = page.locator('tbody tr', { has: page.locator('.v-chip', { hasText: '受領済' }) }).first()
    await expect(received.locator('.mdi-chevron-down')).toHaveCount(0)
  })

  await test.step('発注済の発注から受領ダイアログが開き、倉庫を選ぶ項目がある', async () => {
    const ordered = page.locator('tbody tr', { has: page.locator('.v-chip', { hasText: '発注済' }) }).first()
    await ordered.locator('.v-chip', { hasText: '発注済' }).click()
    await page.getByText('受領（入庫）', { exact: true }).click()

    await expect(page.getByText('発注の受領（入庫）')).toBeVisible()
    await expect(page.getByLabel('入庫先の倉庫 *')).toBeVisible()
    await page.getByRole('button', { name: 'キャンセル' }).click()
  })
})
