import { test, expect, login, resetSession, apiBaseUrl, selectOption, openPlans, findListRow, ACCOUNTS } from './support'

const OWNER_MANAGER = { email: 'yamamoto@example.com', password: 'password' }

// 「計画」画面: 定期点検のまとまりと、定期整備の系列・単発を1画面に並べ、行を押すとその場で子を開く
test('まとまりを開くと計器ごとの周期と期限が並び、「点検を実施」で点検フォームが開く', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await openPlans(page)
  await expect(page.getByRole('heading', { level: 2, name: /定期点検/ })).toBeVisible()
  await expect(page.getByRole('heading', { level: 2, name: /定期整備/ })).toBeVisible()
  await expect(page.getByRole('button', { name: 'まとまりを追加' })).toHaveCount(0) // 一般ユーザは作成・編集できない

  const groups = page.getByTestId('plan-groups')
  const group = groups.locator('tbody tr', { hasText: '伝送器 月次点検' }).first()
  await expect(group).toContainText('計装保全課')
  await group.click()
  const plans = groups.locator('[data-testid^="group-plans-"]')
  const plan = plans.locator('tr', { hasText: 'FT-301 流量伝送器 ゼロ点確認' })
  await expect(plan).toContainText('90日ごと')
  await plan.getByRole('button', { name: '点検を実施' }).click()
  await expect(page).toHaveURL(/\/inspections\/new\?.*inspection_plan_id=\d+/)
})

test('定期整備の系列を開くと各回が並び、回を押すと定期整備の詳細へ進む', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await openPlans(page, '定期整備')
  await expect(page.getByTestId('plan-groups')).toHaveCount(0) // 定期整備だけ

  const series = await findListRow(page, page.getByTestId('plan-maintenances').locator('tbody tr', { hasText: /^系列A号ボイラー整備/ }))
  await expect(series).toContainText('ボイラー設備（24か月）')
  await expect(series).toContainText('発電設備（48か月）')
  await series.click()
  const rounds = page.locator('[data-testid^="series-rounds-"]')
  await expect(rounds.getByRole('link', { name: /2024年 A号ボイラー整備/ })).toBeVisible()
  await rounds.getByRole('link', { name: /2022年 A号ボイラー整備/ }).click()
  await expect(page).toHaveURL(/\/maintenances\/\d+$/)
  await expect(page.getByRole('link', { name: '計画の一覧へ戻る' })).toBeVisible() // ヘッダーの現在地は「計画」
})

test('法規区分で絞り込むと、その区分のまとまりだけになり、定期整備は出さない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await openPlans(page)
  await selectOption(page, '法規区分', 'ボイラー・第一種圧力容器')
  const groups = page.getByTestId('plan-groups').locator('tbody tr')
  await expect(groups).toHaveCount(1)
  await expect(groups).toContainText('安全弁 年次点検')
  await expect(page.getByText('担当部署・法規区分で絞り込んでいる間は、定期整備を表示しません')).toBeVisible()
})

test('旧の点検計画・定期整備のURLは「計画」画面の期限順・定期整備に転送され、絞り込みも引き継ぐ', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspection-plans?overdue=true')
  await expect(page).toHaveURL(/\/plans\?.*tab=due/)
  await expect(page.getByLabel('期限超過のみ')).toBeChecked()

  await page.goto('/maintenances?status=completed')
  await expect(page).toHaveURL(/\/plans\?.*tab=maintenance/)
  await expect(page.getByTestId('plan-maintenances').locator('tbody tr').first()).toContainText('完了')
})

test('業務管理者は、まとまりを追加・編集できる', async ({ page }) => {
  await login(page, OWNER_MANAGER)
  await openPlans(page, '定期点検')
  const name = `E2E ${Date.now()} テレメータ計器の定期検査`

  await page.getByRole('button', { name: 'まとまりを追加' }).click()
  const dialog = page.getByRole('dialog')
  await dialog.getByLabel('名前').fill(name)
  await dialog.getByLabel('既定の周期（日・任意）').fill('90')
  const saved = page.waitForResponse((res) => res.url().endsWith('/inspection_plan_groups') && res.request().method() === 'POST')
  await dialog.getByRole('button', { name: '保存' }).click()
  const groupId = (await (await saved).json()).data.id
  try {
    await expect(dialog).toBeHidden()
    const row = page.getByTestId('plan-groups').locator('tbody tr', { hasText: name })
    await expect(row).toContainText('0件')

    await row.getByRole('button', { name: `${name}を編集` }).click()
    await expect(dialog.getByLabel('既定の周期（日・任意）')).toHaveValue('90')
    // 1つだけ選ぶ欄は選ぶとメニューが閉じる（selectOption の Escape はダイアログまで閉じるため使わない）
    await dialog.locator('.v-field', { has: page.getByLabel('法規区分（任意）', { exact: true }) }).click()
    await page.getByRole('option', { name: '高圧ガス製造施設（特定施設）' }).click()
    await dialog.getByRole('button', { name: '保存' }).click()
    await expect(dialog).toBeHidden()
    await expect(row).toContainText('高圧ガス製造施設')
  } finally {
    // まとまりは消せないため、無効にして一覧から外す
    const token = await page.evaluate(() => localStorage.getItem('jwt'))
    await page.request.patch(`${apiBaseUrl()}/inspection_plan_groups/${groupId}`, { headers: { Authorization: `Bearer ${token}` }, data: { inspection_plan_group: { is_active: false } } })
  }

  await test.step('定期整備の系列を編集すると、今の名前と設備ごとの周期が入っている（保存はしない）', async () => {
    await openPlans(page, '定期整備')
    const series = await findListRow(page, page.getByTestId('plan-maintenances').locator('tbody tr', { hasText: /^系列A号ボイラー整備/ }))
    await series.getByRole('button', { name: 'A号ボイラー整備を編集' }).click()
    await expect(dialog.getByLabel('系列の名前 *（例: A号ボイラー整備）')).toHaveValue('A号ボイラー整備')
    await expect(dialog.getByLabel('ボイラー設備の周期（月）')).toHaveValue('24')
    await dialog.getByRole('button', { name: 'キャンセル' }).click()
    await expect(dialog).toBeHidden()
  })

  await resetSession(page)
})
