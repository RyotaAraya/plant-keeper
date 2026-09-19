# PlantKeeper

石油プラントの保全業務を統合管理するWebアプリケーション。
計装保全の実務経験をベースにしたドメイン特化設計で、設備台帳・点検記録・トラブル管理・資材管理などを一元化します。

## 主な機能

### 保全管理（コア）
- **設備台帳** — プラント設備・計器の一覧管理、設備ツリー
- **点検・作業記録** — チェックリストベースの定期点検、作業実績の記録・承認
- **トラブル管理** — 不具合報告から対応完了までの追跡、優先度・ステータス管理
- **定期整備** — 定期保全のスケジュール管理、担当者アサイン

### 資材管理
- **資材マスタ** — 型番・メーカー・代替品の管理、正規化検索
- **在庫管理** — 拠点・倉庫別の在庫追跡（FIFO）、発注点アラート
- **発注管理** — 見積もり〜発注〜受領のステータス管理
- **修理管理** — 外部修理の送付・返却追跡

### 組織管理
- **ユーザ管理** — 所属会社（自社/協力会社）・雇用区分・権限の3軸管理、退職・復帰対応
- **部署管理** — 部→課→チームの3階層組織、役職管理
- **拠点管理** — 複数拠点の横断管理

### その他
- **ダッシュボード** — 未対応トラブル、在庫アラート、直近の整備予定を一覧表示
- **監査ログ** — 操作履歴のCSVエクスポート

## 技術スタック

| レイヤー | 技術 |
|----------|------|
| フロントエンド | Vue 3, TypeScript, Vuetify 3, Pinia, Vue Router 4, Axios |
| バックエンド | Ruby on Rails 8 (API mode), Devise, Devise-JWT |
| データベース | PostgreSQL 16 |
| インフラ | Docker, docker-compose（開発）/ Render, Neon（デプロイ） |
| テスト | Minitest（バックエンド）, Playwright（E2E） |
| CI/CD・依存更新 | GitHub Actions, Renovate |
| コード品質 | ESLint, RuboCop, Brakeman, vue-tsc, Lefthook |

## 環境

| 環境 | ブランチ | フロントエンド | API |
|------|----------|----------------|-----|
| 本番（デモ） | `main` | https://plant-keeper-web.onrender.com | https://plant-keeper-api.onrender.com/api/v1 |
| stg | `develop` | https://plant-keeper-web-stg.onrender.com | https://plant-keeper-api-stg.onrender.com/api/v1 |

- `develop` への push で stg に、`main` へのマージで本番に自動デプロイされます。stg で動作確認してから `develop` → `main` の PR でリリースします
- 無料プランのため、しばらくアクセスがないとスリープし、初回アクセス時は起動に数十秒〜1分ほどかかります
- 本番のDBは Render Postgres、stg のDBは Neon です

## 開発フロー

- **テスト**: `backend/test/` に Minitest（認証・権限・点検→トラブル自動作成・資材検索・モデル検証）、`e2e/` に Playwright のスモークテスト（認証・画面遷移・ロール別の表示制御・点検から不具合報告→トラブル登録）
- **CI**（GitHub Actions）: PR と `main`/`develop` への push で、Brakeman、RuboCop、バックエンドのテスト、フロントの lint + ビルド、E2E を実行
- **依存更新**: [Renovate](https://docs.renovatebot.com/) が毎週月曜の朝に `develop` 向けの更新PRを作成。patch は公開3日後にCI成功で自動マージ、minor は手動マージ、major は承認制
- 開発コマンド・テストの実行方法・デプロイ手順・設計上の規約は [CLAUDE.md](CLAUDE.md) にまとめています

## アーキテクチャ

```
frontend/          Vue 3 SPA (Vite dev server :5173)
    ↓ API calls
backend/           Rails 8 API (:3000)
    ↓
db                 PostgreSQL 16 (:5432)
```

- JWT認証（Authorization ヘッダー）
- フロントエンド → バックエンドの通信は Axios + CORS
- 27テーブルのリレーショナルデータモデル

## ローカルでの起動

Docker Desktop が必要です。

```bash
docker-compose up -d
docker-compose exec backend bundle exec rails db:create db:migrate db:seed
```

http://localhost:5173 を開き、デモアカウントでログインできます（管理者: `admin@example.com` / `password`）。

## ライセンス

MIT
