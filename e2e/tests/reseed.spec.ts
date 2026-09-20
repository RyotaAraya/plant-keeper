import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'
import type { Page } from '@playwright/test'

// デモデータの再投入は、実際に実行すると全データが消えるため、APIを差し替えて画面の流れだけを確認する
// （サーバ側の実行・状態・二重実行の拒否は、バックエンドのテスト demo_reseed_test.rb で確認している）。
// 状態の確認（GET）は、最初は未実行、始めたあとは「実行中」を1回返し、その後 `final` を返す
async function mockReseed(page: Page, final: { status: string; error?: string }) {
  let started = false
  let polls = 0
  const cors = {
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'authorization, content-type',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
  }
  await page.route(`${apiBaseUrl()}/admin/reseed`, async (route) => {
    const method = route.request().method()
    if (method === 'OPTIONS') return route.fulfill({ status: 204, headers: cors })
    if (method === 'POST') {
      started = true
      return route.fulfill({ status: 202, headers: cors, json: { data: { status: 'running' } } })
    }
    if (!started) return route.fulfill({ headers: cors, json: { data: { status: 'idle', enabled: true } } })
    polls += 1
    const data = polls === 1 ? { status: 'running' } : final
    return route.fulfill({ headers: cors, json: { data: { ...data, enabled: true } } })
  })
}

async function openReseedDialog(page: Page) {
  await page.getByRole('link', { name: '設定', exact: true }).click()
  await page.getByRole('button', { name: '再投入する' }).click()
}

test('再投入は取り消せない旨を示し、実行中は状態を表示して再実行できず、完了したら知らせる', async ({ page }) => {
  await mockReseed(page, { status: 'succeeded' })
  await login(page, ACCOUNTS.admin)
  await openReseedDialog(page)

  const dialog = page.getByRole('dialog')
  await expect(dialog).toContainText('この操作は取り消せません')
  await dialog.getByRole('button', { name: '実行する' }).click()

  await test.step('実行中: 進捗の表示。閉じても処理が続き、ページの再投入ボタンは押せない', async () => {
    await expect(dialog.getByTestId('reseed-progress')).toBeVisible()
    await expect(dialog).toContainText('この画面を閉じても処理は続きます')
    await expect(dialog.getByRole('button', { name: '実行する' })).toHaveCount(0)
    await dialog.getByRole('button', { name: '閉じる' }).click()
    await expect(dialog).toBeHidden()
    await expect(page.getByTestId('reseed-running')).toBeVisible()
    await expect(page.getByRole('button', { name: '再投入する' })).toBeDisabled()
  })

  await test.step('完了すると、知らせて、また実行できる', async () => {
    await expect(page.getByText('デモデータを再投入しました。')).toBeVisible({ timeout: 15_000 })
    await expect(page.getByTestId('reseed-running')).toHaveCount(0)
    await expect(page.getByRole('button', { name: '再投入する' })).toBeEnabled()
  })
})

test('再投入が失敗したら、その旨を表示する', async ({ page }) => {
  await mockReseed(page, { status: 'failed', error: '再投入に失敗しました（詳細はサーバログを参照）' })
  await login(page, ACCOUNTS.admin)
  await openReseedDialog(page)
  await page.getByRole('dialog').getByRole('button', { name: '実行する' }).click()

  await expect(page.getByRole('dialog')).toContainText('再投入に失敗しました', { timeout: 15_000 })
  await page.getByRole('dialog').getByRole('button', { name: '閉じる' }).click()
  await expect(page.getByRole('dialog')).toBeHidden()
  await expect(page.getByRole('alert').filter({ hasText: '再投入に失敗しました（詳細はサーバログを参照）' })).toBeVisible()
})
