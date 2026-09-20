import { test, expect, openListRow, login, ACCOUNTS } from './support'

// 定期整備の系列: 設備ごとの周期を登録し、「次回を作る」で周期が来た設備を自動で対象にする（ボイラー2年・もう一方は4年）。
// このテストは定期整備を3件作る（名前が「E2E 」で始まる。繰り返し実行すると一覧に溜まる）
test('系列に登録して次回を作ると、周期が来た設備だけが対象になり、4年後の回には両方の設備が入る', async ({ page }) => {
  const stamp = Date.now()
  const title = `E2E ${stamp} 2026年 A号ボイラー整備`
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '定期整備', exact: true }).click()

  await test.step('複数設備の定期整備を作る（2026年4月）', async () => {
    await page.getByRole('button', { name: '新規作成' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('名称 *', { exact: false }).fill(title)
    await dialog.getByLabel('予定 開始日 *').fill('2026-04-01')
    await dialog.getByLabel('予定 終了日').fill('2026-04-30')
    await dialog.locator('.v-field', { has: page.getByLabel('対象設備 *') }).click()
    await page.getByRole('option', { name: 'ボイラー設備' }).click()
    await page.getByRole('option', { name: '常圧蒸留装置' }).click()
    await page.keyboard.press('Escape')
    await dialog.getByRole('button', { name: '作成' }).click()
    await expect(dialog).toBeHidden()
    await openListRow(page, title)
  })

  await test.step('系列に登録する（ボイラー設備は24か月、常圧蒸留装置は48か月ごと）', async () => {
    const card = page.getByTestId('series-card')
    await expect(card).toContainText('系列に属していません')
    await card.getByRole('button', { name: '系列に登録' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('常圧蒸留装置の周期（月）').fill('48')
    await dialog.getByRole('button', { name: '保存' }).click()
    await expect(dialog).toBeHidden()
    await expect(card).toContainText('ボイラー設備（24か月ごと）')
    await expect(card).toContainText('常圧蒸留装置（48か月ごと）')
    await expect(card.locator('[data-testid^="series-history-"]')).toHaveCount(1)
  })

  await test.step('次回（2年後）は、名称の年が進み、周期が来たボイラー設備だけが選ばれている', async () => {
    await page.getByRole('button', { name: '次回を作る' }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByLabel('名称 *')).toHaveValue(`E2E ${stamp} 2028年 A号ボイラー整備`)
    await expect(dialog.getByLabel('予定 開始日 *')).toHaveValue('2028-04-01')
    await expect(dialog.getByLabel('予定 終了日')).toHaveValue('2028-04-30')
    const boiler = dialog.getByTestId('candidate-ボイラー設備')
    const cdu = dialog.getByTestId('candidate-常圧蒸留装置')
    await expect(boiler.getByRole('checkbox')).toBeChecked()
    await expect(boiler).toContainText('周期が来ている')
    await expect(cdu.getByRole('checkbox')).not.toBeChecked()
    await expect(cdu).toContainText('まだ周期が来ていない')
    await dialog.getByRole('button', { name: '作成' }).click()
  })

  await test.step('2028年の定期整備が作られ、対象はボイラー設備だけ、系列の履歴に2件が並ぶ', async () => {
    await expect(page.getByRole('heading', { level: 1, name: `E2E ${stamp} 2028年 A号ボイラー整備` })).toBeVisible()
    await expect(page.getByTestId('maintenance-status')).toHaveText('計画中')
    await expect(page.getByText('対象設備（1）')).toBeVisible()
    await expect(page.getByTestId('series-card').locator('[data-testid^="series-history-"]')).toHaveCount(2)
  })

  await test.step('さらに次回（4年後の2030年）には、両方の設備が入る', async () => {
    await page.getByRole('button', { name: '次回を作る' }).click()
    const dialog = page.getByRole('dialog')
    await expect(dialog.getByLabel('予定 開始日 *')).toHaveValue('2030-04-01')
    await expect(dialog.getByTestId('candidate-ボイラー設備').getByRole('checkbox')).toBeChecked()
    await expect(dialog.getByTestId('candidate-常圧蒸留装置').getByRole('checkbox')).toBeChecked()
    await dialog.getByRole('button', { name: 'キャンセル' }).click()
  })
})

test('系列に属さない定期整備も、次回を作れる（日付は入力する）', async ({ page }) => {
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '定期整備', exact: true }).click()
  // シードの定期整備（系列なし）。E2Eが作った系列つきの整備と、デモの系列（A号ボイラー整備）は除く
  const row = page.locator('tbody tr', { has: page.locator('.v-chip'), hasNotText: /E2E|A号ボイラー整備/ }).first()
  await expect(row).toBeVisible()
  await row.click()

  await page.getByRole('button', { name: '次回を作る' }).click()
  const dialog = page.getByRole('dialog')
  await expect(dialog.getByLabel('予定 開始日 *')).toHaveValue('') // 周期が分からないので、提案しない
  await expect(dialog.getByRole('checkbox').first()).toBeChecked() // 対象設備はそのまま引き継ぐ
  await dialog.getByRole('button', { name: 'キャンセル' }).click()
})
