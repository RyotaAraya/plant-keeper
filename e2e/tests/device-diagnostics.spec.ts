import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'

// 機器の自己診断（NAMUR NE 107）の受け口。診断は計器のいまの状態を変えるため、シードの計器は使わず、
// E2E 専用の計器（E2E-DIAG。なければAPIで作る）に送り、最後に「正常」に戻す。トークンは実行のたびに発行し、最後に失効する。
// 試しに送る診断は故障（F）で、計器のトラブルが自動で登録される。同じ計器に未解決のものがあると重ねて作らないため、
// 始める前と最後に、この計器の診断から作ったトラブルを完了にする
const TAG = 'E2E-DIAG'

test('管理者はトークンを発行して試しに送れ、計器の一覧・詳細に診断が出て、失効したトークンは受け付けない', async ({ page }) => {
  const api = apiBaseUrl()
  const loginRes = await page.request.post(`${api}/login`, { data: { user: ACCOUNTS.admin } })
  const headers = { Authorization: loginRes.headers()['authorization'] }
  const me = (await (await page.request.get(`${api}/current_user`, { headers })).json()).user
  const found = (await (await page.request.get(`${api}/instruments`, { headers, params: { q: TAG, 'site_ids[]': me.site_id } })).json()).data
  let instrument = found.find((i: any) => i.tag_number === TAG)
  if (!instrument) {
    const equipments = (await (await page.request.get(`${api}/equipments?per_page=1000&site_ids[]=${me.site_id}`, { headers })).json()).data
    const tank = equipments.find((e: any) => e.name === 'タンク設備') ?? equipments[0]
    const created = await page.request.post(`${api}/instruments`, { headers, data: { instrument: { equipment_id: tank.id, tag_number: TAG, instrument_type: 'pressure_transmitter' } } })
    expect(created.ok()).toBeTruthy()
    instrument = (await created.json()).data
  }
  const stamp = `E2E ${Date.now()}`
  const closeDiagnosticTroubles = async () => {
    const troubles = (await (await page.request.get(`${api}/troubles`, { headers, params: { instrument_id: instrument.id, per_page: 100 } })).json()).data
    for (const trouble of troubles.filter((t: any) => t.source === 'device_diagnostic' && t.status !== 'closed')) {
      expect((await page.request.patch(`${api}/troubles/${trouble.id}`, { headers, data: { trouble: { status: 'closed' } } })).ok()).toBeTruthy()
    }
  }
  await closeDiagnosticTroubles()

  await login(page, ACCOUNTS.admin)
  await page.goto('/settings')
  await page.getByRole('link', { name: '外部連携' }).click()
  await expect(page).toHaveURL(/\/settings\/integrations$/)

  await page.getByTestId('integration-issue').click()
  await page.getByTestId('integration-name').locator('input').fill(stamp)
  await page.getByTestId('integration-issue-submit').click()
  const raw = await page.getByTestId('integration-token-value').locator('input').inputValue()
  expect(raw).toMatch(/^pkint_/)

  const send = (status: string) => page.request.post(`${api}/integrations/device_diagnostics`, {
    headers: { 'X-Integration-Token': raw },
    data: { diagnostics: [{ tag_number: TAG, status, occurred_at: new Date().toISOString() }] },
  })

  try {
    // 試しに送る（本物の受け口に、発行したトークンで送る）
    await page.getByTestId('integration-test-tag').locator('input').fill(TAG)
    await page.getByTestId('integration-test-send').click()
    await expect(page.getByTestId('integration-test-result')).toContainText('計器の状態が変わりました')
    await expect(page.getByTestId('integration-test-result')).toContainText('故障のためトラブルを登録しました')
    await page.getByTestId('integration-issue-close').click()
    const row = page.locator('[data-testid^="integration-token-"]', { hasText: stamp })
    await expect(row.locator('td').nth(4)).not.toHaveText('未使用')
    await expect(row.locator('td').nth(5)).toHaveText('有効')

    // 計器の一覧（故障で絞り込み）と詳細
    await page.goto('/instruments?diagnostic_status=failure')
    const listRow = page.locator('tbody tr', { hasText: TAG })
    await expect(listRow.getByTestId('diagnostic-chip')).toHaveText('F 故障')
    await listRow.click()
    await expect(page.getByTestId('diagnostic-current').getByTestId('diagnostic-chip')).toHaveText('F 故障')
    await page.getByRole('tab', { name: '機器の診断' }).click()
    const latest = page.getByTestId('diagnostic-history').locator('tbody tr').first()
    await expect(latest.locator('td').nth(1)).toHaveText('F 故障')
    await expect(latest.locator('td').nth(4)).toHaveText(stamp)

    // 故障から自動で登録したトラブル（報告者は人ではなく連携）
    await page.getByTestId('diagnostic-trouble').getByRole('link', { name: `${TAG} 機器の診断で故障` }).click()
    await expect(page).toHaveURL(/\/troubles\/\d+$/)
    await expect(page.getByTestId('detail-summary')).toContainText(`機器の診断（${stamp}）`)
    await expect(page.getByTestId('trouble-diagnostic-source').getByTestId('diagnostic-chip')).toHaveText('F 故障')
  } finally {
    // 計器を正常に戻し、自動のトラブルを完了にしてから、トークンを画面で失効する
    expect((await send('N')).ok()).toBeTruthy()
    await closeDiagnosticTroubles()
    await page.goto('/settings/integrations')
    await page.locator('[data-testid^="integration-token-"]', { hasText: stamp }).getByRole('button', { name: '失効' }).click()
    await page.getByTestId('integration-revoke-submit').click()
    await expect(page.locator('[data-testid^="integration-token-"]', { hasText: stamp }).locator('td').nth(5)).toContainText('失効')
  }
  expect((await send('F')).status()).toBe(401)
})

test('外部連携は管理者だけで、一般ユーザには開けない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/settings/integrations')
  await expect(page).toHaveURL(/\/home$/)
  const res = await page.request.get(`${apiBaseUrl()}/integration_tokens`, {
    headers: { Authorization: `Bearer ${await page.evaluate(() => localStorage.getItem('jwt'))}` },
  })
  expect(res.status()).toBe(403)
})
