import { test, expect, login, selectFirstOption, selectOption, openListRow, requireFakeAi, ACCOUNTS } from './support'
import type { Page } from '@playwright/test'

test.use({ viewport: { width: 390, height: 844 } })

test('スマホではメニューを開いて画面を選ぶと閉じ、一覧と入力画面が画面幅に収まる', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  const equipmentLink = page.getByRole('link', { name: '設備台帳', exact: true })
  await expect(equipmentLink).not.toBeInViewport()
  await page.getByRole('button', { name: 'メニューを開閉' }).click()
  await equipmentLink.click()
  await expect(page.getByRole('heading', { level: 1, name: '設備台帳' })).toBeVisible()
  await expect(equipmentLink).not.toBeInViewport()

  for (const path of ['/equipments', '/inspections/new', '/plana', '/home', '/plans']) {
    await page.goto(path)
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    expect(await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)).toBe(0)
  }
})

test('スマホの一覧から作成ダイアログを開いて閉じられる', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.goto('/equipments')
  await page.getByRole('button', { name: '新規作成' }).click()
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByLabel('設備名')).toBeVisible()
  await expect(dialog.getByRole('button', { name: '保存', exact: true })).toBeVisible()
  await dialog.getByRole('button', { name: 'キャンセル' }).click()
  await expect(dialog).not.toBeVisible()
})

// ページ全体の横スクロール（表・ダイアログの中のスクロールは数えない）
async function pageOverflow(page: Page) {
  return page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)
}

// 点検の不具合報告と対応記録を、スマホ幅で最後まで保存する（#90）。プラナの提案は fake のバックエンドでだけ確かめる（requireFakeAi）。
// 入力 → 提案 → 反映 が縦に並び、反映すると反映先の入力欄にフォーカスが移って見える位置に来ること、
// 提案を破棄・ダイアログを閉じると、フォーカスが元のボタンに戻ることを確かめる。
// スマホで報告する現場の人として運転員で行う（AIの1日の回数を、ほかのAIのE2Eが使う sato と取り合わないためでもある）
test('スマホで、点検の不具合をプラナの提案を反映して保存できる', async ({ page }) => {
  await login(page, ACCOUNTS.operator)
  const statusResponse = page.waitForResponse((r) => r.url().endsWith('/api/v1/ai/status'))
  await page.goto('/inspections/new')
  requireFakeAi((await (await statusResponse).json()).data.provider)
  await selectOption(page, '設備 *', '常圧蒸留装置')
  await selectOption(page, '計器（任意）', 'FT-301')
  await selectFirstOption(page, '部署 *')
  await page.getByRole('button', { name: '項目追加' }).click()
  await page.getByLabel('内容', { exact: true }).fill('指示値の確認')
  await page.getByRole('button', { name: '不具合あり' }).click()
  await expect(page.getByTestId('routine-checks')).toBeVisible()

  await page.getByLabel('現場メモ').fill('FT-301の指示が徐々に下がっている。')
  const draftButton = page.getByTestId('ai-draft-button')
  // 破棄すると、提案を作ったボタンにフォーカスが戻る
  await draftButton.click()
  await page.getByTestId('ai-draft').getByRole('button', { name: '破棄' }).click()
  await expect(page.getByTestId('ai-draft')).toHaveCount(0)
  await expect(draftButton).toBeFocused()

  await page.getByTestId('ai-similar-button').click()
  await expect(page.getByTestId('ai-similar-result')).toBeVisible()
  await draftButton.click()
  const draft = page.getByTestId('ai-draft')
  await expect(draft).toBeVisible()
  const draftTitle = (await page.getByTestId('ai-draft-title').innerText()).trim()
  // 反映のボタン（文言が長い）が、切れずに画面の幅に収まる
  const apply = page.getByTestId('ai-apply')
  const box = (await apply.boundingBox())!
  const cardBox = (await draft.boundingBox())!
  expect(box.x + box.width).toBeLessThanOrEqual(cardBox.x + cardBox.width)
  expect(await pageOverflow(page)).toBe(0)

  // 反映すると、提案の下にある「報告する内容」のタイトルにフォーカスが移り、見える位置に来る
  await apply.click()
  const titleInput = page.getByLabel('トラブルタイトル')
  await expect(titleInput).toHaveValue(draftTitle)
  await expect(titleInput).toBeFocused()
  await expect(titleInput).toBeInViewport()

  const title = `E2E ${Date.now()} スマホの不具合報告`
  await titleInput.fill(title)
  await page.getByRole('button', { name: '下書き保存' }).click()
  await expect(page).toHaveURL(/\/inspections\/\d+\?.*saved=/)
  expect(await pageOverflow(page)).toBe(0)
})

// 実行のたびに、シードのトラブル「FT-301 オリフィス閉塞疑い」に、対応記録（内容が `E2E ` で始まる）が1件ずつ増える
test('スマホで、トラブル詳細から対応記録をプラナの提案を反映して保存できる', async ({ page }) => {
  await login(page, ACCOUNTS.operator)
  await page.goto('/troubles?site_ids=all')
  await page.getByRole('textbox', { name: 'タイトル検索' }).fill('FT-301 オリフィス閉塞疑い')
  const statusResponse = page.waitForResponse((r) => r.url().endsWith('/api/v1/ai/status'))
  await openListRow(page, 'FT-301 オリフィス閉塞疑い')
  requireFakeAi((await (await statusResponse).json()).data.provider)
  await expect(page.getByRole('heading', { level: 1, name: 'FT-301 オリフィス閉塞疑い' })).toBeVisible()
  expect(await pageOverflow(page)).toBe(0)

  // 何も入力せずに閉じると、開いたボタンにフォーカスが戻る
  const openButton = page.getByRole('button', { name: '対応記録', exact: true })
  const dialog = page.getByRole('dialog', { name: '対応記録追加' })
  await openButton.click()
  await dialog.getByRole('button', { name: 'キャンセル' }).click()
  await expect(dialog).toHaveCount(0)
  await expect(openButton).toBeFocused()

  await openButton.click()
  await page.getByLabel('対応メモ').fill('オリフィスの上流側を清掃した。')
  await page.getByTestId('ai-response-button').click()
  await expect(page.getByTestId('ai-response-draft')).toBeVisible()
  expect(await pageOverflow(page)).toBe(0)

  // 反映すると、提案の下にある「保存する内容」の対応内容にフォーカスが移り、見える位置に来る
  await page.getByTestId('ai-response-apply').click()
  const description = page.getByLabel('対応内容 *')
  await expect(description).toHaveValue(/オリフィスの上流側を清掃した/)
  await expect(description).toBeFocused()
  await expect(description).toBeInViewport()

  const text = `E2E ${Date.now()} スマホの対応記録`
  await description.fill(text)
  // ダイアログの操作ボタンは、中身をスクロールしても画面の中に残る
  const save = dialog.getByRole('button', { name: '記録', exact: true })
  await expect(save).toBeInViewport()
  await save.click()
  await expect(dialog).toHaveCount(0)
  await expect(openButton).toBeFocused()
  await expect(page.getByText(text)).toBeVisible()
})

// スマホ（600px 以下）以外では、メニューは開いた状態で始まる（Vuetify の既定だと 1280px 未満でも閉じてしまう）
test.describe('タブレット・小さめのノートPCの幅', () => {
  for (const width of [768, 1024]) {
    test(`${width}px 幅では、メニューが開いた状態で始まる`, async ({ page }) => {
      await page.setViewportSize({ width, height: 800 })
      await login(page, ACCOUNTS.admin)
      await expect(page.getByRole('link', { name: '設備台帳', exact: true })).toBeInViewport()
    })
  }
})
