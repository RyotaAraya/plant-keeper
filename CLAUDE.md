# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

PlantKeeper — 石油プラントの保全業務を統合管理するWebアプリケーション。
計装保全の実務経験をベースにしたドメイン特化設計。

## 技術スタック

- フロントエンド: Vue 3 + TypeScript + Vuetify 3 (日本語ロケール) + Pinia + Vue Router 4 + Axios
- バックエンド: Rails 8 API mode + devise + devise-jwt
- DB: PostgreSQL 16
- インフラ: Docker（docker-compose、3コンテナ構成）

## 開発コマンド

```bash
# 起動
docker-compose up -d

# マイグレーション
docker-compose exec backend bundle exec rails db:migrate

# シードデータ（replantで全データ再投入）
docker-compose exec backend bundle exec rails db:seed:replant

# Railsコンソール
docker-compose exec backend bundle exec rails console

# ログ確認
docker-compose logs -f backend

# フロントエンド lint
docker-compose exec frontend npm run lint:fix

# バックエンド lint
docker-compose exec backend bundle exec rubocop -A

# フロントエンド ビルド確認（tsc はvuetify型エラーがあるため vite build を使用）
cd frontend && npx vite build
```

## アクセスURL（開発用）

- フロントエンド: http://localhost:5173
- バックエンドAPI: http://localhost:3000/api/v1

## ログイン情報（開発用）

- 管理者(admin): admin@example.com / password
- 管理者(manager): suzuki@example.com / password
- 一般(member): sato@example.com / password

## デプロイ（Render）

- 設定ファイル: `render.yaml`（Blueprint）。本番・stg の両サービスをこの1ファイルで定義
- 無料プランのため、アクセスが一定時間ない場合スリープする（初回アクセス時に起動待ちで数十秒かかることがある）

### ブランチ運用
- `develop` に push → stg に自動デプロイ。動作確認後、`develop` → `main` の PR をマージして本番リリース
- `main` に push/マージすると即本番に自動デプロイされる（GitHub連携によるauto-deploy）。直接 push しない
- dependabot の PR は `develop` 向け（`.github/dependabot.yml` の `target-branch`）。メジャー更新は stg で動作確認してから `main` へ
- CI（`.github/workflows/ci.yml`）は PR と `main`/`develop` への push で実行

### 本番
- フロントエンド: `plant-keeper-web`（static site、`frontend/` を `npm run build` → `dist/` を配信）
  - https://plant-keeper-web.onrender.com
- バックエンド: `plant-keeper-api`（Ruby、`backend/` を起動時に `db:migrate` 実行後 puma 起動）
  - https://plant-keeper-api.onrender.com/api/v1
- DB: `plant-keeper-db`（Render Postgres、free plan）

### stg（`develop` ブランチ）
- フロントエンド: `plant-keeper-web-stg` — https://plant-keeper-web-stg.onrender.com
- バックエンド: `plant-keeper-api-stg` — https://plant-keeper-api-stg.onrender.com/api/v1
- DB: Neon（無料Postgres）。Render管理外のため `DATABASE_URL` は Render ダッシュボードで手動設定する（Neonの接続文字列、`sslmode=require` 付き。`db:migrate` がadvisory lockを使うため、プーラー経由ではなくdirect接続（Connectで Connection pooling をオフ）を使う）
- `DEVISE_JWT_SECRET_KEY` は本番と別の値を設定する。`RAILS_MASTER_KEY` も手動設定
- 初回のみシード投入が必要（Render無料プランはシェルが使えないためローカルから実行。`db:migrate` は初回デプロイで実行済みのため `db:seed` のみ）:
  ```bash
  docker-compose exec -e DATABASE_URL='<Neonの接続文字列>' backend bundle exec rails db:seed
  ```
  （`db:seed:replant` は全データ削除のため、接続先を確認してから使うこと）
- pre-push フック（lefthook）を通過すれば push 自体は成功するが、Render側のビルド・デプロイ完了までは別途数分かかる。デプロイ状況はRenderダッシュボードで確認が必要（Claude Codeからは確認不可）

## 設計ドキュメント

- `要求仕様書.md` — 機能要件、業務フロー、設計方針
- `データモデル設計.md` — 27テーブルのER図・テーブル定義・簡易化メモ
- `DEVELOPMENT.md` — 開発環境構築ガイド
- `実装タスク表.md` — フェーズ別の実装タスク進捗表

## アーキテクチャ

### 機能優先度
1. **保全管理**（メイン）: 設備台帳、点検・作業記録、トラブル管理、定期整備
2. **運転部門チェック統合**: 保全と同じチェックリスト機能を使用、不具合→トラブル自動連携
3. **資材管理**: 資材マスタ、在庫（FIFO）、修理、発注、拠点横断検索
4. **ユーザ管理**: 全員ログイン、所属会社・雇用区分・権限の3軸管理、退職/復帰対応

### ユーザモデルの3軸設計

| 軸 | カラム | 自社(owner) | 協力会社(contractor) |
|---|---|---|---|
| 所属会社 | company_id → companies | company_type: owner | company_type: contractor |
| 雇用区分 | employment_type | employee / dispatch | contractor（自動設定） |
| 権限 | system_role | admin / manager / member | manager / worker |

- 会社タイプ変更で雇用区分・権限の選択肢が連動
- 協力会社は部署（department）なし

### 部署の階層構造
- departments テーブル: parent_id 自己参照で3階層（division→section→team）
- 拠点（site）ごとに独立したツリー。各行が `site_id` を持つ（非正規化）
- `Department#full_path` → "保全部 > 計器保全課 > 計器Aチーム"
- `Department#ancestor_chain` → 階層配列（UI用）
- API: `GET /departments?tree=true` でネストされたツリー取得（Ruby側でin-memoryでツリーを構築）
- モデルバリデーション: 自己参照禁止（`not_self_referential`）、階層整合性チェック（`valid_parent_level`）
- `full_path` / `ancestor_chain` は public メソッド。`private` キーワードより前に定義すること
- `update_params`（site_id除外）と `department_params`（create用、site_id含む）を分離。作成後の拠点変更不可

### バックエンド構造
- API: `/api/v1` 名前空間、全コントローラが `BaseController`（`authenticate_user!`）を継承
- 認証: devise-jwt、トークンは Authorization ヘッダーで送受信
- JWT revocation: `JTIMatcher` 戦略（usersテーブルの`jti`カラムで管理）
- 認可: Pundit（`BaseController` に `include Pundit::Authorization`）。各モデルに対応するポリシーファイルあり（`app/policies/`）。`ApplicationPolicy` のヘルパー: `admin?`、`owner_manager?`、`owner_company?`
- 監査ログ: `BaseController#record_audit_log(action, resource)` ヘルパーで統一記録（`resource.saved_changes` を `changes_json` に保存）
- レスポンス: `{ data: ... }` 形式

**シリアライズの使い分け:**
- `UserSerializer`（PORO）: 認証系レスポンスのみ（`POST /login`、`GET /current_user`）。返却フィールドはIDのみで、company/departmentオブジェクトのネストなし
- `user_json` ヘルパー: users一覧・詳細画面のレスポンスでcompany/departmentをネスト返却
- その他モデル: コントローラ内で `as_json(include: ...)` インライン（ActiveModel::Serializers不使用）

**コントローラの一貫したパターン:**
- `index`: `includes(...)` + `if params[:x].present?` チェーンフィルタ + `limit/offset` ページネーション
- `show`: 深い `includes(...)` + 完全ネストJSON。computed fields（`troubles_count`, `stock_summary`等）は `.merge(...)` で付与
- ネストされたコレクション更新（点検項目等）: フロントから送られたIDを収集 → 送られていないIDの子レコードを `destroy_all` → ループでupsert（ID有りは更新、ID無しは作成）
- 複数テーブルへの書き込みは必ず `ActiveRecord::Base.transaction` でラップ

**ルート上の注意点:**
- `destroy` ルートがあるのは `checklist_templates` と `maintenance_assignments` のみ。それ以外は `is_active` フラグで論理削除
- `checklist_templates` にはカスタムメンバーアクション `POST /:id/duplicate` あり（テンプレートと全項目を複製、名前に「（コピー）」付与）
- `position` フィールドは `user_params` の permit リストに含まれず、API経由での更新不可（読み取りは可能）

### フロントエンド構造
- ルーティング: `meta: { requiresAuth: true }` でガード、遅延ロード
- 認証: `stores/auth.ts` で JWT を localStorage 管理、axios インターセプタで自動付与
- 認可: `composables/usePermissions.ts` — バックエンドの Pundit ポリシーに対応した computed プロパティ群。`canManageCore = isAdmin || isOwnerManager` が共通パターン。SideNavのメニュー表示制御と各ビュー内のボタン表示制御の両方で使用
- 画面パターン: `*ListView.vue`（一覧+フィルタ） + `*DetailView.vue`（詳細+編集ダイアログ）
- UIパターン: カスケードセレクト（拠点→部→課→チーム）に `initializing` フラグで watch 連鎖抑制
- `InspectionFormView.vue` は `/inspections/new` と `/inspections/:id/edit` で共用
- `orders/` には一覧ビューのみ（詳細ビューなし）

**Axiosインターセプタ:**
- リクエスト: localStorageから `jwt` を読みAuthorizationヘッダーにセット
- レスポンス: バックエンドが新しい `Authorization` ヘッダーを返した場合、localStorageの `jwt` を上書き（JWTローテーションを透過的に処理）

**認証ストア（`stores/auth.ts`）:**
- singleton promiseパターン: `initPromise` 変数でページロード時の並行初期化競合を防止
- `initialize()` はべき等 — 複数回呼び出しても同じPromiseを返す
- ログアウト失敗時（ネットワーク障害等）もローカル状態とlocalStorageはクリア（UX優先のフェイルオープン）

### データモデルの設計方針
- 論理削除: sites.is_active / users.is_active / companies.is_active（履歴保持）
- 履歴パターン: started_on/ended_on（equipment_assignments, department_histories）
- ポリモーフィック監査ログ: audit_logs（auditable_type/auditable_id）
- 自己結合: departments（parent_id）、material_alternatives（代替品）
- 正規化検索: materials.normalized_part_number（ハイフン除去、`before_save` で自動設定）。検索時もクエリ側で同様にハイフン除去してから `ILIKE` 検索
- 添付ファイル: ActiveStorage（has_many_attached）— 専用テーブルなし
- 在庫: `purchased_on: :asc` 順（FIFO）

### 簡易実装方針
- 承認フロー: UIのみ（ボタンでステータス変更、ロジックなし）
- 価格履歴: orders テーブルで兼用
- 使用資材記録: テキストカラム（trouble_responses.used_materials 等）
- 監査ログ出力: CSV のみ
- 発注アラート: ダッシュボードにリスト表示のみ（メール通知なし）
- ダッシュボードの在庫アラート: `Material#select` ブロック内で `stocks.sum(:quantity)` を呼ぶため、対象資材数によってN+1が発生（現状のデータ規模では許容）

### バックエンドの規約
- レスポンス形式: 成功 `{ data: ... }`、エラー `{ errors: [...] }`
- ページネーション: `page`/`per_page` パラメータ → `{ data: [...], meta: { total_count, page, per_page } }`。ページネーションなしのエンドポイントもあり（users, departments, checklist_templates）
- フィルタリング: コントローラ内で `if params[:x].present?` チェーンで実装
- 全文検索: `ILIKE '%query%'` パターン（users: name+email, troubles: title, instruments: tag_number, materials: name+part_number+normalized_part_number）
- enum はすべて文字列型（integer ではない）
- `AuditLog` の enum は `prefix: true` 付き → `action_create?` / `action_update?` 等（`create?` ではない）
- 論理削除リソースには `destroy` ルートなし
- JSON シリアライズ: `as_json(include: ...)` インライン。ActiveModel::Serializers 不使用（UserSerializer のみ PORO）
- シードファイル: `db/seeds/` 配下に 01〜13 の番号付きファイルで分割
- 点検で不具合検出時、InspectionsController 内でトラブルを自動作成（モデルコールバックではなくコントローラロジック）。`has_defect && defect_title.present? && trouble.nil?` の条件で重複作成を防止

### フロントエンドの規約
- API呼び出し: `src/api/axios.ts` の単一 Axios インスタンスを直接使用（サービス層なし）
- 型定義: `src/types/models.ts` に全インターフェースを集約
- 認証ストア: `stores/auth.ts` で singleton promise パターンによる初期化（レースコンディション防止）
- レイアウト: `MainLayout.vue` → `AppBar.vue` + `SideNav.vue` のスロット構成
- Pinia は router より先に登録（router の `beforeEach` で `useAuthStore()` を使用するため）

## 注意事項

- GitHub公開リポジトリ。ポートフォリオ関連の文言をコードやドキュメントに書かない
- 日本語でコミュニケーション
- テストスイートなし（RSpec/Minitest/Vitest いずれも未導入）
- `equipment` は Rails で不可算名詞扱い。`config/initializers/inflections.rb` で `irregular "equipment", "equipments"` を定義済み
- JWT認証: ログイン POST /api/v1/login、ログアウト DELETE /api/v1/logout
- pre-push フック（lefthook）: ESLint → vue-tsc → RuboCop が直列実行（`docker-compose exec -T` 経由）
- vue-tsc は Vuetify の型定義で既知のエラーあり。ビルド確認は `npx vite build` を使用
- シードの audit_log 部分で `Auditable must exist` バリデーションエラーが出るが、ユーザ・設備等の主要データには影響なし
