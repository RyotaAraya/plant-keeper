import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'

// ダイアログを閉じたとき、開いたボタンへフォーカスが戻る（アプリ全体の仕組み utils/dialogFocusReturn.ts。#136）。
// キャンセル・Esc・外側のクリック・保存（一覧の再取得でボタンが作り直される場合を含む）のどれでも戻ることを、代表的なダイアログで確かめる

test('作成ダイアログは、キャンセル・Esc・外側のクリックのどれで閉じても「新規作成」へ戻る', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.goto('/equipments')
  const open = page.getByRole('button', { name: '新規作成' })
  const dialog = page.getByRole('dialog')

  await open.click()
  await dialog.getByRole('button', { name: 'キャンセル' }).click()
  await expect(dialog).toHaveCount(0)
  await expect(open).toBeFocused()

  await open.click()
  await expect(dialog).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(dialog).toHaveCount(0)
  await expect(open).toBeFocused()

  await open.click()
  await expect(dialog).toBeVisible()
  await page.mouse.click(5, 5) // ダイアログの外（スクリム）
  await expect(dialog).toHaveCount(0)
  await expect(open).toBeFocused()
})

test('保存して詳細を読み込み直し、「編集」ボタンが作り直されても、新しい「編集」ボタンへ戻る', async ({ page }) => {
  // 計器の詳細は、保存後の読み込みの間は中身がスケルトンに置き換わるため、「編集」ボタンが作り直される。
  // シードの計器を変えないよう、E2E 専用の計器（E2E-FOCUS。なければAPIで作る）を、何も変えずに保存する
  const api = apiBaseUrl()
  const loginRes = await page.request.post(`${api}/login`, { data: { user: ACCOUNTS.admin } })
  const headers = { Authorization: loginRes.headers()['authorization'] }
  const me = (await (await page.request.get(`${api}/current_user`, { headers })).json()).user
  const found = (await (await page.request.get(`${api}/instruments`, { headers, params: { q: 'E2E-FOCUS', 'site_ids[]': me.site_id } })).json()).data
  let instrument = found.find((i: any) => i.tag_number === 'E2E-FOCUS')
  if (!instrument) {
    const equipments = (await (await page.request.get(`${api}/equipments?per_page=1000&site_ids[]=${me.site_id}`, { headers })).json()).data
    const tank = equipments.find((e: any) => e.name === 'タンク設備') ?? equipments[0]
    const created = await page.request.post(`${api}/instruments`, { headers, data: { instrument: { equipment_id: tank.id, tag_number: 'E2E-FOCUS', instrument_type: 'pressure_transmitter' } } })
    expect(created.ok()).toBeTruthy()
    instrument = (await created.json()).data
  }

  await login(page, ACCOUNTS.admin)
  await page.goto(`/instruments/${instrument.id}`)
  const edit = page.getByRole('button', { name: '編集', exact: true })
  const before = await edit.elementHandle()
  await edit.click()
  const refetched = page.waitForResponse((res) => res.url().endsWith(`/instruments/${instrument.id}`) && res.request().method() === 'GET')
  await page.getByRole('dialog').getByRole('button', { name: '保存' }).click()
  await refetched
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(edit).toBeFocused()
  expect(await before!.evaluate((el) => el.isConnected)).toBe(false) // 開いたボタンは作り直されている
})

test('詳細の編集と、共通部品のダイアログ（前倒しの候補）も、閉じると開いたボタンへ戻る', async ({ page }) => {
  // 詳細の編集は、実行のたびにAPIで作る `E2E ` で始まるトラブルで行う（キャンセルだけで、保存はしない）
  const api = apiBaseUrl()
  const loginRes = await page.request.post(`${api}/login`, { data: { user: ACCOUNTS.admin } })
  const headers = { Authorization: loginRes.headers()['authorization'] }
  const equipments = (await (await page.request.get(`${api}/equipments?per_page=1`, { headers })).json()).data
  const created = await page.request.post(`${api}/troubles`, {
    headers, data: { trouble: { equipment_id: equipments[0].id, title: `E2E ${Date.now()} フォーカス`, reported_at: new Date().toISOString() } },
  })
  expect(created.ok()).toBeTruthy()
  const troubleId = (await created.json()).data.id

  await login(page, ACCOUNTS.admin)
  await page.goto(`/troubles/${troubleId}`)
  const edit = page.getByRole('button', { name: '編集' })
  await edit.click()
  await page.getByRole('dialog').getByRole('button', { name: 'キャンセル' }).click()
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(edit).toBeFocused()

  // 共通部品のダイアログ: 「計画」の点検の期限順の「前倒し」（シードの PT-502・LT-701）
  await page.goto('/plans?tab=due&diagnostic_advance=true')
  const chip = page.locator('[data-testid^="diagnostic-advance-chip-"]').first()
  await chip.click()
  const dialog = page.getByTestId('diagnostic-advance-dialog')
  await dialog.getByRole('button', { name: '閉じる' }).click()
  await expect(dialog).toHaveCount(0)
  await expect(chip).toBeFocused()

  await page.request.patch(`${api}/troubles/${troubleId}`, { headers, data: { trouble: { status: 'closed' } } })
})
