import { test, expect, login, resetSession, apiBaseUrl, ACCOUNTS } from './support'
import { todayForInput } from '../../frontend/src/utils/datetime'
import type { APIRequestContext, Page } from '@playwright/test'

const MANAGER = { email: 'suzuki@example.com', password: 'password' }
const WORKER = { email: 'honda@example.com', password: 'password' }

async function apiToken(request: APIRequestContext, account: { email: string; password: string }) {
  const res = await request.post(`${apiBaseUrl()}/login`, { data: { user: account } })
  expect(res.ok()).toBeTruthy()
  return res.headers()['authorization']
}

// シードのインターロック（川崎製油所 発電設備 I-752）を、終わっていないバイパスがない状態にする。
// 流れのテストが途中で失敗しても、次の実行で申請から始められるようにするため
async function resetInterlock(request: APIRequestContext, tagNumber: string): Promise<number> {
  const admin = await apiToken(request, ACCOUNTS.admin)
  const res = await request.get(`${apiBaseUrl()}/interlocks`, { headers: { Authorization: admin }, params: { q: tagNumber } })
  const interlock = (await res.json()).data.find((il: any) => il.tag_number === tagNumber)
  expect(interlock, `シードのインターロック ${tagNumber}`).toBeTruthy()
  const bypass = interlock.open_bypass
  if (bypass) {
    const post = (action: string, token: string, data: object = {}) =>
      request.post(`${apiBaseUrl()}/interlock_bypasses/${bypass.id}/${action}`, { headers: { Authorization: token }, data })
    if (bypass.status === 'requested' || bypass.status === 'approved') {
      await post('cancel', admin, { reason: 'E2E の後片付け' })
    } else {
      // 復帰と確認は別の人が行う
      const worker = await apiToken(request, WORKER)
      if (bypass.status === 'bypassed') await post('restore', worker)
      await post('confirm', admin)
    }
  }
  return interlock.id
}

async function switchTo(page: Page, account: { email: string; password: string }, path: string) {
  await resetSession(page)
  await login(page, account)
  await page.goto(path)
}

// シードのデモ: I-701（ボイラードラム液位 低低）は、LT-701 の調査でバイパスしたまま、予定の復帰を過ぎている
test('ホームと台帳で、復帰期限を過ぎたバイパスが目立ち、詳細で理由と代替措置が分かる', async ({ page }) => {
  await login(page, ACCOUNTS.member)

  // ホームの先頭（拠点全体）に、復帰期限超過として出る
  const section = page.getByTestId('home-bypasses')
  await expect(section.locator('li.pk-home-list__alert', { hasText: 'I-701 ボイラードラム液位 低低' })).toContainText('復帰期限超過')

  await page.goto('/interlocks?bypass_state=overdue')
  await expect(page.getByTestId('interlock-overdue-alert')).toBeVisible()
  // 件数は決め打ちしない（シードの予定の復帰は投入時からの相対時間のため、stg では時間がたつと I-751 も期限を過ぎる）
  await expect(page.locator('tbody tr', { hasText: 'I-701' })).toBeVisible()
  for (const row of await page.locator('tbody tr').all()) await expect(row).toContainText('復帰期限超過')

  await page.locator('tbody tr', { hasText: 'I-701' }).click()
  const current = page.getByTestId('current-bypass')
  await expect(current).toContainText('復帰期限超過')
  await expect(current).toContainText('LT-701 の指示不安定の調査のため')
  await expect(current).toContainText('ドラムの現場液面計を運転員が1時間ごとに確認')
  await expect(page.getByRole('link', { name: 'LT-701' })).toBeVisible()
})

test('バイパスは申請 → 承認 → 実施 → 復帰 → 別の人の確認で完了し、本人には承認・確認のボタンが出ない', async ({ page }) => {
  const id = await resetInterlock(page.request, 'I-752')
  const path = `/interlocks/${id}`
  const current = page.getByTestId('current-bypass')
  const act = async (action: string) => {
    await current.getByTestId(`bypass-${action}`).click()
    await page.getByTestId('bypass-action-submit').click()
  }

  // 自社の一般: 申請する。承認は業務管理者の仕事なので、ボタンは出ない
  await switchTo(page, ACCOUNTS.member, path)
  await page.getByTestId('bypass-request').click()
  await page.getByTestId('bypass-reason').locator('textarea').fill('E2E TV-751 の年次校正のため')
  await page.getByTestId('bypass-measure').locator('textarea').fill('タービン入口の現場温度計を運転員が監視する')
  await page.getByTestId('bypass-request-submit').click()
  await expect(current).toContainText('承認待ち')
  await expect(current.getByTestId('bypass-approve')).toHaveCount(0)
  await expect(current).toContainText('管理者・自社の業務管理者の承認待ちです')

  // 自社の業務管理者: 承認する
  await switchTo(page, MANAGER, path)
  await act('approve')
  await expect(current).toContainText('承認済（未実施）')

  // 協力会社の技能員: 現場でバイパスし、作業のあとで復帰する。復帰した本人は確認できない
  await switchTo(page, WORKER, path)
  await act('start')
  await expect(current).toContainText('バイパス中')
  await act('restore')
  await expect(current).toContainText('復帰確認待ち')
  await expect(current.getByTestId('bypass-confirm')).toHaveCount(0)

  // 自社の一般: 別の人として復帰を確認し、完了にする
  await switchTo(page, ACCOUNTS.member, path)
  await act('confirm')
  await expect(current).toContainText('終わっていないバイパスはありません')
  // 履歴は新しい順（実行のたびに完了の記録が1件ずつ増える）
  await expect(page.getByRole('row', { name: /E2E TV-751 の年次校正のため/ }).first()).toContainText('完了')
})

// 定期整備のあとは運転を再開するため、対象設備のインターロックにバイパス中・復帰確認待ちが残っていると検収へ進めない。
// シードの I-701（ボイラー設備。復帰期限超過のままバイパス中）を使う。このテストは定期整備を1件作る（名前が「E2E 」で始まる）
test('対象設備にバイパスが残っている定期整備は、検収へ進めず、残っているバイパスが一覧で分かる', async ({ page }) => {
  const admin = await apiToken(page.request, ACCOUNTS.admin)
  const headers = { Authorization: admin }
  const me = (await (await page.request.get(`${apiBaseUrl()}/current_user`, { headers })).json()).user
  const equipments = (await (await page.request.get(`${apiBaseUrl()}/equipments`, { headers, params: { per_page: 1000 } })).json()).data
  const boiler = equipments.find((e: any) => e.name === 'ボイラー設備' && e.site_id === me.site_id)
  const created = await page.request.post(`${apiBaseUrl()}/scheduled_maintenances`, {
    headers,
    data: { scheduled_maintenance: { title: `E2E ${Date.now()} ボイラー整備（バイパス）`, site_id: me.site_id, planned_start_on: todayForInput(), equipment_ids: [boiler.id] } },
  })
  expect(created.ok()).toBeTruthy()
  const maintenance = (await created.json()).data
  for (const status of ['preparing', 'in_progress']) {
    const res = await page.request.patch(`${apiBaseUrl()}/scheduled_maintenances/${maintenance.id}`, { headers, data: { scheduled_maintenance: { status } } })
    expect(res.ok()).toBeTruthy()
  }

  await login(page, ACCOUNTS.admin)
  await page.goto(`/maintenances/${maintenance.id}`)
  const card = page.getByTestId('maintenance-bypasses')
  await expect(card.getByRole('row', { name: /I-701 ボイラードラム液位 低低/ })).toContainText('復帰期限超過')
  await expect(page.getByRole('button', { name: '検収へ進む' })).toBeDisabled()
  await expect(page.getByTestId('bypass-blocking-note')).toContainText('戻っていないバイパス')

  await card.getByRole('row', { name: /I-701/ }).click()
  await expect(page).toHaveURL(/\/interlocks\/\d+$/)
})
