import { test, expect, login, apiBaseUrl, selectFirstOption, selectOption, openPlans, ACCOUNTS } from './support'
import type { APIRequestContext, Page } from '@playwright/test'

// 一覧の検索条件の保存（ユーザ・ページごとに localStorage）とリセット。
// 保存の維持を確かめるため、テストの途中では resetSession（localStorage を全部消す）を使わない
const CONTRACTOR = { email: 'yoshida@example.com', password: 'password' }

const field = (page: Page, label: string) => page.locator('.v-field', { has: page.getByLabel(label, { exact: true }) })
const listRequest = (page: Page, path: string) =>
  page.waitForRequest((req) => req.method() === 'GET' && new URL(req.url()).pathname.endsWith(`/api/v1/${path}`))

// 別のユーザに切り替える。検索条件は残し、トークンだけを消す
async function switchUser(page: Page, account: { email: string; password: string }) {
  await page.goto('/favicon.svg')
  await page.evaluate(() => localStorage.removeItem('jwt'))
  await login(page, account)
}

async function apiSession(request: APIRequestContext, account: { email: string; password: string }) {
  const api = apiBaseUrl()
  const response = await request.post(`${api}/login`, { data: { user: account } })
  expect(response.ok()).toBeTruthy()
  const headers = { Authorization: response.headers()['authorization'] }
  const me = (await (await request.get(`${api}/current_user`, { headers })).json()).user
  return { api, headers, me }
}

// 各一覧: 条件を1つ選ぶ → 再読み込みで戻る → リセットで外れ、再読み込みしても戻らない
const PAGES: { path: string; heading: string; label: string }[] = [
  { path: '/inspections', heading: '点検・作業記録', label: '種別' },
  { path: '/troubles', heading: 'トラブル管理', label: '優先度' },
  { path: '/instruments', heading: '装置・計器', label: '機器の診断' },
  { path: '/reference-standards', heading: '基準器', label: '状態' },
  { path: '/interlocks', heading: 'インターロック', label: 'バイパス' },
  { path: '/materials', heading: '資材管理', label: 'カテゴリ' },
  { path: '/stocks', heading: '在庫管理', label: 'ステータス' },
  { path: '/orders', heading: '発注', label: 'ステータス' },
  { path: '/repairs', heading: '修理', label: 'ステータス' },
  { path: '/users', heading: 'ユーザ管理', label: '権限' },
  { path: '/audit-logs', heading: '監査ログ', label: '操作' },
]

for (const { path, heading, label } of PAGES) {
  test(`${heading}: 検索条件を保存して再読み込みで戻し、リセットで既定に戻す`, async ({ page }) => {
    await login(page, ACCOUNTS.admin)
    await page.goto(path)
    await expect(page.getByRole('heading', { level: 1 })).toContainText(heading)
    await expect(field(page, label)).not.toHaveClass(/v-field--dirty/)
    await selectFirstOption(page, label)
    await expect(field(page, label)).toHaveClass(/v-field--dirty/)
    await page.reload()
    await expect(field(page, label)).toHaveClass(/v-field--dirty/)
    await page.getByTestId('filter-reset').click()
    await expect(field(page, label)).not.toHaveClass(/v-field--dirty/)
    await page.reload()
    await expect(field(page, label)).not.toHaveClass(/v-field--dirty/)
  })
}

test('設備台帳・拠点管理・部署管理も、選んだ条件を保存してリセットで戻す', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  const site = page.getByRole('button', { name: '表示する拠点を選ぶ' })

  await page.goto('/equipments')
  await site.click()
  await page.getByRole('button', { name: '全拠点', exact: true }).click()
  await page.keyboard.press('Escape')
  await page.reload()
  await expect(site).toContainText('全拠点')
  await page.getByTestId('filter-reset').click()
  await expect(site).not.toContainText('全拠点')
  await page.reload()
  await expect(site).not.toContainText('全拠点')

  await page.goto('/sites')
  const closed = page.getByLabel('閉鎖拠点を表示')
  await closed.check()
  await page.reload()
  await expect(closed).toBeChecked()
  await page.getByTestId('filter-reset').click()
  await expect(closed).not.toBeChecked()

  await page.goto('/departments')
  const siteSelect = field(page, '拠点で絞り込み')
  await expect(siteSelect).toContainText('製油所') // 拠点の一覧を取ったあと（名前が出る）
  const own = (await siteSelect.locator('.v-select__selection').innerText()).trim()
  await siteSelect.click()
  const other = page.getByRole('option').filter({ hasNotText: own }).first()
  const chosen = (await other.innerText()).trim()
  await other.click()
  await page.reload()
  await expect(siteSelect).toContainText(chosen)
  await page.getByTestId('filter-reset').click()
  await expect(siteSelect).toContainText(own)
  await page.reload()
  await expect(siteSelect).toContainText(own)
})

for (const width of [1440, 390]) test(`点検・作業記録（${width}px）: 3つの見方で同じ条件を使い、下書きは本人のものだけを再開できる。再読み込み・リセットも効く`, async ({ page, request }) => {
  await page.setViewportSize({ width, height: 900 })
  const member = await apiSession(request, ACCOUNTS.member)
  const admin = await apiSession(request, ACCOUNTS.admin)
  const equipment = (await (await request.get(`${member.api}/equipments?site_ids[]=${member.me.site_id}&per_page=1000`, { headers: member.headers })).json()).data[0]
  const stamp = `E2E ${Date.now()} 一覧の条件`
  const ids: number[] = []
  const draft = async (headers: Record<string, string>) => {
    const response = await request.post(`${member.api}/inspections`, { headers, data: { inspection: {
      equipment_id: equipment.id, department_id: member.me.department_id, inspected_at: new Date().toISOString(),
      inspection_type: 'telemetry', status: 'draft', notes: stamp, items: [{ content: '外観を確認', item_type: 'check', result: 'good' }],
    } } })
    expect(response.ok(), await response.text()).toBeTruthy()
    const record = (await response.json()).data
    ids.push(record.id)
    return record
  }
  const own = await draft(member.headers)
  const other = await draft(admin.headers)
  try {
    await login(page, ACCOUNTS.member)
    await page.goto('/inspections')
    await selectOption(page, '種別', 'テレメトリ')
    await selectOption(page, '設備', equipment.name, { exact: true })

    for (const [view, expected] of [['自分の下書き', { mine: 'true', status: 'draft' }], ['承認待ち', { status: 'approval_requested' }], ['すべての記録', {}]] as const) {
      const request = listRequest(page, 'inspections')
      await page.getByRole('button', { name: view, exact: true }).click()
      const params = new URL((await request).url()).searchParams
      expect(params.getAll('inspection_types[]')).toEqual(['telemetry'])
      expect(params.getAll('equipment_ids[]')).toEqual([String(equipment.id)])
      for (const [key, value] of Object.entries(expected)) expect(params.get(key)).toBe(value)
      await expect(field(page, '種別')).toContainText('テレメトリ')
      await expect(field(page, 'ステータス')).toHaveCount(view === 'すべての記録' ? 1 : 0)
    }

    await page.getByRole('button', { name: '自分の下書き', exact: true }).click()
    await expect(page).toHaveURL(/view=drafts/)
    await page.reload()
    await expect(field(page, '種別')).toContainText('テレメトリ')
    await expect(field(page, '設備')).toContainText(equipment.name)
    const resume = page.getByTestId(`inspection-draft-resume-${own.id}`)
    await expect(resume).toBeVisible()
    await expect(page.getByTestId(`inspection-draft-resume-${other.id}`)).toHaveCount(0)
    expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(1)
    await resume.click()
    await expect(page).toHaveURL(new RegExp(`/inspections/${own.id}/edit`))
    await page.goBack()
    await expect(page.getByTestId(`inspection-draft-resume-${own.id}`)).toBeVisible()
    await expect(field(page, '種別')).toContainText('テレメトリ')

    // リセット: 条件は既定に戻り、見方（自分の下書き）はそのまま
    await page.getByTestId('filter-reset').click()
    await expect(page).toHaveURL(/view=drafts/)
    await expect(field(page, '種別')).not.toHaveClass(/v-field--dirty/)
    await expect(field(page, '設備')).not.toHaveClass(/v-field--dirty/)
    await page.reload()
    await expect(field(page, '種別')).not.toHaveClass(/v-field--dirty/)
  } finally {
    for (const id of ids) {
      for (const status of ['approval_requested', 'approved']) {
        await request.patch(`${member.api}/inspections/${id}`, { headers: admin.headers, data: { inspection: { status } } })
      }
    }
  }
})

test('計画: 担当部署・法規区分は見方をまたいで引き継ぎ、期限順だけの条件は定期整備を経由しても戻る。すべてでは定期整備を消さない', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await openPlans(page, '定期点検')
  await selectOption(page, '点検の法規区分', 'ボイラー・第一種圧力容器')

  await page.getByRole('button', { name: '点検の期限順', exact: true }).click()
  await expect(field(page, '点検の法規区分')).toContainText('ボイラー・第一種圧力容器')
  await expect(page.getByTestId('plan-due').locator('tbody tr').first()).toContainText('ボイラー・第一種圧力容器')
  await page.getByLabel('期限超過のみ').check()

  await page.locator('.v-btn-toggle').getByRole('button', { name: '定期整備', exact: true }).click()
  await expect(page.getByTestId('plan-maintenances')).toBeVisible()
  await expect(page.getByLabel('期限超過のみ')).toHaveCount(0) // 期限順だけの条件は出さない
  await page.locator('.v-btn-toggle').getByRole('button', { name: '定期点検', exact: true }).click()
  await expect(field(page, '点検の法規区分')).toContainText('ボイラー・第一種圧力容器')
  await page.getByRole('button', { name: '点検の期限順', exact: true }).click()
  await expect(page.getByLabel('期限超過のみ')).toBeChecked()

  await page.locator('.v-btn-toggle').getByRole('button', { name: 'すべて', exact: true }).click()
  await expect(page.getByTestId('plan-groups').locator('tbody tr')).toHaveCount(1)
  await expect(page.getByTestId('plan-maintenances').locator('tbody tr').first()).not.toContainText('該当する定期整備はありません')

  await page.reload()
  await expect(field(page, '点検の法規区分')).toContainText('ボイラー・第一種圧力容器')
  await page.getByTestId('filter-reset').click()
  await expect(page).toHaveURL(/tab=all/)
  await expect(field(page, '点検の法規区分')).not.toHaveClass(/v-field--dirty/)
  await page.getByRole('button', { name: '点検の期限順', exact: true }).click()
  await expect(page.getByLabel('期限超過のみ')).not.toBeChecked()
  await page.reload()
  await expect(field(page, '点検の法規区分')).not.toHaveClass(/v-field--dirty/)
})

test('トラブル: ステータスの全解除を保存し、リンクの条件は保存した条件と混ぜない。ページ・ユーザで分ける', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/troubles')
  await expect(field(page, 'ステータス')).toHaveClass(/v-field--dirty/) // 既定は完了を除く3つ
  await field(page, 'ステータス').hover() // 消すボタンは、入力欄に乗せたときだけ出る
  await field(page, 'ステータス').getByLabel(/クリア/).click()
  await expect(field(page, 'ステータス')).not.toHaveClass(/v-field--dirty/)
  await selectOption(page, '優先度', '緊急')
  await page.reload()
  await expect(field(page, 'ステータス')).not.toHaveClass(/v-field--dirty/) // 全解除のまま（未完了に戻さない）
  await expect(field(page, '優先度')).toContainText('緊急')

  // 計器の「すべて見る」のようなリンクでは、保存した優先度を混ぜない
  const linked = listRequest(page, 'troubles')
  await page.goto('/troubles?instrument_id=1&site_ids=all')
  expect(new URL((await linked).url()).searchParams.getAll('priorities[]')).toEqual([])
  await expect(page.getByTestId('instrument-filter-chip')).toBeVisible()
  // リンクで開いただけでは保存を上書きしない
  await page.goto('/troubles')
  await expect(field(page, '優先度')).toContainText('緊急')

  // ほかのページには影響しない
  await page.goto('/inspections')
  await expect(field(page, '種別')).not.toHaveClass(/v-field--dirty/)

  // 別のユーザには出ず、元のユーザに戻ると戻る
  await switchUser(page, ACCOUNTS.admin)
  await page.goto('/troubles')
  await expect(field(page, '優先度')).not.toHaveClass(/v-field--dirty/)
  await switchUser(page, ACCOUNTS.member)
  await page.goto('/troubles')
  await expect(field(page, '優先度')).toContainText('緊急')
})

test('保存データが壊れている・型が違う・localStorage が使えないときも、既定の条件で一覧を使える', async ({ page, request }) => {
  const member = await apiSession(request, ACCOUNTS.member)
  await login(page, ACCOUNTS.member)
  await page.evaluate((id) => {
    localStorage.setItem(`plant-keeper:list-filters:v1:${id}:troubles`, '{broken')
    localStorage.setItem(`plant-keeper:list-filters:v1:${id}:inspections`, JSON.stringify({ equipment_ids: ['x', -1], inspection_types: ['unknown'], department_id: 999999999 }))
  }, member.me.id)
  await page.goto('/troubles')
  await expect(field(page, 'ステータス')).toHaveClass(/v-field--dirty/)
  const request2 = listRequest(page, 'inspections')
  await page.goto('/inspections')
  const params = new URL((await request2).url()).searchParams
  expect(params.getAll('equipment_ids[]')).toEqual([])
  expect(params.getAll('inspection_types[]')).toEqual([])
  // 存在しない部署は、部署の選択肢を取ったあとで外れる
  await expect(field(page, '部署')).not.toHaveClass(/v-field--dirty/)

  await page.addInitScript(() => {
    const getItem = Storage.prototype.getItem
    const setItem = Storage.prototype.setItem
    Storage.prototype.getItem = function (key: string) {
      if (key.startsWith('plant-keeper:list-filters')) throw new Error('blocked')
      return getItem.call(this, key)
    }
    Storage.prototype.setItem = function (key: string, value: string) {
      if (key.startsWith('plant-keeper:list-filters')) throw new Error('blocked')
      return setItem.call(this, key, value)
    }
  })
  await page.goto('/troubles')
  await selectOption(page, '優先度', '高')
  await expect(page.locator('tbody tr').first()).toBeVisible()
})

test('協力会社は、保存した拠点にかかわらず所属拠点で開く', async ({ page, request }) => {
  const contractor = await apiSession(request, CONTRACTOR)
  await login(page, CONTRACTOR)
  await page.evaluate((id) => {
    localStorage.setItem(`plant-keeper:list-filters:v1:${id}:troubles`, JSON.stringify({ site_ids: [] }))
  }, contractor.me.id)
  const troubles = listRequest(page, 'troubles')
  await page.goto('/troubles')
  expect(new URL((await troubles).url()).searchParams.getAll('site_ids[]')).toEqual([String(contractor.me.site_id)])
})
