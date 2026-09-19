import { test, expect, login } from './support'
import type { Page } from '@playwright/test'

const ACCOUNTS = {
  ownerManager: { email: 'yamamoto@example.com', password: 'password' },
  contractorWorker: { email: 'honda@example.com', password: 'password' },
}

// 一覧APIのリクエストURLを集める（拠点や絞り込みが、リクエストの site_ids などに付くかを見る）
function collectListRequests(page: Page, resource: string) {
  const urls: string[] = []
  page.on('request', (r) => {
    if (new RegExp(`/api/v1/${resource}\\?`).test(r.url())) urls.push(r.url())
  })
  return urls
}

const paramsOf = (url: string, key: string) => new URL(url).searchParams.getAll(`${key}[]`)

async function openList(page: Page, menu: string) {
  await page.getByRole('link', { name: menu, exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: menu })).toBeVisible()
}

// 絞り込みの選択肢の1つ目を選ぶ（複数選択のため、選んだあとにメニューを閉じる）
async function pickFilterOption(page: Page, label: string, option?: string) {
  await page.locator('.v-field', { has: page.getByLabel(label, { exact: true }) }).click()
  await (option ? page.getByRole('option', { name: option }) : page.getByRole('option').first()).click()
  await page.keyboard.press('Escape')
}

test('点検一覧は自拠点が初期値で、拠点を複数選べ、全拠点・所属拠点だけに切り替えられる', async ({ page }) => {
  const requests = collectListRequests(page, 'inspections')
  await login(page, ACCOUNTS.ownerManager)
  await openList(page, '点検・作業記録')

  const tag = page.getByRole('button', { name: '表示する拠点を選ぶ' })
  await expect(tag).toContainText('川崎製油所')
  await expect.poll(() => requests.length).toBeGreaterThan(0)
  const ownSiteIds = paramsOf(requests[0], 'site_ids')
  expect(ownSiteIds).toHaveLength(1)
  expect(requests.every((u) => !u.includes('department_id'))).toBe(true)

  // 設備を選んでから拠点を切り替えると、表示しない拠点の設備の絞り込みは外れる
  await pickFilterOption(page, '設備')
  await expect.poll(() => paramsOf(requests[requests.length - 1], 'equipment_ids')).toHaveLength(1)

  await tag.click()
  await page.getByRole('menuitemcheckbox', { name: /根岸製油所/ }).click()
  await expect(tag).toContainText('川崎製油所 ほか1')
  await expect.poll(() => paramsOf(requests[requests.length - 1], 'site_ids')).toHaveLength(2)

  // 川崎を外して根岸だけにすると、川崎の設備の絞り込みは外れる
  await page.getByRole('menuitemcheckbox', { name: /川崎製油所/ }).click()
  await expect(tag).toContainText('根岸製油所')
  await expect.poll(() => {
    const last = requests[requests.length - 1]
    return paramsOf(last, 'site_ids').length === 1 && paramsOf(last, 'equipment_ids').length === 0
  }).toBe(true)

  // 全拠点: 拠点で絞らない
  await page.getByRole('button', { name: '全拠点' }).click()
  await expect(tag).toContainText('全拠点')
  await expect.poll(() => paramsOf(requests[requests.length - 1], 'site_ids')).toHaveLength(0)

  // 所属拠点だけ: 自拠点に戻る
  await page.getByRole('button', { name: '所属拠点だけ' }).click()
  await expect(tag).toContainText('川崎製油所')
  await expect.poll(() => paramsOf(requests[requests.length - 1], 'site_ids')).toEqual(ownSiteIds)
})

test('種別・ステータス・優先度は複数選択でき、選ぶとリクエストに複数付く', async ({ page }) => {
  const inspectionRequests = collectListRequests(page, 'inspections')
  const troubleRequests = collectListRequests(page, 'troubles')
  await login(page, ACCOUNTS.ownerManager)

  await openList(page, '点検・作業記録')
  await pickFilterOption(page, 'ステータス', '承認待ち')
  await pickFilterOption(page, 'ステータス', '提出済')
  await expect(page.locator('.v-field', { has: page.getByLabel('ステータス', { exact: true }) })).toContainText('ほか1')
  await expect.poll(() => paramsOf(inspectionRequests[inspectionRequests.length - 1], 'statuses').sort()).toEqual(['approval_requested', 'submitted'])

  await openList(page, 'トラブル管理')
  await pickFilterOption(page, '優先度', '高')
  await pickFilterOption(page, '優先度', '緊急')
  await expect.poll(() => paramsOf(troubleRequests[troubleRequests.length - 1], 'priorities').sort()).toEqual(['critical', 'high'])
})

// ダッシュボードのカードから開いた一覧が、表示中の拠点とカードの絞り込みを引き継ぐこと。
// ダッシュボードは開き直すと自拠点に戻るため、全拠点で見るときはその都度選ぶ。
// 件数は、他のテストが並行してデータを追加しない項目（対応中トラブル・承認待ち点検）でだけ、カードの数字と一覧の件数を比べる
// （未対応トラブルは、点検で不具合を報告するテストが1件ずつ増やす）
async function expectCardOpensList(page: Page, card: RegExp, listHeading: string, scope: '自拠点' | '全拠点', options: { compareCount: boolean }) {
  await page.getByRole('link', { name: 'ダッシュボード', exact: true }).click()
  const tag = page.getByRole('button', { name: '表示する拠点を選ぶ' })
  if (scope === '全拠点') {
    await tag.click()
    // 切り替えた直後は自拠点の数字が残っているため、全拠点で取得し直した結果が表示されるまで待つ
    const reloaded = page.waitForResponse((r) => new URL(r.url()).pathname.endsWith('/dashboard') && !r.url().includes('site_ids'))
    await page.getByRole('button', { name: '全拠点' }).click()
    await reloaded
    await page.keyboard.press('Escape')
    await expect(tag).toContainText('全拠点')
  }
  const button = page.getByRole('button', { name: card })
  await expect(button).toBeVisible()
  const count = (await button.locator('.pk-kpi__value').innerText()).trim()

  await button.click()
  await expect(page.getByRole('heading', { level: 1, name: listHeading })).toBeVisible()
  await expect(tag).toContainText(scope === '全拠点' ? '全拠点' : '川崎製油所')
  if (options.compareCount) await expect(page.locator('.v-data-table-footer')).toContainText(`/ ${count}件`)
}

test('ダッシュボードのカードから開いた一覧は、表示中の拠点とステータスを引き継ぐ', async ({ page }) => {
  const troubleRequests = collectListRequests(page, 'troubles')
  const inspectionRequests = collectListRequests(page, 'inspections')
  await login(page, ACCOUNTS.ownerManager)

  // 自拠点
  await expectCardOpensList(page, /未対応トラブル/, 'トラブル管理', '自拠点', { compareCount: false })
  await expect.poll(() => paramsOf(troubleRequests[troubleRequests.length - 1], 'statuses')).toEqual(['open'])
  expect(paramsOf(troubleRequests[troubleRequests.length - 1], 'site_ids')).toHaveLength(1)
  await expectCardOpensList(page, /対応中トラブル/, 'トラブル管理', '自拠点', { compareCount: true })
  await expectCardOpensList(page, /承認待ち点検/, '点検・作業記録', '自拠点', { compareCount: true })
  await expect.poll(() => paramsOf(inspectionRequests[inspectionRequests.length - 1], 'statuses')).toEqual(['approval_requested'])

  // 全拠点（カードの数字と、開いた一覧の件数が一致する）
  await expectCardOpensList(page, /未対応トラブル/, 'トラブル管理', '全拠点', { compareCount: false })
  await expect.poll(() => paramsOf(troubleRequests[troubleRequests.length - 1], 'site_ids')).toHaveLength(0)
  await expectCardOpensList(page, /対応中トラブル/, 'トラブル管理', '全拠点', { compareCount: true })
  await expectCardOpensList(page, /承認待ち点検/, '点検・作業記録', '全拠点', { compareCount: true })
})

test('拠点の絞り込みはすべての拠点データの一覧で同じ部品になっている', async ({ page }) => {
  await login(page, ACCOUNTS.ownerManager)
  await expect(page.getByRole('button', { name: '表示する拠点を選ぶ' })).toContainText('川崎製油所')

  for (const menu of ['設備台帳', '装置・計器', '点検計画', '点検・作業記録', 'トラブル管理', '定期整備', '在庫管理', '修理管理']) {
    await openList(page, menu)
    await expect(page.getByRole('button', { name: '表示する拠点を選ぶ' }), menu).toContainText('川崎製油所')
  }
})

test('協力会社は拠点を切り替えられず、一覧は所属拠点で固定される', async ({ page }) => {
  const inspectionRequests = collectListRequests(page, 'inspections')
  const troubleRequests = collectListRequests(page, 'troubles')
  await login(page, ACCOUNTS.contractorWorker)

  await openList(page, '点検・作業記録')
  await expect(page.locator('.pk-site-scope')).toContainText('川崎製油所')
  await expect(page.getByRole('button', { name: '表示する拠点を選ぶ' })).toHaveCount(0)
  await expect.poll(() => inspectionRequests.some((u) => paramsOf(u, 'site_ids').length === 1)).toBe(true)

  await openList(page, 'トラブル管理')
  await expect(page.locator('.pk-site-scope')).toContainText('川崎製油所')
  await expect(page.getByRole('button', { name: '表示する拠点を選ぶ' })).toHaveCount(0)
  await expect.poll(() => troubleRequests.some((u) => paramsOf(u, 'site_ids').length === 1)).toBe(true)
})
