import { defineConfig, devices } from '@playwright/test'

// 既定はローカル（docker-compose）。stg で実行する場合は E2E_BASE_URL を指定する
const baseURL = process.env.E2E_BASE_URL ?? 'http://localhost:5173'

// 点検などのデータを作成するテストを含むため、本番のデモ環境では実行させない
if (/^https:\/\/plant-keeper-web\.onrender\.com/.test(baseURL)) {
  throw new Error('E2Eは本番環境では実行できません。ローカルまたはstgを指定してください。')
}

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  forbidOnly: !!process.env.CI,
  // ローカルのdevサーバー（vite dev）は再起動後の初回アクセスで依存の再最適化とリロードが走り、初回だけ失敗することがあるため1回リトライする
  retries: 1,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL,
    locale: 'ja-JP',
    timezoneId: 'Asia/Tokyo',
    actionTimeout: 15_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
})
