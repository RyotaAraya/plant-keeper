import { test, expect, login, apiBaseUrl, selectOption, ACCOUNTS } from './support'
import { todayForInput } from '../../frontend/src/utils/datetime'
import type { APIRequestContext } from '@playwright/test'

// 朝会・夕会ボード。シードのデモ（実施中の定期整備・今日と明日が期限の計画）は投入日からの相対日付で、
// stg では日がたつと期限超過に移るため、件数や位置を決め打ちせず、確かめたい行はAPIで自分用に作って最後に片付ける
const MANAGER = { email: 'suzuki@example.com', password: 'password' }

async function apiSession(request: APIRequestContext, account: { email: string; password: string }) {
  const api = apiBaseUrl()
  const res = await request.post(`${api}/login`, { data: { user: account } })
  expect(res.ok()).toBeTruthy()
  const headers = { Authorization: res.headers()['authorization'] }
  const get = async (path: string) => (await (await request.get(`${api}${path}`, { headers })).json())
  const me = (await get('/current_user')).user
  return { api, headers, get, me }
}

// 佐藤（計器Aチーム）の拠点の部署を名前で
async function departmentId(get: (path: string) => Promise<any>, siteId: number, name: string): Promise<number> {
  const departments = (await get(`/departments?site_id=${siteId}`)).data
  const found = departments.find((d: any) => d.name === name)
  expect(found, `部署 ${name}`).toBeTruthy()
  return found.id
}

const BYPASS_RANK: Record<string, number> = { 復帰期限超過: 0, バイパス中: 1, 復帰確認待ち: 2 }

test('自分の所属（チーム）の範囲で開き、課のチェックリストの計画が今日の欄に出て点検へ進め、部署を変えると外れる', async ({ page }) => {
  const { api, headers, get } = await apiSession(page.request, MANAGER)
  const instrument = (await get('/instruments?q=PT-801')).data.find((i: any) => i.tag_number === 'PT-801')
  const template = (await get('/checklist_templates')).data.find((t: any) => t.name === '伝送器 月次点検') // 計装保全課（課）のチェックリスト
  const name = `E2E ${Date.now()} PT-801 月次点検`
  const created = await page.request.post(`${api}/inspection_plans`, {
    headers,
    data: { inspection_plan: { name, equipment_id: instrument.equipment_id, instrument_id: instrument.id, checklist_template_id: template.id,
                               inspection_type: 'periodic', interval_days: 30, next_due_on: todayForInput() } },
  })
  expect(created.ok()).toBeTruthy()
  const planId = (await created.json()).data.id

  try {
    await login(page, ACCOUNTS.member)
    await page.getByRole('link', { name: '朝会・夕会ボード', exact: true }).click()
    await expect(page).toHaveURL(/\/meeting-board$/)
    await expect(page.getByTestId('board-day')).toContainText('計器Aチーム')

    // チームを選んでいても、課に割り当てたチェックリストの計画は出る
    const plan = page.getByTestId(`board-plan-${planId}`)
    await expect(page.getByTestId('board-plans-today').getByTestId(`board-plan-${planId}`)).toContainText(name)
    await expect(plan).toContainText('計装保全課')

    // インターロックは、復帰期限超過 → バイパス中 → 復帰確認待ちの順（件数はシードの相対時刻で変わるため決め打ちしない）
    const bypasses = page.getByTestId('board-bypasses')
    const labels = await bypasses.locator('li .v-chip').allTextContents()
    const ranks = labels.map((label) => BYPASS_RANK[label.trim()])
    expect(ranks.every((rank) => rank !== undefined)).toBeTruthy()
    expect(ranks).toEqual([...ranks].sort((a, b) => a - b))

    // 部署を製造部に変えると、計装保全課の計画は外れる。インターロックは部署で絞らない
    await selectOption(page, '部', '製造部', { exact: true })
    await expect(page.getByTestId('board-day')).toContainText('製造部')
    await expect(page.getByTestId(`board-plan-${planId}`)).toHaveCount(0)
    await expect(bypasses.locator('li .v-chip')).toHaveCount(labels.length)

    // 所属に戻して、計画から点検を実施する
    await page.getByRole('button', { name: '自分の所属に戻す' }).click()
    await page.getByTestId(`board-plan-${planId}`).getByRole('link', { name: '点検を実施' }).click()
    await expect(page).toHaveURL(new RegExp(`/inspections/new\\?.*inspection_plan_id=${planId}`))
  } finally {
    const retired = await page.request.patch(`${api}/inspection_plans/${planId}`, { headers, data: { inspection_plan: { is_active: false } } })
    expect(retired.ok()).toBeTruthy()
  }
})

test('トラブルは緊急が先頭で、自分が報告した未対応のトラブルが出る', async ({ page }) => {
  const { api, headers, get, me } = await apiSession(page.request, ACCOUNTS.member)
  const equipment = (await get(`/equipments?per_page=1000&site_ids[]=${me.site_id}`)).data[0]
  const title = `E2E ${Date.now()} 朝会ボードの緊急トラブル`
  const created = await page.request.post(`${api}/troubles`, {
    headers, data: { trouble: { equipment_id: equipment.id, title, description: '朝会ボードの確認', priority: 'critical', reported_at: new Date().toISOString() } },
  })
  expect(created.ok()).toBeTruthy()
  const id = (await created.json()).data.id

  try {
    await login(page, ACCOUNTS.member)
    await page.goto('/meeting-board')
    const rows = page.getByTestId('board-troubles').locator('tbody tr')
    const row = page.getByTestId(`board-trouble-${id}`)
    await expect(row.locator('td').nth(0)).toHaveText('緊急')
    await expect(row.locator('td').nth(1)).toHaveText('未対応')
    await expect(row.locator('td').nth(2)).toHaveText(title)

    // 緊急の行が、ほかの優先度より前にそろっている（「緊急」の列を完全一致で）
    const priorities = (await rows.evaluateAll((trs) => trs.map((tr) => tr.querySelector('td')?.textContent?.trim() ?? '')))
    const firstOther = priorities.findIndex((p) => p !== '緊急')
    if (firstOther >= 0) expect(priorities.slice(firstOther)).not.toContain('緊急')

    await row.getByRole('link', { name: title }).click()
    await expect(page).toHaveURL(new RegExp(`/troubles/${id}$`))
  } finally {
    // 一般ユーザはトラブルを更新できないため、業務管理者が完了にする
    const manager = await apiSession(page.request, MANAGER)
    const closed = await page.request.patch(`${api}/troubles/${id}`, { headers: manager.headers, data: { trouble: { status: 'closed' } } })
    expect(closed.ok()).toBeTruthy()
  }
})

test('実施中の定期整備の作業は、自分のチームと上位の課のものが出て、ほかの課の作業は出ない', async ({ page }) => {
  const { api, headers, get, me } = await apiSession(page.request, ACCOUNTS.admin)
  const equipment = (await get(`/equipments?per_page=1000&site_ids[]=${me.site_id}`)).data.find((e: any) => e.name === '接触改質装置') // インターロックのない設備
  const stamp = `E2E ${Date.now()}`
  const created = await page.request.post(`${api}/scheduled_maintenances`, {
    headers, data: { scheduled_maintenance: { title: `${stamp} 朝会ボード用の整備`, site_id: me.site_id, planned_start_on: todayForInput(), equipment_ids: [equipment.id] } },
  })
  expect(created.ok()).toBeTruthy()
  const maintenanceId = (await created.json()).data.id
  const path = `${api}/scheduled_maintenances/${maintenanceId}`
  const taskIds: number[] = []
  const addTask = async (title: string, department: string, status = 'not_started') => {
    const res = await page.request.post(`${path}/tasks`, {
      headers,
      data: { maintenance_task: { equipment_id: equipment.id, kind: 'work', title: `${stamp} ${title}`, department_id: await departmentId(get, me.site_id, department) } },
    })
    expect(res.ok()).toBeTruthy()
    const task = (await res.json()).data
    taskIds.push(task.id)
    if (status !== 'not_started') await page.request.patch(`${path}/tasks/${task.id}`, { headers, data: { maintenance_task: { status } } })
    return task.id
  }

  try {
    expect((await page.request.patch(path, { headers, data: { scheduled_maintenance: { status: 'in_progress' } } })).ok()).toBeTruthy()
    const sectionTask = await addTask('課の作業', '計装保全課')
    await addTask('チームの完了した作業', '計器Aチーム', 'completed')
    const otherTask = await addTask('電気の作業', '電気チーム')

    await login(page, ACCOUNTS.member)
    await page.goto('/meeting-board')
    const maintenance = page.getByTestId(`board-maintenance-${maintenanceId}`)
    await expect(maintenance).toContainText(`${stamp} 朝会ボード用の整備`)
    await expect(maintenance).toContainText('完了 1 / 2')
    const row = maintenance.getByTestId(`board-task-${sectionTask}`)
    await expect(row.locator('td').nth(0)).toHaveText('計装保全課')
    await expect(row.locator('td').nth(3)).toHaveText('未着手')
    await expect(maintenance.getByTestId(`board-task-${otherTask}`)).toHaveCount(0)
  } finally {
    // 作業を済ませ、検収して完了にする（stg で繰り返しても、実施中の整備が溜まらないように）
    for (const id of taskIds) await page.request.patch(`${path}/tasks/${id}`, { headers, data: { maintenance_task: { status: 'completed' } } })
    await page.request.patch(path, { headers, data: { scheduled_maintenance: { status: 'acceptance' } } })
    const completed = await page.request.patch(path, { headers, data: { scheduled_maintenance: { accepted_on: todayForInput(), acceptance_result: 'passed', status: 'completed' } } })
    expect(completed.ok()).toBeTruthy()
  }
})
