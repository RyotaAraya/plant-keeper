import { test, login, apiBaseUrl, ACCOUNTS } from '../support'
const dir = '/private/tmp/claude-501/-Users-rair-dev-docs-self-analysis-plant-keeper/fca6437d-3739-480f-ba97-7f213fd289af/scratchpad/ui-' + (process.env.PHASE ?? 'before')
test('shots', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 })
  await login(page, { email: 'suzuki@example.com', password: 'password' })
  const token = await page.evaluate(() => localStorage.getItem('jwt'))
  const headers = { Authorization: `Bearer ${token}` }
  const get = async (p: string) => (await (await page.request.get(`${apiBaseUrl()}${p}`, { headers })).json()).data
  const trouble = (await get('/troubles?q=FT-301%20%E3%82%AA%E3%83%AA%E3%83%95%E3%82%A3%E3%82%B9&per_page=5'))[0]
  const equipment = (await get('/equipments?per_page=1000')).find((e: any) => e.name === 'ボイラー設備')
  const maintenance = (await get('/scheduled_maintenances?per_page=1000')).find((m: any) => m.title === '2026年 A号ボイラー整備')
  const shots: [string, string][] = [
    ['home', '/home'], ['troubles', '/troubles'], ['trouble', `/troubles/${trouble.id}`],
    ['equipment', `/equipments/${equipment.id}`], ['maintenance', `/maintenances/${maintenance.id}`],
  ]
  for (const [name, path] of shots) {
    await page.goto(path)
    await page.waitForLoadState('networkidle')
    await page.waitForTimeout(400)
    await page.screenshot({ path: `${dir}-${name}.png`, fullPage: false })
  }
})
