import { test, expect, login, selectOption, ACCOUNTS } from './support'
import type { Page } from '@playwright/test'

// 一覧の見た目の共通ルール（#166）のうち、動作のあるもの: 件数の表示、修理のページ送り、拠点の列の出し分け、絞り込みの行の並び。
// 修理の件数はシードでは少ないため、一覧のAPIの応答を差し替える（画面の件数・ページ送りだけを確かめ、データは作らない）

const isRepairList = (url: URL) => url.pathname.endsWith('/api/v1/repairs')
const range = (from: number, to: number) => Array.from({ length: to - from + 1 }, (_, i) => from + i)
const repair = (id: number) => ({
  id,
  status: 'pending',
  shipped_on: null,
  repair_vendor: null,
  stock: { serial_number: null, material: { name: `E2E 修理 ${id}`, part_number: 'E2E' } },
  requested_by: { name: 'E2E' },
})
const bodyRows = (page: Page) => page.locator('.v-data-table tbody tr')

test('修理の一覧は、ページ送りが表の下の1か所だけで、2ページ目をサーバーから取得し、条件を変えると1ページ目に戻る', async ({ page }) => {
  const pages: string[] = []
  await page.route(isRepairList, async (route) => {
    if (route.request().method() !== 'GET') return route.fallback()
    const current = Number(new URL(route.request().url()).searchParams.get('page') ?? '1')
    pages.push(String(current))
    const ids = current === 1 ? range(1, 25) : range(26, 30)
    await route.fulfill({ json: { data: ids.map(repair), meta: { total_count: 30, page: current, per_page: 25 } } })
  })
  await login(page, ACCOUNTS.admin)
  await page.goto('/repairs')

  // 総件数を出し、取得した25件を「全25件」としない。表の中では再びページに分けない（既定のフッターなし）
  await expect(page.getByTestId('list-count')).toHaveText('検索結果 30件')
  await expect(bodyRows(page)).toHaveCount(25)
  await expect(page.locator('.v-data-table-footer')).toHaveCount(0)

  const pagination = page.getByTestId('repair-pagination')
  await pagination.getByRole('button', { name: '次のページ' }).click()
  await expect(bodyRows(page)).toHaveCount(5)
  await expect(page.getByText('E2E 修理 30')).toBeVisible()
  expect(pages.at(-1)).toBe('2')

  await selectOption(page, 'ステータス', '依頼中')
  await expect.poll(() => pages.at(-1)).toBe('1')
  await expect(bodyRows(page)).toHaveCount(25)
})

test('一覧を取得できなかったときは、0件ではなく取得できなかったことを出す', async ({ page }) => {
  await page.route(isRepairList, (route) => (route.request().method() === 'GET' ? route.abort('failed') : route.fallback()))
  await login(page, ACCOUNTS.admin)
  await page.goto('/repairs')
  await expect(page.getByTestId('list-count')).toHaveText(/一覧を取得できませんでした/)
  await expect(page.getByTestId('list-count')).not.toContainText('0件')
})

test('設備台帳は、1つの拠点を表示しているときは拠点の列を出さず、全拠点では出す', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.goto('/equipments')
  const siteColumn = page.getByRole('columnheader', { name: '拠点', exact: true })
  await expect(page.getByRole('columnheader', { name: '設備名' })).toBeVisible()
  await expect(page.getByTestId('list-count')).toContainText('検索結果')
  await expect(siteColumn).toHaveCount(0)

  await page.getByRole('button', { name: '表示する拠点を選ぶ' }).click()
  await page.getByRole('button', { name: '全拠点' }).click()
  await page.keyboard.press('Escape')
  await expect(siteColumn).toBeVisible()
})

test('絞り込みの行は 拠点 → キーワード → ページの条件 → リセット の順で、スマホ幅でもラベルを省略しない', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  for (const path of ['/reference-standards', '/instruments', '/interlocks']) {
    for (const width of [1440, 1024, 390]) {
      await page.setViewportSize({ width, height: 900 })
      await page.goto(path)
      const filters = page.locator('.pk-filters')
      await expect(filters.locator('.pk-filter-search')).toBeVisible()
      const order = await filters.evaluate((el) => {
        const pick = (selector: string) => Array.from(el.children).findIndex((c) => c.matches(selector))
        return { site: pick('.pk-site-scope'), search: pick('.pk-filter-search'), select: pick('.pk-filter-select'), reset: pick('.pk-filters__reset') }
      })
      expect(order.site, `${path} ${width}px`).toBeGreaterThanOrEqual(0)
      expect(order.site, `${path} ${width}px`).toBeLessThan(order.search)
      expect(order.search, `${path} ${width}px`).toBeLessThan(order.select)
      expect(order.select, `${path} ${width}px`).toBeLessThan(order.reset)

      // 絞り込みのラベル（検索の対象・条件の名前）が省略されずに収まる。ページ全体は横にはみ出さない
      const truncated = await filters.locator('.v-field-label:not(.v-field-label--floating)').evaluateAll((labels) =>
        labels.filter((el) => el.scrollWidth > el.clientWidth).map((el) => el.textContent))
      expect(truncated, `${path} ${width}px`).toEqual([])
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), `${path} ${width}px`).toBe(true)
    }
  }
})
