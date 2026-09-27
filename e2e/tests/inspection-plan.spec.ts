import { test, expect, login, resetSession, apiBaseUrl, selectOption, ACCOUNTS } from './support'

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

// 周期の見直しの候補: シードの年次校正の計画（FT-301 は短縮、PT-701 は延長の候補）。根拠を見て、権限のある人は周期を変えられる
test('一般ユーザは、見直しの候補と根拠を見られるが、周期は変えられない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/inspection-plans?interval_review=shorten')
  const row = page.locator('tbody tr', { hasText: 'FT-301 流量伝送器 年次校正' })
  await row.getByText('短縮の候補').click()

  const dialog = page.getByTestId('interval-review-dialog')
  await expect(dialog).toContainText('調整前が許容差を超えていました（0.72% / ±0.5%）')
  await expect(dialog).toContainText('0.25 → 0.41 → 0.72%')
  await expect(dialog.getByTestId('interval-review-save')).toHaveCount(0)
  await expect(dialog.getByRole('link', { name: 'FT-301 の校正の傾向を見る' })).toBeVisible()
})

test('業務管理者は、延長の候補の根拠と注意を見て周期を変えられ、変えたあとは同じ候補が出ない', async ({ page }) => {
  // シードの計画を変えないよう、同じ計器（PT-701）の年次校正の計画をAPIで自分用に作る
  await login(page, OWNER_MANAGER)
  const token = await page.evaluate(() => localStorage.getItem('jwt'))
  const headers = { Authorization: `Bearer ${token}` }
  const get = async (path: string) => (await (await page.request.get(`${apiBaseUrl()}${path}`, { headers })).json()).data
  const instrument = (await get('/instruments?q=PT-701')).find((i: any) => i.tag_number === 'PT-701')
  const template = (await get('/checklist_templates')).find((t: any) => t.name === '伝送器 年次点検')
  const name = `E2E ${Date.now()} PT-701 年次校正`
  const created = await page.request.post(`${apiBaseUrl()}/inspection_plans`, {
    headers,
    data: { inspection_plan: { name, equipment_id: instrument.equipment_id, instrument_id: instrument.id, checklist_template_id: template.id,
                               inspection_type: 'periodic', interval_days: 365, next_due_on: '2027-09-01' } },
  })
  expect(created.ok()).toBeTruthy()
  const planId = (await created.json()).data.id

  try {
    await page.goto('/inspection-plans?interval_review=extend')
    const row = page.locator('tbody tr', { hasText: name })
    await row.getByText('延長の候補').click()
    const dialog = page.getByTestId('interval-review-dialog')
    await expect(dialog).toContainText('調整前が許容差の50%以下')
    await expect(dialog).toContainText('インターロック（I-702）に関わる計器です')
    await expect(dialog.getByTestId('interval-review-days').locator('input')).toHaveValue('730')
    await dialog.getByTestId('interval-review-save').click()

    await expect(dialog).toBeHidden()
    await expect(page.locator('tbody tr', { hasText: name })).toHaveCount(0) // 延長の候補から外れる
    await page.goto('/inspection-plans')
    await expect(page.locator('tbody tr', { hasText: name })).toContainText('730日ごと')
  } finally {
    await page.request.patch(`${apiBaseUrl()}/inspection_plans/${planId}`, { headers, data: { inspection_plan: { is_active: false } } })
  }
})

// 点検計画は、必ず点検のまとまり（親）に属す。担当部署・法規区分はまとまりが持つ
test('点検計画にまとまりと法規区分が表示され、法規区分・まとまりで絞り込める', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.getByRole('link', { name: '点検計画', exact: true }).click()

  const valve = page.getByRole('row', { name: /ボイラー安全弁 年次点検/ })
  await expect(valve).toContainText('安全弁 年次点検')
  await expect(valve).toContainText('ボイラー・第一種圧力容器')

  await test.step('法規区分で絞り込むと、その区分のまとまりの計画だけになる', async () => {
    await selectOption(page, '法規区分', 'ボイラー・第一種圧力容器')
    await expect(page.getByRole('row', { name: /FT-301 流量伝送器 ゼロ点確認/ })).toHaveCount(0)
    for (const text of await page.locator('tbody tr').allInnerTexts()) expect(text).toContain('ボイラー・第一種圧力容器')
    await page.goto('/inspection-plans') // 絞り込みを外す
  })

  await test.step('まとまりで絞り込むと、そのまとまりの計画だけになる', async () => {
    await selectOption(page, 'まとまり', '伝送器 月次点検', { exact: true })
    await expect(page.getByRole('row', { name: /FT-301 流量伝送器 ゼロ点確認/ })).toBeVisible()
    await expect(page.getByRole('row', { name: /ボイラー安全弁 年次点検/ })).toHaveCount(0)
  })
})

test('業務管理者は、まとまりを選んで点検計画を追加でき、周期にまとまりの既定の周期が入る', async ({ page }) => {
  await login(page, OWNER_MANAGER)
  await page.getByRole('link', { name: '点検計画', exact: true }).click()
  await page.getByRole('button', { name: '計画を追加' }).click()
  const dialog = page.getByRole('dialog')
  const name = `E2E ${Date.now()} まとまりの計画`

  await dialog.getByLabel('計画名').fill(name)
  await expect(dialog.getByRole('button', { name: '保存' })).toBeDisabled() // まとまりは必須
  await dialog.locator('.v-field', { has: page.getByLabel('設備', { exact: true }) }).click()
  await page.getByRole('option', { name: '常圧蒸留装置', exact: true }).click()
  await page.keyboard.press('Escape')
  await dialog.locator('.v-field', { has: page.getByLabel('まとまり', { exact: true }) }).click()
  await page.getByRole('option', { name: '伝送器 月次点検', exact: true }).click()
  await expect(dialog.getByLabel('周期（日）')).toHaveValue('30')

  const saved = page.waitForResponse((res) => res.url().endsWith('/inspection_plans') && res.request().method() === 'POST')
  await dialog.getByRole('button', { name: '保存' }).click()
  const planId = (await (await saved).json()).data.id
  try {
    await expect(dialog).toBeHidden()
    await expect(page.getByRole('row', { name: new RegExp(name) })).toContainText('伝送器 月次点検')
  } finally {
    const token = await page.evaluate(() => localStorage.getItem('jwt'))
    await page.request.patch(`${apiBaseUrl()}/inspection_plans/${planId}`, { headers: { Authorization: `Bearer ${token}` }, data: { inspection_plan: { is_active: false } } })
  }
})
