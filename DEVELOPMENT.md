# 開発環境構築ガイド

## 前提条件

- Docker Desktop
- Git
- [Lefthook](https://github.com/evilmartians/lefthook)（Git hooks 管理）

## セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/<your-username>/plant-keeper.git
cd plant-keeper
```

### 2. コンテナの起動

```bash
docker-compose up -d
```

3つのコンテナが起動します：

| コンテナ | ポート | 説明 |
|----------|--------|------|
| `manage-frontend-1` | http://localhost:5173 | Vue 3 開発サーバー（Vite） |
| `manage-backend-1` | http://localhost:3000 | Rails API サーバー |
| `manage-db-1` | localhost:5432 | PostgreSQL 16 |

### 3. Git Hooks のセットアップ

```bash
# macOS
brew install lefthook

# インストール後
lefthook install
```

### 4. データベースのセットアップ

```bash
docker-compose exec backend bundle exec rails db:create
docker-compose exec backend bundle exec rails db:migrate
docker-compose exec backend bundle exec rails db:seed
```

### 5. 動作確認

ブラウザで http://localhost:5173 にアクセスし、以下のアカウントでログインできれば成功です。

| ロール | メールアドレス | パスワード |
|--------|---------------|-----------|
| 管理者 | admin@example.com | password |
| 監督者 | suzuki@example.com | password |
| 作業員 | sato@example.com | password |

## よく使うコマンド

### 起動・停止

```bash
# 起動
docker-compose up -d

# 停止
docker-compose down

# ログ確認
docker-compose logs -f backend
docker-compose logs -f frontend
```

### バックエンド

```bash
# Railsコンソール
docker-compose exec backend bundle exec rails console

# マイグレーション
docker-compose exec backend bundle exec rails db:migrate

# マイグレーションをリセットしてシードを再投入
docker-compose exec backend bundle exec rails db:migrate:reset
docker-compose exec backend bundle exec rails db:seed

# ルーティング確認
docker-compose exec backend bundle exec rails routes
```

### フロントエンド

```bash
# ESLint
docker-compose exec frontend npm run lint

# ESLint（自動修正）
docker-compose exec frontend npm run lint:fix

# 型チェック
docker-compose exec frontend npm run typecheck

# 型チェック + ビルド（CIと同じ。vue-tsc -b → vite build）
docker-compose exec frontend npm run build
```

> 型チェックは `vue-tsc -b`（project references のビルドモード）で行います。ルートの `tsconfig.json` は `files: []` 構成のため、`-b` なしの `vue-tsc --noEmit` は何も検査しません。

## テスト

### バックエンド（Minitest）

認証・権限（Pundit）・点検→トラブル自動作成・資材の型番検索・モデル検証のテストが `backend/test/` にあります。フィクスチャは使わず、`test/support/test_data.rb` のヘルパーでテストごとにデータを作ります。

```bash
# 初回・スキーマ変更時: テスト用DBを作り直す
# （db:prepare は新規DBにシードを投入するので使わない）
T=postgres://manage:manage_password@db:5432/manage_test
docker-compose exec -e DATABASE_URL=$T -e RAILS_ENV=test backend bash -c 'bin/rails db:drop db:create db:schema:load'

# 実行
docker-compose exec -e DATABASE_URL=$T backend bin/rails test
```

コンテナの `DATABASE_URL` は開発DBを指しているため、必ず上記のように `manage_test` を指定します。`*_test` 以外のDBに接続している場合は `test/test_helper.rb` がテストを中断します（開発DBの誤初期化防止）。

### E2E（Playwright）

`e2e/` に、ブラウザ経由のスモークテストがあります（認証、主要画面の遷移と権限、ロール別のメニュー・ボタンの出し分け、点検で不具合報告 → トラブル自動登録）。シードのデモアカウントを使うため、`docker-compose up -d` とシード投入が済んでいる状態で実行します。

```bash
# 初回のみ（ホストのNodeで実行）
cd e2e && npm install && npx playwright install chromium

# ローカル（http://localhost:5173）に対して実行
npx playwright test

# stgに対して実行（本番は設定で拒否されます）。無料プランのAPIがスリープしていると起動に1分近くかかるため、先に起こしておく
curl -s -o /dev/null -m 120 https://plant-keeper-api-stg.onrender.com/up
E2E_BASE_URL=https://plant-keeper-web-stg.onrender.com npx playwright test
```

点検のテストは実行のたびにデータ（タイトルが `E2E ` で始まる点検・トラブル）を追加します。ローカルは `db:seed:replant`、stg は管理者の `admin/reseed` で元に戻せます。

## ブランチ運用・CI・デプロイ

| ブランチ | デプロイ先 |
|----------|-----------|
| `develop` | stg（Render + Neon） |
| `main` | 本番（Render） |

1. 変更は `develop` に反映すると stg に自動デプロイされる
2. stg で動作確認したら、`develop` → `main` の PR を作成・マージして本番リリース（`main` へは直接 push しない）
3. PR と `main`/`develop` への push で GitHub Actions（`.github/workflows/ci.yml`）が走る: Brakeman / RuboCop / バックエンドのテスト / フロントの lint + ビルド / E2E
4. 依存更新は [Renovate](https://docs.renovatebot.com/)（`.github/renovate.json5`）が `develop` 向けにPRを作成する（patch は自動マージ、minor は手動、major は Dependency Dashboard で承認）

Render の構成は `render.yaml`（Blueprint）に定義しています。各環境のURL・環境変数・初回セットアップは [CLAUDE.md](CLAUDE.md) の「デプロイ（Render）」を参照してください。

## プロジェクト構成

```
.
├── docker-compose.yml
├── render.yaml               Render のデプロイ定義（本番・stg）
├── .github/
│   ├── workflows/ci.yml      CI（GitHub Actions）
│   └── renovate.json5        依存更新（Renovate）
├── backend/                  Rails 8 API
│   ├── app/
│   │   ├── controllers/api/v1/   API コントローラー
│   │   └── models/               モデル（27テーブル）
│   ├── config/
│   ├── db/
│   │   ├── migrate/              マイグレーション
│   │   ├── schema.rb
│   │   ├── seeds.rb              シードの読み込み
│   │   └── seeds/                デモ・開発用シードデータ（番号付きファイル）
│   ├── test/                     Minitest
│   ├── Dockerfile
│   └── Gemfile
├── e2e/                      Playwright E2Eテスト
├── frontend/                 Vue 3 SPA
│   ├── src/
│   │   ├── api/                  Axios 設定
│   │   ├── components/layout/    共通レイアウト（AppBar, SideNav）
│   │   ├── plugins/              Vuetify, Pinia 設定
│   │   ├── router/               Vue Router 設定
│   │   ├── stores/               Pinia ストア
│   │   ├── types/                TypeScript 型定義
│   │   └── views/                ページコンポーネント
│   ├── Dockerfile
│   └── package.json
├── README.md
├── DEVELOPMENT.md            開発環境構築ガイド
├── CLAUDE.md                 Claude Code 設定
├── lefthook.yml              Git hooks 設定（pre-push）
├── 要求仕様書.md
└── データモデル設計.md
```

## コード品質

`git push` 時に Lefthook が自動で以下のチェックを実行します。

| チェック | 対象 | 内容 |
|---------|------|------|
| ESLint | `frontend/src/` | Vue + TypeScript の lint（自動修正） |
| vue-tsc | `frontend/` | TypeScript 型チェック（`-b`） |
| RuboCop | `backend/` | Ruby スタイルチェック（自動修正） |

pre-push ではテストは実行しません。テストと、型チェックを含むビルドは CI（Pull Request / push）で実行されます。

手動で実行する場合：

```bash
# フロントエンド
docker-compose exec frontend npm run lint:fix
docker-compose exec frontend npm run typecheck

# バックエンド
docker-compose exec backend bundle exec rubocop -A
```

## API 認証

JWT（JSON Web Token）ベースの認証を使用しています。

```bash
# ログイン — Authorization ヘッダーでトークンを返却
curl -D - -X POST http://localhost:3000/api/v1/login \
  -H 'Content-Type: application/json' \
  -d '{"user":{"email":"admin@example.com","password":"password"}}'

# APIリクエスト — Authorization ヘッダーにトークンを付与
curl http://localhost:3000/api/v1/dashboard \
  -H 'Authorization: Bearer <token>'

# ログアウト
curl -X DELETE http://localhost:3000/api/v1/logout \
  -H 'Authorization: Bearer <token>'
```

## 環境変数

`docker-compose.yml` で設定済み（開発環境）：

| 変数 | 値 | 説明 |
|------|-----|------|
| `DATABASE_URL` | `postgres://manage:manage_password@db:5432/manage_development` | DB接続 |
| `RAILS_ENV` | `development` | Rails環境 |
| `DEVISE_JWT_SECRET_KEY` | `dev_jwt_secret_key_change_in_production` | JWT署名キー |

## トラブルシューティング

### HMR（ホットリロード）が効かない

Docker + macOS 環境では `vite.config.ts` に `usePolling: true` が設定されています。
それでも反映されない場合はフロントエンドコンテナを再起動してください。

```bash
docker-compose restart frontend
```

### API が 401 Unauthorized を返す

JWTトークンの有効期限が切れています。再ログインしてください。

### マイグレーションエラー

スキーマが合わない場合はリセットしてください。

```bash
docker-compose exec backend bundle exec rails db:migrate:reset
docker-compose exec backend bundle exec rails db:seed
```

### backend コンテナが起動しない

Puma のPIDファイルが残っている可能性があります。`docker-compose.yml` の command で `rm -f tmp/pids/server.pid` を実行済みですが、解消しない場合：

```bash
docker-compose down
docker-compose up -d
```
