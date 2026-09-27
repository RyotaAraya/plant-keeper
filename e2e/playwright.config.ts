import { defineConfig, devices } from '@playwright/test'

// 既定はローカル（docker-compose）。stg で実行する場合は E2E_BASE_URL を指定する
const baseURL = process.env.E2E_BASE_URL ?? 'http://localhost:5173'

// テストを動かすマシンの時刻帯にかかわらず、アプリと同じ日本時間で「今日」を求める（todayForInput() などは、テストを動かすNodeのローカル時間を使う）。
// CI（GitHub Actions）はUTCのため、日本時間の0〜9時（UTCの前日）に、アプリが記録する日付とずれて失敗していた。
// use.timezoneId はブラウザの時刻帯だけを変えるので、テストのNode側は、ここで環境変数を設定する（ワーカーが引き継ぐ）
process.env.TZ = 'Asia/Tokyo'

// 点検などのデータを作成するテストを含むため、本番のデモ環境では実行させない
if (/^https:\/\/plant-keeper-web\.onrender\.com/.test(baseURL)) {
  throw new Error('E2Eは本番環境では実行できません。ローカルまたはstgを指定してください。')
}

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  forbidOnly: !!process.env.CI,
  // CIのジョブ（--shard）への振り分けを、ファイル単位ではなくテスト単位にする（ファイルの大きさの差で、ジョブの時間がそろわないため）。
  // そのため、同じファイルのテストどうしでも、順番・前のテストのデータに頼らない（別のジョブ・ワーカーで動くことがある）
  fullyParallel: true,
  // ローカルのdevサーバー（vite dev）は再起動後の初回アクセスで依存の再最適化とリロードが走り、初回だけ失敗することがあるため1回リトライする
  retries: 1,
  // CIは1並列。ランナー（非公開リポジトリは2コア）の中で並列にしても、ブラウザ・API・DBがCPUを取り合って短くならなかった
  // （2並列 9.7分・7.9分、APIを2プロセスにしても10.3分）。CIでは、4つのジョブに分けて（--shard）別のマシンで流す（ci.yml）
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
