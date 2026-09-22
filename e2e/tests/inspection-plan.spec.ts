import { test, expect, login, resetSession, ACCOUNTS } from './support'

const OWNER_MANAGER = { email: 'yamamoto@example.com', password: 'password' }

// 点検計画（周期・次回期限）: 一覧で期限超過が見え、そこから点検を始められる。
// 点検を提出すると期限が進み、シードの状態が変わってしまうため、ここでは提出まではしない
test('点検計画に期限超過が表示され、「点検を実施」で計画の設備を引き継いだ点検画面が開く', async ({ page }) => {
  await login(page, ACCOUNTS.member)

  await page.getByRole('link', { name: '点検計画', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '点検計画' })).toBeVisible()
  await expect(page.locator('tbody tr').first()).toBeVisible()
  await expect(page.getByText(/日超過/).first()).toBeVisible()

  await test.step('期限超過のみに絞り込める', async () => {
    const all = await page.locator('tbody tr').count()
    await page.getByLabel('期限超過のみ').check()
    await expect(async () => {
      const rows = page.locator('tbody tr')
      expect(await rows.count()).toBeLessThanOrEqual(all)
      for (const text of await rows.allInnerTexts()) expect(text).toContain('日超過')
    }).toPass()
  })

  await test.step('点検を実施すると設備が引き継がれる', async () => {
    await page.getByRole('button', { name: '点検を実施' }).first().click()
    await expect(page).toHaveURL(/\/inspections\/new\?.*inspection_plan_id=\d+/)
    await expect(page.getByRole('heading', { level: 1, name: '新規点検記録' })).toBeVisible()
    await expect(page.locator('.v-field', { has: page.getByLabel('設備 *') }).locator('.v-select__selection')).not.toBeEmpty()
  })
})

test('計画の追加ボタンはマネージャーにだけ表示される', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: '点検計画', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '点検計画' })).toBeVisible()
  await expect(page.getByRole('button', { name: '計画を追加' })).toHaveCount(0)

  await resetSession(page)
  await login(page, OWNER_MANAGER)
  await page.getByRole('link', { name: '点検計画', exact: true }).click()
  await expect(page.getByRole('button', { name: '計画を追加' })).toBeVisible()
})

// 巡回の計画は、装置ごとではなく、いくつかの装置をまとめて1件にする
test('複数の設備をまとめた巡回の計画から「点検を実施」を開くと、その設備すべてが点検に引き継がれる', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: '点検計画', exact: true }).click()

  const row = page.getByRole('row', { name: /製造部 巡回点検/ })
  await expect(row).toContainText('常圧蒸留装置、')
  await expect(row).toContainText('重油間接脱硫装置')
  await row.getByRole('button', { name: '点検を実施' }).click()

  await expect(page).toHaveURL(/\/inspections\/new\?.*equipment_ids=/)
  const equipment = page.locator('.v-field', { has: page.getByLabel('設備 *') })
  for (const name of ['常圧蒸留装置', '重油間接脱硫装置', '流動接触分解装置', '減圧蒸留装置', '接触改質装置']) {
    await expect(equipment).toContainText(name)
  }
  await expect(page.getByLabel('計器（任意）')).toHaveCount(0) // 複数の設備をまとめた点検は、計器を選ばない
})
