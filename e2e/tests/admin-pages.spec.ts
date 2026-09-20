import { readFileSync } from 'node:fs'
import { test, expect, login, ACCOUNTS } from './support'

// 管理系の画面（監査ログ・ユーザ管理）。拠点と期間で絞れること、監査ログをCSVで出力できること

test('監査ログは自拠点・直近1か月が初期値で、対象の選択肢に英語のクラス名が出ない', async ({ page }) => {
  const urls: string[] = []
  page.on('request', (r) => {
    if (/\/api\/v1\/audit_logs\?/.test(r.url())) urls.push(r.url())
  })
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '監査ログ', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '監査ログ' })).toBeVisible()

  await expect(page.getByRole('button', { name: '表示する拠点を選ぶ' })).toContainText('川崎製油所')
  await expect.poll(() => urls.length).toBeGreaterThan(0)
  const params = new URL(urls[0]).searchParams
  expect(params.getAll('site_ids[]')).toHaveLength(1)

  // 期間は「今日」までの直近1か月（28〜31日前から）
  const days = (Date.parse(params.get('to')!) - Date.parse(params.get('from')!)) / 86_400_000
  expect(days).toBeGreaterThanOrEqual(28)
  expect(days).toBeLessThanOrEqual(31)
  await expect(page.getByLabel('開始日')).toHaveValue(params.get('from')!)
  await expect(page.getByLabel('終了日')).toHaveValue(params.get('to')!)

  // 「対象モデル」ではなく「対象」。選択肢は日本語の呼び名だけ
  await page.locator('.v-field', { has: page.getByLabel('対象', { exact: true }) }).click()
  const options = await page.getByRole('option').allTextContents()
  expect(options.length).toBeGreaterThan(5)
  expect(options.every((text) => !/[A-Za-z(]/.test(text))).toBe(true)
})

test('監査ログは、条件に合う記録をCSVで出力できる', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '監査ログ', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '監査ログ' })).toBeVisible()
  await page.waitForLoadState('networkidle')

  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.getByRole('button', { name: 'CSV出力' }).click(),
  ])
  expect(download.suggestedFilename()).toMatch(/^監査ログ_\d{4}-\d{2}-\d{2}_\d{4}-\d{2}-\d{2}\.csv$/)

  const csv = readFileSync((await download.path())!, 'utf8')
  // Excelで文字化けしないよう BOM 付き。先頭行は見出し
  expect(csv.startsWith('﻿日時,ユーザ,操作,対象,対象ID,拠点,変更内容,IP')).toBe(true)
  // ログインするたびに記録が増えるため、少なくとも今のログインの1行がある
  expect(csv.split('\r\n').filter(Boolean).length).toBeGreaterThan(1)
})

test('ユーザ管理は自拠点が初期値で、拠点を切り替えられる', async ({ page }) => {
  const urls: string[] = []
  page.on('request', (r) => {
    if (/\/api\/v1\/users\?/.test(r.url())) urls.push(r.url())
  })
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: 'ユーザ管理', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'ユーザ管理' })).toBeVisible()

  const tag = page.getByRole('button', { name: '表示する拠点を選ぶ' })
  await expect(tag).toContainText('川崎製油所')
  await expect.poll(() => urls.length).toBeGreaterThan(0)
  expect(new URL(urls[0]).searchParams.getAll('site_ids[]')).toHaveLength(1)

  await tag.click()
  await page.getByRole('button', { name: '全拠点' }).click()
  await expect(tag).toContainText('全拠点')
  await expect.poll(() => new URL(urls[urls.length - 1]).searchParams.getAll('site_ids[]').length).toBe(0)
})
