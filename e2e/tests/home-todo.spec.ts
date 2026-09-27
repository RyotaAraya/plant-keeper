import { test, expect, login, apiBaseUrl, ACCOUNTS } from './support'
import { todayForInput } from '../../frontend/src/utils/datetime'
import type { APIRequestContext, Page } from '@playwright/test'

// ホーム（やること）。所属のチーム → 課 → 部のエリアに、その部署に直接割り当てたものだけを出す。
// シードのデモ（実施中の定期整備・今日と明日が期限の計画）は投入日からの相対日付で、stg では日がたつと期限超過に移るため、
// 件数や位置を決め打ちせず、確かめたい行はAPIで自分用に作って最後に片付ける
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
const area = (page: Page, name: string) => page.getByTestId(`home-area-${name}`)

test('ログインするとホームが開き、バイパス → チーム → 課 → 部のエリアが並び、課の計画は課のエリアにだけ出て点検へ進める', async ({ page }) => {
  const { api, headers, get } = await apiSession(page.request, MANAGER)
  const instrument = (await get('/instruments?q=PT-801')).data.find((i: any) => i.tag_number === 'PT-801')
  const template = (await get('/checklist_templates')).data.find((t: any) => t.name === '伝送器 月次点検') // まとまり「伝送器 月次点検」（計装保全課）に入る
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
    await expect(page.getByRole('heading', { level: 1, name: 'ホーム' })).toBeVisible()
    await expect(area(page, '保全部')).toBeVisible()
    const sections = await page.locator('[data-testid="home-bypasses"], [data-testid^="home-area-"]').evaluateAll((els) => els.map((e) => e.getAttribute('data-testid')))
    expect(sections).toEqual(['home-bypasses', 'home-area-計器Aチーム', 'home-area-計装保全課', 'home-area-保全部'])

    // インターロックは、復帰期限超過 → バイパス中 → 復帰確認待ちの順（件数はシードの相対時刻で変わるため決め打ちしない）
    const ranks = (await page.getByTestId('home-bypasses').locator('li .v-chip').allTextContents()).map((label) => BYPASS_RANK[label.trim()])
    expect(ranks.every((rank) => rank !== undefined)).toBeTruthy()
    expect(ranks).toEqual([...ranks].sort((a, b) => a - b))

    // 課に割り当てた計画は、課のエリアにだけ出る（チームのエリアには混ざらない）
    await expect(area(page, '計装保全課').getByTestId(`home-todo-plan-${planId}`)).toContainText(name)
    await expect(area(page, '計器Aチーム').getByTestId(`home-todo-plan-${planId}`)).toHaveCount(0)
    await area(page, '計装保全課').getByTestId(`home-todo-plan-${planId}`).getByRole('link', { name: '点検を実施' }).click()
    await expect(page).toHaveURL(new RegExp(`/inspections/new\\?.*inspection_plan_id=${planId}`))
  } finally {
    const retired = await page.request.patch(`${api}/inspection_plans/${planId}`, { headers, data: { inspection_plan: { is_active: false } } })
    expect(retired.ok()).toBeTruthy()
  }
})

test('自分が報告した緊急のトラブルは、チームのエリアの先頭側に出て、詳細へ進める', async ({ page }) => {
  const { api, headers, get, me } = await apiSession(page.request, ACCOUNTS.member)
  const equipment = (await get(`/equipments?per_page=1000&site_ids[]=${me.site_id}`)).data[0]
  const title = `E2E ${Date.now()} ホームの緊急トラブル`
  const created = await page.request.post(`${api}/troubles`, {
    headers, data: { trouble: { equipment_id: equipment.id, title, description: 'ホームの確認', priority: 'critical', reported_at: new Date().toISOString() } },
  })
  expect(created.ok()).toBeTruthy()
  const id = (await created.json()).data.id

  try {
    await login(page, ACCOUNTS.member)
    const team = area(page, '計器Aチーム')
    const row = team.getByTestId(`home-todo-trouble-${id}`)
    await expect(row).toContainText(title)
    await expect(row).toContainText('緊急')
    await expect(area(page, '計装保全課').getByTestId(`home-todo-trouble-${id}`)).toHaveCount(0)
    // 緊急の行は、緊急でないトラブル・今日の点検・作業より前にある
    const keys = await team.locator('[data-testid^="home-todo-"]').evaluateAll((els) => els.map((e) => e.getAttribute('data-testid')))
    const alerts = await team.locator('[data-testid^="home-todo-"].pk-home-list__alert').evaluateAll((els) => els.map((e) => e.getAttribute('data-testid')))
    expect(keys.slice(0, alerts.length)).toEqual(alerts)
    expect(alerts).toContain(`home-todo-trouble-${id}`)

    await row.getByRole('link', { name: '開く' }).click()
    await expect(page).toHaveURL(new RegExp(`/troubles/${id}$`))
  } finally {
    // 一般ユーザはトラブルを更新できないため、業務管理者が完了にする
    const manager = await apiSession(page.request, MANAGER)
    const closed = await page.request.patch(`${api}/troubles/${id}`, { headers: manager.headers, data: { trouble: { status: 'closed' } } })
    expect(closed.ok()).toBeTruthy()
  }
})

test('実施中の定期整備の作業は、作業の部署のエリアにだけ出て、ほかの部署の作業は出ない', async ({ page }) => {
  const { api, headers, get, me } = await apiSession(page.request, ACCOUNTS.admin)
  const equipment = (await get(`/equipments?per_page=1000&site_ids[]=${me.site_id}`)).data.find((e: any) => e.name === '接触改質装置') // インターロックのない設備
  const stamp = `E2E ${Date.now()}`
  const created = await page.request.post(`${api}/scheduled_maintenances`, {
    headers, data: { scheduled_maintenance: { title: `${stamp} ホーム用の整備`, site_id: me.site_id, planned_start_on: todayForInput(), equipment_ids: [equipment.id] } },
  })
  expect(created.ok()).toBeTruthy()
  const maintenanceId = (await created.json()).data.id
  const path = `${api}/scheduled_maintenances/${maintenanceId}`
  const taskIds: number[] = []
  const addTask = async (title: string, department: string) => {
    const res = await page.request.post(`${path}/tasks`, {
      headers,
      data: { maintenance_task: { equipment_id: equipment.id, kind: 'work', title: `${stamp} ${title}`, department_id: await departmentId(get, me.site_id, department) } },
    })
    expect(res.ok()).toBeTruthy()
    const task = (await res.json()).data
    taskIds.push(task.id)
    return task.id
  }

  try {
    expect((await page.request.patch(path, { headers, data: { scheduled_maintenance: { status: 'in_progress' } } })).ok()).toBeTruthy()
    const sectionTask = await addTask('課の作業', '計装保全課')
    const otherTask = await addTask('電気の作業', '電気チーム')

    await login(page, ACCOUNTS.member)
    const row = area(page, '計装保全課').getByTestId(`home-todo-task-${sectionTask}`)
    await expect(row).toContainText(`${stamp} 課の作業`)
    await expect(row).toContainText('未着手')
    await expect(area(page, '計器Aチーム').getByTestId(`home-todo-task-${sectionTask}`)).toHaveCount(0)
    await expect(page.getByTestId(`home-todo-task-${otherTask}`)).toHaveCount(0)
  } finally {
    // 作業を済ませ、検収して完了にする（stg で繰り返しても、実施中の整備が溜まらないように）
    for (const id of taskIds) await page.request.patch(`${path}/tasks/${id}`, { headers, data: { maintenance_task: { status: 'completed' } } })
    await page.request.patch(path, { headers, data: { scheduled_maintenance: { status: 'acceptance' } } })
    const completed = await page.request.patch(path, { headers, data: { scheduled_maintenance: { accepted_on: todayForInput(), acceptance_result: 'passed', status: 'completed' } } })
    expect(completed.ok()).toBeTruthy()
  }
})

test('マネージャーは先頭に承認待ちが出て、チームのエリアはない', async ({ page }) => {
  await login(page, MANAGER)
  await expect(page.getByTestId('home-approvals')).toBeVisible()
  await expect(area(page, '保全部')).toBeVisible()
  const sections = await page.locator('[data-testid="home-approvals"], [data-testid^="home-area-"]').evaluateAll((els) => els.map((e) => e.getAttribute('data-testid')))
  expect(sections).toEqual(['home-approvals', 'home-area-計装保全課', 'home-area-保全部'])
})

test('運転員は不具合を報告するボタンと、自分が報告したトラブル、製造部の計画のエリアが出る', async ({ page }) => {
  await login(page, ACCOUNTS.operator)
  await expect(page.getByTestId('home-my-troubles')).toBeVisible()
  await expect(area(page, '製造部')).toBeVisible()
  await expect(page.getByTestId('home-approvals')).toHaveCount(0)
  await page.getByTestId('home-report').getByRole('link', { name: '不具合を報告する' }).click()
  await expect(page).toHaveURL(/\/inspections\/new\?inspection_type=operation_check/)
})

test('協力会社は拠点全体の1エリアで、拠点を切り替えられない', async ({ page }) => {
  await login(page, { email: 'honda@example.com', password: 'password' })
  await expect(area(page, 'site')).toContainText('川崎製油所全体')
  await expect(page.locator('[data-testid^="home-area-"]')).toHaveCount(1)
  await expect(page.getByLabel('拠点', { exact: true })).toHaveCount(0)
})

test('旧のダッシュボード・朝会・夕会ボードのURLはホームになり、夕会の指定は引き継ぐ', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/dashboard')
  await expect(page).toHaveURL(/\/home$/)
  await page.goto('/meeting-board?mode=evening')
  await expect(page).toHaveURL(/\/home\?mode=evening/)
  await expect(page.getByTestId('home-day')).toContainText('夕会')
})

test('夕会に切り替えると、今日の下書きの点検は積み残しに、提出すると実績に出て、今日の対応記録も実績に出る', async ({ page }) => {
  const { api, headers, get, me } = await apiSession(page.request, ACCOUNTS.member)
  const equipment = (await get(`/equipments?per_page=1000&site_ids[]=${me.site_id}`)).data[0]
  const stamp = `E2E ${Date.now()}`
  // 点検は消せないため、提出したまま残る（点検一覧の E2E の記録と同じ扱い）
  const inspection = await page.request.post(`${api}/inspections`, {
    headers,
    data: { inspection: { equipment_id: equipment.id, department_id: me.department_id, inspection_type: 'routine', status: 'draft',
                          inspected_at: new Date().toISOString(), notes: `${stamp} 夕会の確認` } },
  })
  expect(inspection.ok()).toBeTruthy()
  const inspectionId = (await inspection.json()).data.id
  const trouble = await page.request.post(`${api}/troubles`, {
    headers, data: { trouble: { equipment_id: equipment.id, title: `${stamp} 夕会の対応記録`, description: '夕会の確認', priority: 'low', reported_at: new Date().toISOString() } },
  })
  expect(trouble.ok()).toBeTruthy()
  const troubleId = (await trouble.json()).data.id

  try {
    await login(page, ACCOUNTS.member)
    await expect(page.getByTestId('home-results')).toHaveCount(0) // 朝会には実績を出さない
    await page.getByTestId('home-mode-evening').click()
    await expect(page).toHaveURL(/mode=evening/)
    await expect(page.getByTestId('home-day')).toContainText('夕会')
    const team = area(page, '計器Aチーム')
    await expect(team.getByTestId(`home-draft-inspection-${inspectionId}`)).toBeVisible()
    await expect(team.getByTestId(`home-result-inspection-${inspectionId}`)).toHaveCount(0)
    // 「開く」は詳細へ（編集画面は作成者本人と管理者・マネージャーのものなので、ホームからは開かない）
    await team.getByTestId(`home-draft-inspection-${inspectionId}`).getByRole('link', { name: '開く' }).click()
    await expect(page).toHaveURL(new RegExp(`/inspections/${inspectionId}$`))
    await page.goBack()
    await expect(page).toHaveURL(/mode=evening/)

    // 提出し、対応を記録すると、再読み込み（夕会のまま）で実績に移る
    expect((await page.request.patch(`${api}/inspections/${inspectionId}`, { headers, data: { inspection: { status: 'submitted' } } })).ok()).toBeTruthy()
    const response = await page.request.post(`${api}/trouble_responses`, {
      headers, data: { trouble_response: { trouble_id: troubleId, response_type: 'investigation', description: `${stamp} 導圧管をブローした`, responded_at: new Date().toISOString() } },
    })
    expect(response.ok()).toBeTruthy()
    const responseId = (await response.json()).data.id
    await page.reload()
    await expect(page).toHaveURL(/mode=evening/)
    await expect(team.getByTestId(`home-draft-inspection-${inspectionId}`)).toHaveCount(0)
    await expect(team.getByTestId(`home-result-inspection-${inspectionId}`).locator('.v-chip')).toHaveText('提出済')
    const responseRow = team.getByTestId(`home-result-response-${responseId}`)
    await expect(responseRow.getByRole('link')).toHaveText(`${stamp} 夕会の対応記録`)
    await expect(responseRow).toContainText(`調査：${stamp} 導圧管をブローした`)

    await page.getByTestId('home-mode-morning').click()
    await expect(page).not.toHaveURL(/mode=evening/)
    await expect(page.getByTestId('home-results')).toHaveCount(0)
  } finally {
    const manager = await apiSession(page.request, MANAGER)
    expect((await page.request.patch(`${api}/troubles/${troubleId}`, { headers: manager.headers, data: { trouble: { status: 'closed' } } })).ok()).toBeTruthy()
  }
})

test('印刷ボタンで印刷でき、印刷ではメニュー・操作ボタンを出さず、紙の幅に収まる', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await page.goto('/home?mode=evening')
  await expect(page.getByTestId('home-results').first()).toBeVisible()

  // 印刷のダイアログは開かず、呼ばれたことだけを確かめる
  await page.evaluate(() => { (window as any).__printed = 0; window.print = () => { (window as any).__printed += 1 } })
  await page.getByTestId('home-print').click()
  expect(await page.evaluate(() => (window as any).__printed)).toBe(1)

  await page.emulateMedia({ media: 'print' })
  await page.setViewportSize({ width: 718, height: 1000 }) // A4 の幅（余白を除く）
  for (const selector of ['.v-navigation-drawer', '.v-app-bar', '[data-testid="home-print"]', '[data-testid="home-mode-evening"]']) {
    await expect(page.locator(selector).first(), selector).toBeHidden()
  }
  await expect(page.getByRole('link', { name: '点検を実施' })).toHaveCount(0)
  await expect(page.getByTestId('home-results').first()).toBeVisible()
  expect(await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)).toBe(0)
})
