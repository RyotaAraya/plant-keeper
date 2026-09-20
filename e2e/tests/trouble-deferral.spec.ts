import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'
import type { APIRequestContext, Page } from '@playwright/test'
import { todayForInput } from '../../frontend/src/utils/datetime'

// 運転中に直せないトラブルを、定期整備の作業に回す（トラブルは「定修待ち」）。作業の完了で解決済、見送りで未対応に戻る。
// テストごとに、APIでトラブル（と定期整備）を自分用に用意する。名前は「E2E 」で始まる（繰り返し実行すると一覧に溜まる）
async function adminApi(request: APIRequestContext) {
  const api = apiBaseUrl()
  const loginRes = await request.post(`${api}/login`, { data: { user: ACCOUNTS.admin } })
  const headers = { Authorization: loginRes.headers()['authorization'] }
  const me = (await (await request.get(`${api}/current_user`, { headers })).json()).user
  const equipments = (await (await request.get(`${api}/equipments?per_page=1000`, { headers })).json()).data
  const equipment = (name: string) => equipments.find((e: any) => e.name === name && e.site_id === me.site_id)
  return {
    me,
    equipment,
    async createTrouble(title: string, equipmentName = 'ボイラー設備') {
      const res = await request.post(`${api}/troubles`, {
        headers, data: { trouble: { equipment_id: equipment(equipmentName).id, title, description: '運転中は交換できない', priority: 'high', reported_at: new Date().toISOString() } },
      })
      return (await res.json()).data
    },
    async createMaintenance(title: string, equipmentName: string) {
      const res = await request.post(`${api}/scheduled_maintenances`, {
        headers, data: { scheduled_maintenance: { title, site_id: me.site_id, planned_start_on: todayForInput(), equipment_ids: [equipment(equipmentName).id] } },
      })
      return (await res.json()).data
    },
  }
}

async function openTrouble(page: Page, title: string) {
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  await page.getByRole('textbox', { name: 'タイトル検索' }).fill(title)
  await page.getByRole('row', { name: new RegExp(title) }).click()
  await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
}

test('新しい定期整備に回すと定修待ちになり、作業を完了するとトラブルが解決済になる', async ({ page, request }) => {
  const title = `E2E ${Date.now()} PT-701 の指示が振れる`
  const admin = await adminApi(request)
  await admin.createTrouble(title)
  await login(page, ACCOUNTS.admin)
  await openTrouble(page, title)
  await expect(page.getByText('未対応').first()).toBeVisible()

  await test.step('新しい定期整備を作って回す', async () => {
    await page.getByRole('button', { name: '定期整備に回す' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByText('新しい定期整備を作る').click()
    await dialog.getByLabel('名称 *').fill(`E2E ${Date.now()} ボイラー整備`)
    await dialog.getByLabel('予定 開始日 *').fill(todayForInput())
    await dialog.getByRole('button', { name: '回す' }).click()
  })

  await test.step('定期整備の詳細に、トラブルから回された作業（トラブルへのリンクつき）が出る', async () => {
    await expect(page.getByTestId('tasks-card')).toContainText(title)
    await expect(page.getByTestId('tasks-card').locator('[data-testid^="task-trouble-"]')).toBeVisible()
    await page.getByTestId('tasks-card').getByRole('combobox').first().click()
    await page.getByRole('option', { name: '完了' }).click()
    await expect(page.getByTestId('tasks-progress')).toContainText('完了 1 / 1')
  })

  await test.step('トラブルは解決済になり、定期整備のカードから整備に戻れる', async () => {
    await page.getByTestId('tasks-card').locator('[data-testid^="task-trouble-"]').click()
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
    await expect(page.getByText('解決済').first()).toBeVisible()
    await expect(page.getByTestId('deferred-card')).toContainText('完了')
    await expect(page.getByRole('button', { name: '定期整備に回す' })).toHaveCount(0)
  })
})

test('既存の定期整備に回すと（設備が対象でなければ追加され）、作業を見送りにするとトラブルは未対応に戻る', async ({ page, request }) => {
  const stamp = Date.now()
  const title = `E2E ${stamp} 発電機の軸受の異音`
  const maintenanceTitle = `E2E ${stamp} A号ボイラー整備`
  const admin = await adminApi(request)
  await admin.createMaintenance(maintenanceTitle, '常圧蒸留装置')
  await admin.createTrouble(title, 'ボイラー設備')
  await login(page, ACCOUNTS.admin)
  await openTrouble(page, title)

  await page.getByRole('button', { name: '定期整備に回す' }).click()
  const dialog = page.getByRole('dialog')
  await dialog.locator('.v-field', { has: page.getByLabel('定期整備 *') }).click()
  await page.getByRole('option', { name: new RegExp(maintenanceTitle) }).click()
  await expect(dialog.getByTestId('defer-equipment-added')).toContainText('ボイラー設備')
  await dialog.getByRole('button', { name: '回す' }).click()

  await expect(page.getByRole('heading', { level: 1, name: maintenanceTitle })).toBeVisible()
  await expect(page.getByText('対象設備（2）')).toBeVisible() // ボイラー設備が対象に追加された
  await page.getByTestId('tasks-card').getByRole('combobox').first().click()
  await page.getByRole('option', { name: '見送り' }).click()
  await expect(page.getByTestId('tasks-progress')).toContainText('完了 0 / 0')

  await page.getByTestId('tasks-card').locator('[data-testid^="task-trouble-"]').click()
  await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
  await expect(page.getByText('未対応').first()).toBeVisible()
  await expect(page.getByRole('button', { name: '定期整備に回す' })).toBeVisible() // 見送りにしたので、回し直せる
})

test('一般ユーザは、トラブルを定期整備に回せない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: 'トラブル管理', exact: true }).click()
  const row = page.locator('tbody tr', { has: page.locator('.v-chip') }).first()
  await expect(row).toBeVisible()
  await row.click()
  await expect(page.getByRole('heading', { level: 1 }).first()).toBeVisible()
  await expect(page.getByRole('button', { name: '定期整備に回す' })).toHaveCount(0)
})
