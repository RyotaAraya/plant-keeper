import { test, expect, openListRow, login, selectFirstOption, apiBaseUrl, ACCOUNTS } from './support'
import type { Page } from '@playwright/test'
import { todayForInput } from '../../frontend/src/utils/datetime'

const WORKER = { email: 'honda@example.com', password: 'password' }

async function pickOption(page: Page, dialogOrPage: ReturnType<Page['getByRole']> | Page, label: string, option: string | RegExp) {
  await dialogOrPage.locator('.v-field', { has: page.getByLabel(label, { exact: true }) }).click()
  await page.getByRole('option', { name: option }).click()
}

// 定期整備の作業: 部署ごとに、設備の計器を種類ごとの定修点検つきで割り当て、作業から点検を実施すると作業が完了になる。
// 未完了の作業があるうちは検収へ進めない（完了か見送り）。次回を作ると作業が引き継がれる。
// このテストは定期整備を2件・点検を1件作る（名前が「E2E 」で始まる。繰り返し実行すると一覧に溜まる）
test('計器を一括追加し、作業から点検を実施して完了にし、残りを見送りにして検収へ進み、次回に作業を引き継ぐ', async ({ page }) => {
  const stamp = Date.now()
  const title = `E2E ${stamp} ボイラー整備（作業）`
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '定期整備', exact: true }).click()

  await test.step('ボイラー設備の定期整備を作る', async () => {
    await page.getByRole('button', { name: '新規作成' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('名称 *', { exact: false }).fill(title)
    await dialog.getByLabel('予定 開始日 *').fill(todayForInput())
    await dialog.locator('.v-field', { has: page.getByLabel('対象設備 *') }).click()
    await page.getByRole('option', { name: 'ボイラー設備' }).click()
    await page.keyboard.press('Escape')
    await dialog.getByRole('button', { name: '作成' }).click()
    await expect(dialog).toBeHidden()
    await openListRow(page, title)
  })

  const tasks = page.getByTestId('tasks-card')
  await expect(tasks).toContainText('作業はまだありません')

  await test.step('計器を一括追加すると、伝送器の定修点検の作業が並ぶ（部署ごと）', async () => {
    await tasks.getByRole('button', { name: '計器を一括追加' }).click()
    const dialog = page.getByRole('dialog')
    await pickOption(page, dialog, '担当する部署', /計装保全課$/)
    await dialog.getByRole('button', { name: '追加' }).click()
    await expect(dialog.getByTestId('bulk-result')).toContainText(/\d+件を追加しました/)
    await dialog.getByRole('button', { name: '閉じる' }).click()
    await expect(tasks.getByTestId('tasks-progress')).toContainText(/完了 0 \/ \d+/)
    await expect(tasks.getByTestId('task-FT-701 伝送器 定修点検')).toContainText('伝送器 定修点検')
    await expect(tasks).toContainText('計装保全課')
  })

  await test.step('未完了の作業があるうちは、検収へ進めない', async () => {
    await page.getByRole('button', { name: '実施中にする' }).click()
    await page.getByRole('button', { name: '検収へ進む' }).click()
    await expect(page.getByRole('alert').filter({ hasText: '未完了の作業が' })).toBeVisible()
    await expect(page.getByTestId('maintenance-status')).toHaveText('実施中')
  })

  await test.step('作業から点検を実施すると、設備・計器・チェックリストが引き継がれ、提出すると作業が完了になる', async () => {
    await tasks.getByTestId('task-FT-701 伝送器 定修点検').getByRole('button', { name: '点検を実施' }).click()
    await expect(page.getByRole('heading', { level: 1, name: '新規点検記録' })).toBeVisible()
    await expect(page.getByTestId('from-maintenance-task')).toBeVisible()
    await expect(page.locator('.v-field', { has: page.getByLabel('計器（任意）', { exact: true }) })).toContainText('FT-701')
    await expect(page.locator('input[value="5点校正（全数）"]')).toBeVisible() // 伝送器 定修点検のチェックリストの項目
    if ((await page.locator('.v-field', { has: page.getByLabel('部署 *', { exact: true }) }).innerText()).trim() === '部署 *') await selectFirstOption(page, '部署 *')
    await page.getByRole('button', { name: '提出' }).click()
    await expect(page).toHaveURL(/\/inspections$/)
    await page.goBack()
    await page.goBack()
    await page.getByRole('link', { name: '定期整備', exact: true }).click()
    await openListRow(page, title)
    await expect(tasks.getByTestId('tasks-progress')).toContainText(/完了 1 \/ \d+/)
    await expect(tasks.getByTestId('task-FT-701 伝送器 定修点検')).toContainText(todayForInput())
    await expect(tasks.getByTestId('task-FT-701 伝送器 定修点検').getByRole('button', { name: '点検記録' })).toBeVisible()
  })

  await test.step('残りの作業を見送りにすると、検収へ進める（見送りは進捗に数えない）', async () => {
    const rows = tasks.locator('[data-testid^="task-"]')
    const count = await rows.count()
    for (let i = 0; i < count; i++) {
      const row = rows.nth(i)
      if ((await row.getAttribute('data-testid')) === 'task-FT-701 伝送器 定修点検') continue
      await row.locator('.v-select .v-field').click()
      await page.getByRole('option', { name: '見送り' }).click()
      await expect(row.locator('.v-select')).toContainText('見送り')
    }
    await expect(tasks.getByTestId('tasks-progress')).toContainText('完了 1 / 1')
    await page.getByRole('button', { name: '検収へ進む' }).click()
    await expect(page.getByTestId('maintenance-status')).toHaveText('検収')
  })

  await test.step('次回を作ると、作業（見送りも）が未着手に戻って引き継がれる', async () => {
    await page.getByRole('button', { name: '次回を作る' }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByTestId('carried-tasks')).toContainText(/作業 \d+件を、未着手に戻して引き継ぎます/)
    await dialog.getByLabel('予定 開始日 *').fill('2028-04-01')
    await dialog.getByRole('button', { name: '作成' }).click()
    await expect(page.getByTestId('maintenance-status')).toHaveText('計画中')
    await expect(page.getByTestId('tasks-card').getByTestId('tasks-progress')).toContainText(/完了 0 \/ \d+/)
  })
})

// 権限のテストが、作業のある定期整備を、APIで自分用に用意する（別のテストの結果に依存しない）
test.describe('作業の権限', () => {
  test.beforeAll(async ({ request }) => {
    const api = apiBaseUrl()
    const loginRes = await request.post(`${api}/login`, { data: { user: ACCOUNTS.admin } })
    const headers = { Authorization: loginRes.headers()['authorization'] }
    const me = (await (await request.get(`${api}/current_user`, { headers })).json()).user
    const equipments = (await (await request.get(`${api}/equipments?per_page=1000`, { headers })).json()).data
    const boiler = equipments.find((e: any) => e.name === 'ボイラー設備' && e.site_id === me.site_id)
    const created = await request.post(`${api}/scheduled_maintenances`, {
      headers, data: { scheduled_maintenance: { title: `E2E ${Date.now()} 権限確認用`, site_id: me.site_id, planned_start_on: todayForInput(), equipment_ids: [boiler.id] } },
    })
    const maintenance = (await created.json()).data
    await request.post(`${api}/scheduled_maintenances/${maintenance.id}/tasks/bulk`, { headers, data: { equipment_id: boiler.id } })
  })

for (const [label, account] of [['一般ユーザ', ACCOUNTS.member], ['協力会社の技能員', WORKER]] as const) {
  test(`${label}は作業の状態を更新できるが、作業の追加・一括追加・編集・削除はできない`, async ({ page }) => {
    await login(page, account)
    await page.getByRole('link', { name: '定期整備', exact: true }).click()
    const row = page.locator('tbody tr', { hasText: /\d+ \/ \d+/ }).first() // 作業のある定期整備
    await expect(row).toBeVisible()
    await row.click()

    const tasks = page.getByTestId('tasks-card')
    await expect(tasks.locator('[data-testid^="task-"]').first()).toBeVisible()
    await expect(tasks.getByRole('button', { name: /作業を追加|計器を一括追加/ })).toHaveCount(0)
    await expect(tasks.getByRole('button', { name: /を編集|を削除/ })).toHaveCount(0)
    await expect(tasks.locator('.v-select').first()).toBeVisible() // 状態は、現場が付ける
  })
}
})
