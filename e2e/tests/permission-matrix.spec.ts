import { test, expect, login } from './support'

// 権限マトリクス（トップページ・ログイン画面）と、実際のメニューが食い違わないこと。
// マトリクスは permissionsFor（メニューの出し分けと同じ判定）から作っているが、
// 判定を変えたときに説明だけ古くなっていないかを、実際にログインして確かめる
const ROLES = [
  { column: 0, name: 'システム管理者', account: { email: 'admin@example.com', password: 'password' } },
  { column: 1, name: '業務管理者（自社）', account: { email: 'suzuki@example.com', password: 'password' } },
  { column: 2, name: '一般', account: { email: 'sato@example.com', password: 'password' } },
  { column: 3, name: '業務管理者（協力会社）', account: { email: 'yoshida@example.com', password: 'password' } },
  { column: 4, name: '技能員', account: { email: 'honda@example.com', password: 'password' } },
]

// マトリクスの行 → その権限があるときにメニューに出る項目
const MENU_BY_ROW: Record<string, string[]> = {
  資材を見る: ['資材管理'],
  在庫を見る: ['在庫管理'],
  発注・修理を管理する: ['発注管理', '修理管理'],
  拠点・ユーザの一覧を見る: ['拠点管理'],
  '拠点・ユーザ・部署・監査ログ・設定を管理する': ['ユーザ管理', '監査ログ', '部署管理', '設定'],
}

test('トップページの権限マトリクスは、実際にログインしたときのメニューと一致する', async ({ page }) => {
  await page.goto('/')
  const matrix = page.locator('#permissions .pk-matrix__table')
  await expect(matrix.locator('thead th[scope="col"]')).toHaveCount(ROLES.length)

  // 行ラベル → 権限（列）ごとの「できる」
  const allowed: Record<string, boolean[]> = {}
  for (const row of await matrix.locator('tbody tr:has(th[scope="row"])').all()) {
    // 折り返し用に入れているゼロ幅スペース（U+200B）は、行の照合に使う文字列から除く
    const label = (await row.locator('th[scope="row"]').innerText()).replace(/\u200b/g, '').trim()
    allowed[label] = await row.locator('td').evaluateAll((cells) => cells.map((c) => !!c.querySelector('.pk-matrix__on')))
  }
  for (const label of Object.keys(MENU_BY_ROW)) expect(allowed[label], `行「${label}」がマトリクスにある`).toBeDefined()

  for (const role of ROLES) {
    await test.step(role.name, async () => {
      await page.context().clearCookies()
      await page.goto('/login')
      await page.evaluate(() => localStorage.clear())
      await login(page, role.account)

      for (const [label, menus] of Object.entries(MENU_BY_ROW)) {
        for (const menu of menus) {
          const link = page.getByRole('link', { name: menu, exact: true })
          if (allowed[label][role.column]) await expect(link, `${role.name}: ${menu}`).toBeVisible()
          else await expect(link, `${role.name}: ${menu}`).toHaveCount(0)
        }
      }
    })
  }
})

test('ログイン画面のデモアカウントは権限ごとに1人で、選ぶとマトリクスのその列が光る', async ({ page }) => {
  await page.goto('/login')
  const accounts = page.locator('.pk-demo-item')
  await expect(accounts).toHaveCount(ROLES.length)

  const headers = page.locator('.pk-matrix__role')
  await expect(headers).toHaveCount(ROLES.length)
  await expect(page.locator('.pk-matrix__role.is-active')).toHaveCount(0)

  for (const role of ROLES) {
    await accounts.nth(role.column).hover()
    await expect(page.locator('.pk-matrix__role.is-active')).toHaveCount(1)
    await expect(headers.nth(role.column)).toHaveClass(/is-active/)
  }

  await page.mouse.move(0, 0)
  await expect(page.locator('.pk-matrix__role.is-active')).toHaveCount(0)
})

test('ログイン画面のデモアカウントに、所属拠点が表示される', async ({ page }) => {
  await page.goto('/login')
  const accounts = page.locator('.pk-demo-item')
  await expect(accounts).toHaveCount(ROLES.length)
  for (let i = 0; i < ROLES.length; i++) {
    await expect(accounts.nth(i).locator('.pk-site-tag')).toContainText('製油所')
  }
})
