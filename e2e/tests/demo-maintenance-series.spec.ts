import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'
import type { Page } from '@playwright/test'

async function apiGet(page: Page, path: string) {
  const token = await page.evaluate(() => localStorage.getItem('jwt'))
  const res = await page.request.get(`${apiBaseUrl()}${path}`, { headers: { Authorization: `Bearer ${token}` } })
  expect(res.ok()).toBeTruthy()
  return (await res.json()).data
}

// シードのデモ: 川崎製油所の「A号ボイラー整備」の系列（2022・2024・2026年）。デモデータのない環境（シード前のstgなど）ではスキップ
test('デモの系列: 2026年の整備に、部署ごとの作業と、定修待ちのトラブルから回した作業があり、次回はボイラーだけが対象になる', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  const maintenances = await apiGet(page, '/scheduled_maintenances?per_page=1000')
  const demo = maintenances?.find((m: any) => m.title === '2026年 A号ボイラー整備')
  test.skip(!demo, 'シードの定期整備の系列がない環境')

  await page.goto(`/maintenances/${demo.id}`)
  await expect(page.getByRole('heading', { level: 1, name: '2026年 A号ボイラー整備' })).toBeVisible()

  await test.step('系列の履歴に3回分（2022・2024・2026年）が並ぶ', async () => {
    await page.getByRole('tab', { name: '系列' }).click()
    const card = page.getByTestId('series-card')
    await expect(card).toContainText('ボイラー設備（24か月ごと）')
    await expect(card).toContainText('発電設備（48か月ごと）')
    await expect(card.locator('[data-testid^="series-history-"]')).toHaveCount(3)
  })

  await test.step('作業: 計装課の点検、電気課の整備、定修待ちのトラブルから回した作業', async () => {
    await page.getByRole('tab', { name: /^作業/ }).click()
    const tasks = page.getByTestId('tasks-card')
    await expect(tasks).toContainText('計装保全課')
    await expect(tasks).toContainText('電気保全課')
    await expect(tasks).toContainText('蒸気タービン開放点検')
    await expect(tasks).toContainText('PSV-701') // 安全弁の定修点検
    await expect(tasks.locator('[data-testid^="task-trouble-"]')).toHaveCount(1)
  })

  await test.step('回されたトラブルは定修待ち', async () => {
    await page.getByTestId('tasks-card').locator('[data-testid^="task-trouble-"]').click()
    await expect(page.getByRole('heading', { level: 1, name: /FT-702/ })).toBeVisible()
    await expect(page.getByText('定修待ち').first()).toBeVisible()
    await expect(page.getByTestId('deferred-card')).toContainText('2026年 A号ボイラー整備')
  })

  await test.step('次回（2028年）は、周期が来たボイラー設備だけが対象（発電設備は4年周期でまだ）', async () => {
    await page.goto(`/maintenances/${demo.id}`)
    await page.getByRole('button', { name: '次回を作る' }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByLabel('名称 *')).toHaveValue('2028年 A号ボイラー整備')
    await expect(dialog.getByTestId('candidate-ボイラー設備').getByRole('checkbox')).toBeChecked()
    await expect(dialog.getByTestId('candidate-発電設備').getByRole('checkbox')).not.toBeChecked()
  })
})
