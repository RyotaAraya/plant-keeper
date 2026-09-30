import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'
import type { APIRequestContext } from '@playwright/test'
import { todayForInput } from '../../frontend/src/utils/datetime'

async function setup(request: APIRequestContext) {
  const api = apiBaseUrl()
  async function session(account: { email: string; password: string }) {
    const response = await request.post(`${api}/login`, { data: { user: account } })
    expect(response.ok()).toBeTruthy()
    const headers = { Authorization: response.headers()['authorization'] }
    const get = async (path: string) => (await (await request.get(`${api}${path}`, { headers })).json())
    return { headers, get, me: (await get('/current_user')).user }
  }
  const member = await session(ACCOUNTS.member)
  const manager = await session(ACCOUNTS.admin)
  const stamp = `E2E ${Date.now()}-${Math.random().toString(36).slice(2, 7)} 再開の確認`
  const equipment = (await member.get(`/equipments?site_ids[]=${member.me.site_id}&per_page=1000`)).data[0]
  const create = async (path: string, data: unknown, headers = manager.headers) => {
    const response = await request.post(`${api}${path}`, { headers, data })
    expect(response.ok(), await response.text()).toBeTruthy()
    return (await response.json()).data
  }
  const group = await create('/inspection_plan_groups', { inspection_plan_group: { name: stamp, site_id: member.me.site_id, department_id: member.me.department_id } })
  const yesterday = new Date(Date.now() - 86400000)
  const plan = await create('/inspection_plans', { inspection_plan: { name: stamp, equipment_id: equipment.id, inspection_plan_group_id: group.id, inspection_type: 'routine', interval_days: 7, next_due_on: yesterday.toLocaleDateString('sv-SE', { timeZone: 'Asia/Tokyo' }) } })
  const ids: number[] = []
  const draft = async (owner = member, planned = true) => {
    const record = await create('/inspections', { inspection: {
      equipment_id: equipment.id, department_id: member.me.department_id, inspection_plan_id: planned ? plan.id : null,
      inspected_at: yesterday.toISOString(), inspection_type: 'routine', status: 'draft', notes: stamp,
      items: [{ content: '外観を確認', item_type: 'check', result: 'good' }],
    } }, owner.headers)
    ids.push(record.id)
    return record
  }
  const cleanup = async () => {
    for (const id of ids) {
      const record = (await manager.get(`/inspections/${id}`)).data
      if (record.status === 'draft') {
        const response = await request.patch(`${api}/inspections/${id}`, { headers: manager.headers, data: { inspection: { status: 'submitted' } } })
        expect(response.ok()).toBeTruthy()
      }
    }
    expect((await request.patch(`${api}/inspection_plans/${plan.id}`, { headers: manager.headers, data: { inspection_plan: { is_active: false } } })).ok()).toBeTruthy()
    expect((await request.patch(`${api}/inspection_plan_groups/${group.id}`, { headers: manager.headers, data: { inspection_plan_group: { is_active: false } } })).ok()).toBeTruthy()
  }
  return { member, manager, plan, draft, cleanup }
}

for (const mobile of [false, true]) {
  test(`${mobile ? 'スマホ' : 'PC'}で前日の下書きを計画から再開・提出し、元のホームへ戻れる`, async ({ page }) => {
    if (mobile) await page.setViewportSize({ width: 390, height: 844 })
    const data = await setup(page.request)
    const record = await data.draft()
    const other = await data.draft(data.manager)
    try {
      await login(page, ACCOUNTS.member)
      const urgent = page.getByTestId(`home-urgent-plan-${data.plan.id}`)
      await expect(urgent).toBeVisible()
      // 所属の通常一覧より前に、部署をまたいだ期限超過を出す。
      const order = await page.locator('[data-testid="home-urgent"], [data-testid^="home-area-"]').evaluateAll((els) => els.map((e) => e.getAttribute('data-testid')))
      expect(order[0]).toBe('home-urgent')
      await urgent.getByRole('link', { name: '点検を実施' }).click()
      await expect(page.getByTestId('inspection-plan-context')).toContainText(data.plan.name)
      const own = page.getByTestId(`inspection-draft-${record.id}`)
      await expect(own).toBeVisible()
      await expect(page.getByTestId(`inspection-draft-${other.id}`)).toHaveCount(0)
      await expect(page.getByRole('button', { name: '提出', exact: true })).toHaveCount(0)
      await own.getByRole('link', { name: /入力を再開/ }).click()
      await expect(page).toHaveURL(new RegExp(`/inspections/${record.id}/edit`))
      await expect(page.getByRole('textbox', { name: '内容', exact: true })).toHaveValue('外観を確認')
      await page.getByRole('button', { name: '提出', exact: true }).click()
      await expect(page).toHaveURL(new RegExp(`/inspections/${record.id}\\?saved=submitted`))
      await expect(page.getByTestId('inspection-saved')).toContainText('点検を提出しました')
      const currentPlan = (await data.member.get(`/inspection_plans/${data.plan.id}`)).data
      expect(currentPlan.next_due_on > todayForInput()).toBeTruthy()
      await expect(page.getByTestId('inspection-plan-context')).toContainText(currentPlan.next_due_on)
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)
      expect(overflow).toBeLessThanOrEqual(1)
      await page.getByTestId('inspection-saved').getByRole('link', { name: 'ホームに戻る' }).click()
      await expect(page.getByRole('heading', { level: 1, name: 'ホーム' })).toBeVisible()
      await expect(page.getByTestId(`home-urgent-plan-${data.plan.id}`)).toHaveCount(0)
      await expect(page.getByTestId(`inspection-draft-${record.id}`)).toHaveCount(0)
    } finally { await data.cleanup() }
  })
}

test('複数の本人の下書きを並べ、別の記録を作る操作を明示する。取得失敗時は再確認できる', async ({ page }) => {
  const data = await setup(page.request)
  const first = await data.draft()
  const second = await data.draft()
  try {
    await login(page, ACCOUNTS.member)
    await page.route('**/api/v1/inspections?*', (route) => route.abort('failed'))
    await page.goto(`/inspections/new?inspection_plan_id=${data.plan.id}`)
    await expect(page.getByText('下書きを読み込めませんでした。')).toBeVisible()
    await expect(page.getByRole('button', { name: '提出', exact: true })).toHaveCount(0)
    await page.unroute('**/api/v1/inspections?*')
    await page.getByRole('button', { name: '下書きを再確認' }).click()
    await expect(page.getByTestId(`inspection-draft-${first.id}`)).toBeVisible()
    await expect(page.getByTestId(`inspection-draft-${second.id}`)).toBeVisible()
    await page.getByRole('button', { name: '別の点検記録を作成' }).click()
    await expect(page.getByRole('button', { name: '提出', exact: true })).toBeVisible()
  } finally { await data.cleanup() }
})

test('予定外の下書きは期限を更新せず、外部の戻り先は使わない', async ({ page }) => {
  const data = await setup(page.request)
  const record = await data.draft(data.member, false)
  try {
    await login(page, ACCOUNTS.member)
    await page.goto(`/inspections/${record.id}/edit?return_to=https://example.com`)
    await expect(page.getByTestId('inspection-unplanned-context')).toContainText('期限は更新しません')
    await expect(page.getByTestId('reference-standards-section')).toHaveCount(0)
    await page.getByRole('button', { name: '下書き保存', exact: true }).click()
    await expect(page.getByTestId('inspection-saved')).toContainText('下書きを保存しました')
    await expect(page.getByTestId('inspection-saved').getByRole('link')).toHaveAttribute('href', '/inspections')
    await page.getByRole('button', { name: '提出', exact: true }).click()
    await expect(page.getByTestId('inspection-saved')).toHaveCount(0)
    expect((await data.member.get(`/inspection_plans/${data.plan.id}`)).data.next_due_on).toBe(data.plan.next_due_on)
  } finally { await data.cleanup() }
})
