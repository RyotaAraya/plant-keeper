import { test, expect, login } from './support'
import type { Page } from '@playwright/test'

const ACCOUNTS = {
  ownerManager: { email: 'yamamoto@example.com', password: 'password' },
  ownerMember: { email: 'sato@example.com', password: 'password' },
  contractorWorker: { email: 'honda@example.com', password: 'password' },
}

// 承認待ちの点検の詳細画面を開く（一覧の部署フィルタは自分の所属が初期値のため外す）
async function openApprovalRequestedInspection(page: Page) {
  await page.getByRole('link', { name: '点検・作業記録', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '点検・作業記録' })).toBeVisible()

  const dept = page.locator('.v-field', { has: page.getByLabel('部署', { exact: true }) })
  if (await dept.locator('.v-field__clearable .v-icon').isVisible()) {
    await dept.hover()
    await dept.locator('.v-field__clearable .v-icon').click()
  }
  await page.locator('.v-field', { has: page.getByLabel('ステータス', { exact: true }) }).click()
  await page.getByRole('option', { name: '承認待ち' }).click()

  await expect(async () => {
    await page.locator('tbody tr').first().click()
    await expect(page).toHaveURL(/\/inspections\/\d+$/, { timeout: 2_000 })
  }).toPass({ timeout: 15_000 })
  await expect(page.getByText('点検記録詳細')).toBeVisible()
}

// 承認・差し戻しは管理者/マネージャーだけ。一般ユーザや協力会社の作業員には表示しない（バックエンドの InspectionPolicy#approve? に対応）
test('承認待ちの点検を承認・差し戻しできるのはマネージャーだけ', async ({ page }) => {
  await login(page, ACCOUNTS.ownerManager)
  await openApprovalRequestedInspection(page)
  await expect(page.getByRole('button', { name: '承認', exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: '差し戻し' })).toBeVisible()
})

test('一般ユーザと協力会社の作業員には承認ボタンが表示されない', async ({ page }) => {
  for (const account of [ACCOUNTS.ownerMember, ACCOUNTS.contractorWorker]) {
    await page.context().clearCookies()
    await page.goto('/login')
    await page.evaluate(() => localStorage.clear())
    await login(page, account)
    await openApprovalRequestedInspection(page)
    await expect(page.getByRole('button', { name: '承認', exact: true })).toHaveCount(0)
    await expect(page.getByRole('button', { name: '差し戻し' })).toHaveCount(0)
  }
})
