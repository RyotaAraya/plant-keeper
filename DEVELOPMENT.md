# 開発環境構築ガイド

## 前提条件

- Docker Desktop
- Git

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

### 3. データベースのセットアップ

```bash
docker-compose exec backend bundle exec rails db:create
docker-compose exec backend bundle exec rails db:migrate
docker-compose exec backend bundle exec rails db:seed
```

### 4. 動作確認

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
# 型チェック
docker-compose exec frontend npx vue-tsc --noEmit

# ビルド
docker-compose exec frontend npm run build
```

## プロジェクト構成

```
.
├── docker-compose.yml
├── backend/                  Rails 8 API
│   ├── app/
│   │   ├── controllers/api/v1/   API コントローラー
│   │   └── models/               モデル（26テーブル）
│   ├── config/
│   ├── db/
│   │   ├── migrate/              マイグレーション
│   │   ├── schema.rb
│   │   └── seeds.rb              開発用シードデータ
│   ├── Dockerfile
│   └── Gemfile
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
├── CLAUDE.md                 Claude Code 設定
├── 要求仕様書.md
└── データモデル設計.md
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
