import { test, expect, login, apiBaseUrl } from './support'

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

// マトリクスの行 → その権限があるときに 200、なければ 403 になる一覧API（バックエンドの認可との一致を見る）
const API_BY_ROW: Record<string, string[]> = {
  '設備・点検・トラブルの記録を見る': ['/equipments', '/inspections', '/troubles'],
  資材を見る: ['/materials'],
  在庫を見る: ['/stocks'],
  発注・修理を管理する: ['/orders', '/repairs'],
  拠点・ユーザの一覧を見る: ['/sites', '/users'],
  '拠点・ユーザ・部署・監査ログ・設定を管理する': ['/audit_logs'],
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

      // バックエンドの認可とも一致すること（メニューを隠しているだけで、APIは通ってしまう、を検出する）
      const token = await page.evaluate(() => localStorage.getItem('jwt'))
      for (const [label, paths] of Object.entries(API_BY_ROW)) {
        expect(allowed[label], `行「${label}」がマトリクスにある`).toBeDefined()
        for (const path of paths) {
          const res = await page.request.get(`${apiBaseUrl()}${path}`, { headers: { Authorization: `Bearer ${token}` } })
          expect(res.status(), `${role.name}: GET ${path}`).toBe(allowed[label][role.column] ? 200 : 403)
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

// 制限したAPI（拠点・ユーザ一覧など）を画面が呼んで403になり、エラーになる画面がないこと。
// 全テスト共通のガード（未捕捉のJS例外・API 5xx）が、画面ごとに働く
for (const role of ROLES) {
  test(`${role.name}は、メニューに出ているすべての画面をエラーなく開ける`, async ({ page }) => {
    await login(page, role.account)

    const links = await page.locator('.v-navigation-drawer a[href^="/"]').evaluateAll((els) =>
      els.map((e) => ({ href: (e as HTMLAnchorElement).getAttribute('href') as string, name: (e.textContent ?? '').trim() }))
    )
    expect(links.length).toBeGreaterThan(5)

    for (const link of links) {
      await test.step(link.name, async () => {
        await page.locator(`.v-navigation-drawer a[href="${link.href}"]`).click()
        await expect(page).toHaveURL(new RegExp(`${link.href}$`))
        await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
        // 一覧の取得（拠点・ユーザなど）が終わって、エラー表示に落ちていないこと
        await page.waitForLoadState('networkidle')
        await expect(page.getByText(/権限がありません|Request failed/)).toHaveCount(0)
      })
    }
  })
}
