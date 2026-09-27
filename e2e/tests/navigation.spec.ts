import { test, expect, login, ACCOUNTS, openFirstTrouble, openPlans } from './support'

// メニュー名 / 画面見出し / 一覧にシードデータが表示されるか
const screens = [
  { menu: '設備台帳', heading: '設備台帳', hasRows: true },
  { menu: '装置・計器', heading: '装置・計器', hasRows: true },
  { menu: '基準器', heading: '基準器', hasRows: true },
  { menu: '点検・作業記録', heading: '点検・作業記録', hasRows: true },
  { menu: 'トラブル管理', heading: 'トラブル管理', hasRows: true },
  { menu: '計画', heading: '計画', hasRows: true },
  { menu: '資材管理', heading: '資材管理', hasRows: true },
  { menu: '監査ログ', heading: '監査ログ', hasRows: false },
]

test('管理者が主要画面をメニューから順に開ける', async ({ page }) => {
  await login(page, ACCOUNTS.admin)

  for (const s of screens) {
    await test.step(s.menu, async () => {
      await page.getByRole('link', { name: s.menu, exact: true }).click()
      await expect(page.getByRole('heading', { level: 1, name: s.heading })).toBeVisible()
      if (s.hasRows) {
        await expect(page.locator('tbody tr').first()).toBeVisible()
      }
    })
  }
})

test('一般ユーザには管理系メニューが表示されず、URL直打ちでもホームに戻される', async ({ page }) => {
  await login(page, ACCOUNTS.member)

  for (const menu of ['監査ログ', 'ユーザ管理', '部署管理']) {
    await expect(page.getByRole('link', { name: menu, exact: true })).toHaveCount(0)
  }

  await page.goto('/audit-logs')
  await expect(page).toHaveURL(/\/home/)
})

// 自社/協力会社の判定はログインAPIが返す user.company に依存する（company_id のみだと常に「協力会社扱い」になる）
test('自社所属のユーザには在庫管理メニューが表示され、ヘッダーにログイン名が出る', async ({ page }) => {
  await login(page, ACCOUNTS.admin)

  await expect(page.getByRole('banner')).toContainText('田中 太郎')
  await page.getByRole('button', { name: 'アカウントメニュー' }).click()
  await expect(page.getByText('プラント管理株式会社', { exact: true })).toBeVisible()
  await page.keyboard.press('Escape')
  await page.getByRole('link', { name: '在庫管理', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '在庫管理' })).toBeVisible()
  await expect(page.locator('tbody tr').first()).toBeVisible()
})

// 詳細と入力画面の現在地・一覧への復帰を、実際のリンク操作で確認する。
test('詳細と新規点検からヘッダーの一覧リンクで戻れる', async ({ page }) => {
  await login(page, ACCOUNTS.member)
  await openFirstTrouble(page)
  const location = page.getByRole('navigation', { name: '現在の場所' })
  await expect(location.locator('[aria-current="page"]')).toHaveText('詳細')
  await expect(page.getByRole('link', { name: 'トラブル管理', exact: true })).toHaveAttribute('aria-current', 'page')
  await location.getByRole('link', { name: 'トラブル管理の一覧へ戻る' }).click()
  await expect(page).toHaveURL(/\/troubles$/)
  await expect(location.locator('[aria-current="page"]')).toHaveText('トラブル管理')

  await page.goto('/inspections/new')
  await expect(location.locator('[aria-current="page"]')).toHaveText('新規点検')
  await location.getByRole('link', { name: '点検・作業記録の一覧へ戻る' }).click()
  await expect(page).toHaveURL(/\/inspections$/)
})

// サイドバーは仕事の流れ（ホーム → 記録する → 計画する）のあとに台帳・資材・組織を並べ、プラナの入口は最後。
// 見える項目のないグループは、見出しも出さない
for (const [label, account, groups] of [
  ['システム管理者', ACCOUNTS.admin, ['記録する', '計画する', '設備の台帳', '資材と調達', '組織と設定']],
  ['協力会社の技能員', { email: 'honda@example.com', password: 'password' }, ['記録する', '計画する', '設備の台帳']],
] as const) {
  test(`${label}のサイドバーは、ホーム → 記録する → 計画する → 台帳の順で、プラナの入口が最後にある`, async ({ page }) => {
    await login(page, account)
    const drawer = page.locator('.v-navigation-drawer')
    await expect(drawer.locator('.pk-sidenav__group')).toHaveText([...groups])
    const links = await drawer.locator('a[href^="/"]').evaluateAll((els) => els.map((e) => e.getAttribute('href')))
    expect(links.slice(0, 5)).toEqual(['/home', '/inspections', '/troubles', '/interlocks', '/plans'])
    expect(links.at(-1)).toBe('/plana')
  })
}
