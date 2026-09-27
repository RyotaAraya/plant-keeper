import { test, expect, login, apiBaseUrl, ACCOUNTS, findListRow } from './support'

// 機器の診断で、点検計画の次回期限を前倒しする候補（保守要求・仕様外）。
// 診断は計器のいまの状態を変えるため、シードの計器は使わず、E2E 専用の計器（E2E-DIAG-M。なければAPIで作る）に送る。
// 実行のたびに、トークンと、この計器の計画（名前が `E2E ` で始まる）をAPIで作り、最後に計器を正常に戻し、計画を無効にし、トークンを失効する
const TAG = 'E2E-DIAG-M'

test('保守要求になった計器の計画は「診断で前倒しの候補」に出て、管理者は期限を今日にできる', async ({ page }) => {
  const api = apiBaseUrl()
  const loginRes = await page.request.post(`${api}/login`, { data: { user: ACCOUNTS.admin } })
  const headers = { Authorization: loginRes.headers()['authorization'] }
  const get = async (path: string, params: Record<string, any> = {}) => (await (await page.request.get(`${api}${path}`, { headers, params })).json()).data
  const me = (await (await page.request.get(`${api}/current_user`, { headers })).json()).user

  let instrument = (await get('/instruments', { q: TAG, 'site_ids[]': me.site_id })).find((i: any) => i.tag_number === TAG)
  if (!instrument) {
    const equipments = await get('/equipments', { per_page: 1000, 'site_ids[]': me.site_id })
    const tank = equipments.find((e: any) => e.name === 'タンク設備') ?? equipments[0]
    const created = await page.request.post(`${api}/instruments`, { headers, data: { instrument: { equipment_id: tank.id, tag_number: TAG, instrument_type: 'pressure_transmitter' } } })
    expect(created.ok()).toBeTruthy()
    instrument = (await created.json()).data
  }
  const stamp = `E2E ${Date.now()}`
  const issued = await page.request.post(`${api}/integration_tokens`, { headers, data: { integration_token: { site_id: me.site_id, name: stamp } } })
  expect(issued.ok()).toBeTruthy()
  const token = (await issued.json()).data
  const send = (status: string) => page.request.post(`${api}/integrations/device_diagnostics`, {
    headers: { 'X-Integration-Token': token.token },
    data: { diagnostics: [{ tag_number: TAG, status, code: 'DRIFT', message: 'センサのドリフト', occurred_at: new Date().toISOString() }] },
  })
  const template = (await get('/checklist_templates')).find((t: any) => t.name === '伝送器 年次点検')
  const name = `${stamp} ${TAG} 年次校正`
  const created = await page.request.post(`${api}/inspection_plans`, {
    headers,
    data: { inspection_plan: { name, equipment_id: instrument.equipment_id, instrument_id: instrument.id, checklist_template_id: template.id,
                               inspection_type: 'periodic', interval_days: 365, next_due_on: '2099-01-01' } },
  })
  expect(created.ok()).toBeTruthy()
  const planId = (await created.json()).data.id

  try {
    expect((await send('M')).ok()).toBeTruthy()

    await login(page, ACCOUNTS.admin)
    await page.goto('/plans?tab=due&diagnostic_advance=true')
    const row = await findListRow(page, page.getByRole('row', { name: new RegExp(name) }))
    await row.getByTestId(`diagnostic-advance-chip-${planId}`).click()
    const dialog = page.getByTestId('diagnostic-advance-dialog')
    await expect(dialog).toContainText('保守要求')
    await expect(dialog).toContainText('センサのドリフト（DRIFT）')
    await expect(dialog).toContainText('2099-01-01')
    await dialog.getByTestId('diagnostic-advance-save').click()
    await expect(dialog).toBeHidden()
    // 期限を今日にすると、候補から外れる
    await expect(page.getByRole('row', { name: new RegExp(name) })).toHaveCount(0)
    const plan = (await get('/inspection_plans', { per_page: 1000, 'site_ids[]': me.site_id })).find((p: any) => p.id === planId)
    expect(plan.days_until_due).toBe(0)
    expect(plan.diagnostic_advance).toBeNull()
  } finally {
    expect((await send('N')).ok()).toBeTruthy()
    await page.request.patch(`${api}/inspection_plans/${planId}`, { headers, data: { inspection_plan: { is_active: false } } })
    await page.request.post(`${api}/integration_tokens/${token.id}/revoke`, { headers })
  }
})

test('一般ユーザには前倒しの根拠だけを見せ、期限は変えられない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/plans?tab=due&diagnostic_advance=true')
  // シードのデモ（PT-502 は保守要求、LT-701 は仕様外）
  const chip = page.locator('[data-testid^="diagnostic-advance-chip-"]').first()
  await chip.click()
  const dialog = page.getByTestId('diagnostic-advance-dialog')
  await expect(dialog).toContainText('前倒しの候補')
  await expect(dialog.getByTestId('diagnostic-advance-save')).toHaveCount(0)
})
