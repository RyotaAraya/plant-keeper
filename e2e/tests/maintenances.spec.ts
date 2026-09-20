import { test, expect, login, ACCOUNTS } from './support'
import { todayForInput } from '../../frontend/src/utils/datetime'

const WORKER = { email: 'honda@example.com', password: 'password' }

// 定期整備は「親」: 関連設備をまとめて対象にし、計画中 → 準備中 → 実施中 → 検収 → 完了 と進める。検収を記録して完了にする。
// このテストは定期整備を1件作る（名前が「E2E 」で始まる。繰り返し実行すると一覧に溜まる）
test('複数の設備を対象にした定期整備を作り、検収を記録して完了まで進められる', async ({ page }) => {
  const title = `E2E ${Date.now()} A号ボイラー整備`
  await login(page, ACCOUNTS.admin)
  await page.getByRole('link', { name: '定期整備', exact: true }).click()
  await expect(page.getByRole('heading', { level: 1, name: '定期整備' })).toBeVisible()

  await test.step('複数の対象設備を選んで作成する', async () => {
    await page.getByRole('button', { name: '新規作成' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('名称 *', { exact: false }).fill(title)
    await dialog.getByLabel('予定 開始日 *').fill(todayForInput())
    await dialog.locator('.v-field', { has: page.getByLabel('対象設備 *') }).click()
    await page.getByRole('option', { name: 'ボイラー設備' }).click()
    await page.getByRole('option', { name: '常圧蒸留装置' }).click()
    await page.keyboard.press('Escape') // 選択肢のメニューを閉じる（ダイアログは閉じない）
    await dialog.getByRole('button', { name: '作成' }).click()
    await expect(dialog).toBeHidden()
  })

  await test.step('一覧に、対象設備が複数並ぶ', async () => {
    const row = page.getByRole('row', { name: new RegExp(title) })
    await expect(row).toContainText('ボイラー設備')
    await expect(row).toContainText('常圧蒸留装置')
    await expect(row).toContainText('計画中')
    await row.click()
  })

  const status = page.getByTestId('maintenance-status')
  await expect(status).toHaveText('計画中')

  await test.step('準備中 → 実施中（実績の開始日が入る）', async () => {
    await page.getByRole('button', { name: '準備中にする' }).click()
    await expect(status).toHaveText('準備中')
    await page.getByRole('button', { name: '実施中にする' }).click()
    await expect(status).toHaveText('実施中')
    await expect(page.getByText('実績期間').locator('..')).toContainText(todayForInput())
  })

  await test.step('検収へ進むと、検収を記録するまで完了にできない', async () => {
    await page.getByRole('button', { name: '検収へ進む' }).click()
    await expect(status).toHaveText('検収')
    await expect(page.getByRole('button', { name: '完了にする' })).toBeDisabled()
    await expect(page.getByText('完了にするには、検収を記録してください')).toBeVisible()
  })

  await test.step('検収を記録すると、完了にできる', async () => {
    await page.getByRole('button', { name: '検収を記録' }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel('指摘事項').fill('計器のタグ札を交換すること')
    await dialog.getByRole('button', { name: '記録' }).click()
    const card = page.getByTestId('acceptance-card')
    await expect(card).toContainText('合格')
    await expect(card).toContainText('計器のタグ札を交換すること')
    await page.getByRole('button', { name: '完了にする' }).click()
    await expect(status).toHaveText('完了')
    await expect(page.getByRole('button', { name: /にする|に戻す|検収へ進む|手直しに戻す/ })).toHaveCount(0) // 完了からは進めも戻せもしない
  })
})

// 一般ユーザ・協力会社は、定期整備を見られるが、作成・編集・状態の変更はできない
for (const [label, account] of [['一般ユーザ', ACCOUNTS.member], ['協力会社の技能員', WORKER]] as const) {
  test(`${label}は定期整備を見られるが、作成・編集・状態の変更はできない`, async ({ page }) => {
    await login(page, account)
    await page.getByRole('link', { name: '定期整備', exact: true }).click()
    await expect(page.getByRole('heading', { level: 1, name: '定期整備' })).toBeVisible()
    await expect(page.getByRole('button', { name: '新規作成' })).toHaveCount(0)

    const row = page.locator('tbody tr', { has: page.locator('.v-chip') }).first()
    await expect(row).toBeVisible()
    await row.click()
    await expect(page.getByTestId('maintenance-status')).toBeVisible()
    await expect(page.getByRole('button', { name: '編集' })).toHaveCount(0)
    await expect(page.getByRole('button', { name: /にする|に戻す|検収へ進む/ })).toHaveCount(0)
  })
}
