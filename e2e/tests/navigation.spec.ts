import { test, expect, login, ACCOUNTS } from './support'

// メニュー名 / 画面見出し / 一覧にシードデータが表示されるか
const screens = [
  { menu: '設備台帳', heading: '設備台帳', hasRows: true },
  { menu: '装置・計器', heading: '装置・計器', hasRows: true },
  { menu: '点検・作業記録', heading: '点検・作業記録', hasRows: true },
  { menu: 'トラブル管理', heading: 'トラブル管理', hasRows: true },
  { menu: '定期整備', heading: '定期整備', hasRows: true },
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

test('一般ユーザには管理系メニューが表示されず、URL直打ちでもダッシュボードに戻される', async ({ page }) => {
  await login(page, ACCOUNTS.member)

  for (const menu of ['監査ログ', 'ユーザ管理', '部署管理']) {
    await expect(page.getByRole('link', { name: menu, exact: true })).toHaveCount(0)
  }

  await page.goto('/audit-logs')
  await expect(page).toHaveURL(/\/dashboard/)
})

// 既知の不具合: ログインAPI・current_user が company_id しか返さず、フロントが読む user.company が常に未定義になる。
// そのため「自社所属」の判定（isOwnerCompany）が常に偽になり、在庫管理メニューが表示されず、ヘッダーの会社名も空になる。
// 修正したら fixme を外す。
test.fixme('自社所属のユーザには在庫管理メニューが表示され、ヘッダーに会社名が出る', async ({ page }) => {
  await login(page, ACCOUNTS.admin)

  await expect(page.getByRole('banner')).toContainText('プラント管理株式会社')
  await page.getByRole('link', { name: '在庫管理', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '在庫管理' })).toBeVisible()
  await expect(page.locator('tbody tr').first()).toBeVisible()
})
