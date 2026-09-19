# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

PlantKeeper — 石油プラントの保全業務を統合管理するWebアプリケーション。
計装保全の実務経験をベースにしたドメイン特化設計。

## 技術スタック

- フロントエンド: Vue 3 + TypeScript + Vuetify 3 (日本語ロケール) + Pinia + Vue Router 4 + Axios
- バックエンド: Rails 8 API mode + devise + devise-jwt
- DB: PostgreSQL 16
- インフラ: Docker（docker-compose、3コンテナ構成）。デプロイ先は Render（本番・stg）、stg のDBのみ Neon
- テスト: バックエンド Minitest、E2E Playwright（フロントの単体テストは未導入）
- CI/CD・依存更新: GitHub Actions、Renovate（Dependabot は使わない。脆弱性アラートは GitHub 側の Dependabot alerts を参照）

## セットアップ（初回）

前提: Docker Desktop、Git、[Lefthook](https://github.com/evilmartians/lefthook)（`brew install lefthook`）

```bash
docker-compose up -d    # frontend :5173 / backend :3000 / db :5432 の3コンテナ
lefthook install        # pre-push フックを有効化
docker-compose exec backend bundle exec rails db:create db:migrate db:seed
```

## 開発コマンド

```bash
# 起動・停止
docker-compose up -d
docker-compose down

# ルーティング確認
docker-compose exec backend bundle exec rails routes

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

# フロントエンド 型チェック + ビルド確認（CIと同じ。vue-tsc -b → vite build）
cd frontend && npm run build
```

- 型チェックは `npm run typecheck`（`vue-tsc -b`。`npm run build` にも含まれる）。ルートの `tsconfig.json` は `files: []` + project references のため、`vue-tsc --noEmit` は何も検査せず常に成功する。`-b` を付けること（lefthook の typecheck も `-b`）

## テスト（バックエンド / Minitest）

`backend/test/` に、認証・権限（Pundit）・点検の承認フロー・点検計画・在庫台帳・点検→トラブル自動作成・資材の型番検索・モデル検証のテストがある。フィクスチャは使わず、`test/support/test_data.rb` のヘルパーでテストごとにデータを作る。CI（`backend_test`）でも実行される。

```bash
# 初回・スキーマ変更時: テスト用DBを作り直す（db:prepare は新規DBにシードを投入するので使わない）
T=postgres://manage:manage_password@db:5432/manage_test
docker-compose exec -e DATABASE_URL=$T -e RAILS_ENV=test backend bash -c 'bin/rails db:drop db:create db:schema:load'

# 実行
docker-compose exec -e DATABASE_URL=$T backend bin/rails test
```

- コンテナの `DATABASE_URL` は開発DBを指しているため、必ず上記のように `manage_test` を指定して実行する。`*_test` 以外のDBに接続している場合は `test/test_helper.rb` が中断する（開発DBの誤初期化防止）
- 認証まわりなど重要な修正では、修正を一時的に戻してテストが失敗することを確認する（devise 5.0.4 のログアウト500はこの方法でテストが検出できることを確認済み）

## E2Eテスト（Playwright）

`e2e/` に、ブラウザ経由のスモークテストがある（認証、主要画面の遷移と権限、ロール別（自社/協力会社 × マネージャー/作業員）のメニューと操作ボタンの出し分け、一覧の拠点スコープ（自拠点が初期値・複数選択・協力会社は切替不可）と複数選択の絞り込み、点検で不具合報告 → トラブル自動登録、点検の承認ボタンの出し分け、点検計画の期限超過表示）。テスト中に未捕捉のJS例外・API 5xxが出ていないことも全テストで検証する（`e2e/tests/support.ts`）。CI（`e2e` ジョブ）では、ビルド済みフロント（`vite preview`）+ APIサーバー + シード済みDBに対して実行する。

```bash
# 初回のみ（ホストのNodeで実行。docker-compose up 済みが前提）
cd e2e && npm install && npx playwright install chromium

# ローカル（http://localhost:5173）に対して実行
npx playwright test

# stgに対して実行（本番のデモ環境は設定で拒否される）。無料プランでAPIがスリープしていると起動に1分近くかかるため、先に起こしておく
curl -s -o /dev/null -m 120 https://plant-keeper-api-stg.onrender.com/up
E2E_BASE_URL=https://plant-keeper-web-stg.onrender.com npx playwright test
```

- シードのデモアカウントに依存する（`backend/db/seeds`）。点検のテストは実行のたびに点検とトラブル（タイトルが `E2E ` で始まる）を1件ずつ追加するため、繰り返し実行すると一覧に溜まる。ローカルは `db:seed:replant`、stg は管理者の `admin/reseed` で戻せる
- トラブル一覧の行クリックは初期表示の再描画で空振りすることがあるため、詳細画面へは `openFirstTrouble()` を使う（遷移までリトライし、到達も検証する）
- 承認・点検計画のテストは、提出・承認まではせず画面の出し分けと遷移までを確認する（提出すると計画の期限が進み、シードの状態が変わって再実行できなくなるため）
- ログアウトするテストは専用アカウント（`ACCOUNTS.logout`）を使う（ログアウトの副作用を他のテストから切り離すため。トークンは端末ごとに失効するので、共有しても巻き込みはしない）
- ローカルの `vite dev` は、再起動後の初回アクセスで依存の再最適化とリロードが走り、初回だけ失敗することがある（`retries: 1` で吸収）。CI は `vite preview` のため影響しない
- Vuetify の `v-select` は入力要素が覆われているため、`selectFirstOption()`（入力欄 `.v-field` を操作）を使う
- 自社/協力会社によるメニュー表示・ルートガードは、ログインAPIが返す `user.company` に依存する。`UserSerializer` から `company` を外すと全員が「協力会社扱い」になり在庫管理メニューなどが消える（過去に実際に発生。`navigation.spec.ts` の「自社所属のユーザには…」が検出する）

## アクセスURL（開発用）

- フロントエンド: http://localhost:5173
- バックエンドAPI: http://localhost:3000/api/v1

## ログイン情報（開発用）

- 自社 システム管理者(admin): admin@example.com / password
- 自社 業務管理者(manager): suzuki@example.com / password
- 自社 一般(member): sato@example.com / password
- 協力会社 業務管理者(manager): yoshida@example.com / password
- 協力会社 技能員(worker): honda@example.com / password

ログイン画面のデモアカウント一覧（`GET /demo_accounts`）は、上の**権限ごとに1人ずつの5人だけ**を返す（`DemoController::DEMO_ACCOUNT_EMAILS`。所属拠点 `site_name` も返し、名前の横に表示する）。シードのユーザ（数十人）は点検の実施者や設備担当など、データの整合のために残してあり、減らしていない。

## デプロイ（Render）

- 設定ファイル: `render.yaml`（Blueprint）。本番・stg の両サービスをこの1ファイルで定義
- 無料プランのため、アクセスが一定時間ない場合スリープする（初回アクセス時に起動待ちで数十秒かかることがある）
- `admin/reseed`（管理者によるデモデータの全削除→再投入）は環境変数 `ALLOW_DEMO_RESEED=true` のサーバでだけ動く。`render.yaml` で stg のAPIにだけ設定しており、**本番は既定で無効**（デモ管理者のパスワードが公開されているため、誰でも本番の全データを消せる状態にしない）。本番で必要なときだけRenderダッシュボードで一時的に設定する
- stg（Neon）の reseed は完了まで**約4分**かかり、リクエスト自体はタイムアウトするがサーバ側の処理は続く。**リトライしない**（二重実行になる）。API（例: `inspection_plans` の件数）でデータが揃うのを待つ

### ブランチ運用
- `develop` に push → stg に自動デプロイ。動作確認後、`develop` → `main` の PR をマージして本番リリース
- `main` に push/マージすると即本番に自動デプロイされる（GitHub連携によるauto-deploy）。直接 push しない
- 依存関係の更新は Renovate（`.github/renovate.json5`）。更新PRは `develop` 向け。設定ファイル自体は既定ブランチ `main` から読まれる
  - patch: 公開3日後、CI成功で `develop` へ自動マージ（`main` へのリリースは手動PR）
  - minor: PR作成のみ（手動マージ）。major: Dependency Dashboard（Issue）で承認してからPR作成
  - 更新は stg で動作確認してから `main` へ
- 認証まわり（devise / jwt / warden-jwt_auth / rack 等）の更新では、ログインだけでなく「認証付きAPI → ログアウト（204）→ 失効済みトークンの再利用（401）」まで確認する。バックエンドのテスト（`test/integration/authentication_test.rb`）がこれを検証するが、フロント経由の動作は別途 stg で確認する
  - 実例: devise 5.0.4 で `respond_to_on_destroy` がキーワード引数付きで呼ばれるようになり、`SessionsController` のオーバーライドが ArgumentError → ログアウトが500になりJWTが失効しなかった（`respond_to_on_destroy(**)` で修正）
- CI（`.github/workflows/ci.yml`）は PR と `main`/`develop` への push で実行。ジョブは5つ:
  - `backend_scan_ruby`（Brakeman）/ `backend_lint`（RuboCop）
  - `backend_test`（Minitest。Postgres 16 のサービスコンテナ）
  - `e2e`（Playwright。シード済みDB + APIサーバー + ビルド済みフロントの `vite preview`。失敗時はレポートを artifact に保存）
  - `frontend_lint_and_build`（ESLint + `npm run build`）
  - Renovate の自動マージ（patch）もこれらの成功が条件になるため、テストが赤いと依存更新も止まる

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
- `データモデル設計.md` — 29テーブルのER図・テーブル定義・簡易化メモ
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
- 認証: devise-jwt、トークンは Authorization ヘッダーで送受信。Devise は `database_authenticatable` / `validatable` / `jwt_authenticatable` のみ（自己登録・パスワード再設定は使わない。エンドポイントも無い）。ログイン成功は監査ログ（`login`）に記録される
- JWT revocation: `Denylist` 戦略（`jwt_denylists` テーブル。モデルは `JwtDenylist`）。ログアウトしたトークン（jti）だけを失効させるので、**同じユーザが複数の端末でログインでき、片方でログアウトしても他方は使い続けられる**。失効のたびに期限切れの記録を掃除する。`users.jti` は使わなくなった（切り替え中の互換のためカラムは残してあり、NULL可。削除は次のリリース）
- JWT の有効期限は24時間で、リフレッシュはない。トークンを発行するのはログインだけ（`dispatch_requests` がログインのみ）
- 認可: Pundit（`BaseController` に `include Pundit::Authorization`）。各モデルに対応するポリシーファイルあり（`app/policies/`）。`ApplicationPolicy` のヘルパー: `admin?`、`owner_manager?`、`owner_company?`
  - `BaseController` は `after_action :verify_authorized` を持つ。**新しいアクションで `authorize` を呼び忘れると500になる**（黙って全員に公開されるのを防ぐ。自分自身の情報だけを返す `current_user#show` のみ `skip_after_action`）。ログイン前のデモアカウント一覧（`demo#accounts`）は `BaseController` を継承しない
  - **閲覧の制限（画面とAPI単位）**: 協力会社（業務管理者・技能員）は、拠点の一覧・詳細（`SitePolicy#index?/show?`）とユーザ一覧（`UserPolicy#index?`）を見られない（403。メニューにも出ず、`/sites` を直接開いてもダッシュボードに戻される）。ほかに、資材は技能員不可、在庫は自社のみ、発注・修理は自社のマネージャー以上、といった既存の制限がある
  - 自分の所属拠点は、協力会社にも分かるようにヘッダー右上に表示する（`UserSerializer` が `site: { id, name }` を返す）。拠点の一覧を見られない協力会社の画面（ダッシュボード・設備台帳・装置計器）は、拠点の選択欄を出さず、所属拠点で固定する。ユーザ一覧を見られない協力会社のトラブル編集は、担当者の選択欄を出さない
  - `policy_scope` を使っているのは users のみ（一覧の許可を緩めても、協力会社には自社メンバーだけを返す多重防御）。それ以外の一覧は拠点・会社での**行の絞り込み**をしていない（APIでは他拠点のデータも取得できる。画面の拠点は初期値と選択欄の有無で絞っているだけ）
  - users の一覧は、メールアドレスは管理者と自社ユーザのみ、出身県・前職・入社年・退職日は管理者のみに返す（`UserPolicy#view_email?` / `view_profile_details?`）
  - ダッシュボードは `DashboardPolicy` で、在庫アラート・発注・修理のセクションを、それぞれの一覧を見られる人にだけ返す（権限のない人にはキー自体を含めない。フロントは存在チェックで出し分ける）
- 監査ログ: `BaseController#record_audit_log(action, resource, changes: nil)` ヘルパーで統一記録（既定は `resource.saved_changes` を `changes_json` に保存。削除のように `saved_changes` が空になる操作では `changes:` で削除時点の属性を渡す）。ログイン（`login`）、承認依頼（`approval_request`）、点検項目の追加・変更・削除も記録する
- レスポンス: `{ data: ... }` 形式

**シリアライズの使い分け:**
- `UserSerializer`（PORO）: 認証系レスポンスのみ（`POST /login`、`GET /current_user`）。基本はIDのみで、`company`（`id`・`name`・`company_type`）だけネストして返す。フロントの自社/協力会社の判定（`isOwnerCompany` など）とヘッダーの会社名が `user.company` を参照するため。departmentのネストはなし
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
- 認可: `composables/usePermissions.ts` — バックエンドの Pundit ポリシーに対応した computed プロパティ群。判定の本体は純関数 `permissionsFor(role, companyType)` で、権限マトリクス（トップページ・ログイン画面の `PermissionMatrix.vue`）も同じ関数から「できる/できない」を求める（`constants/permissionMatrix.ts`）。判定を変えたら E2E `permission-matrix.spec.ts` が、マトリクスと実際のメニュー・バックエンドの一覧API（200/403）との食い違いを検出する。あわせて、権限ごとにメニューの全画面を開き、制限したAPIを呼んで403になる画面（未捕捉の例外）がないことも確かめる。`canManageCore = isAdmin || isOwnerManager` が共通パターン。SideNavのメニュー表示制御と各ビュー内のボタン表示制御の両方で使用
- 画面パターン: `*ListView.vue`（一覧+フィルタ） + `*DetailView.vue`（詳細+編集ダイアログ）
- UIパターン: カスケードセレクト（拠点→部→課→チーム）に `initializing` フラグで watch 連鎖抑制
- 拠点スコープ（拠点に属するデータの一覧すべて: ダッシュボード・設備台帳・装置計器・点検計画・点検・作業記録・トラブル管理・定期整備・在庫管理・修理管理）: 日常は自拠点だけ見れば足りるため、初期値は所属拠点（`user.site_id`）で、部署は絞らない。表示する拠点は絞り込み項目と分けて、絞り込みの行の左端に `components/SiteScopeTag.vue`（銘板風のタグ）を置く。**拠点は複数選択で、空は全拠点**（メニューに「所属拠点だけ」「全拠点」のボタンがある）。全拠点にすると拠点をまたいで見られる。協力会社は拠点の一覧を見られないため、切替なしで所属拠点の表示のみ。設備・部署・倉庫の選択肢は `composables/useSiteScopeOptions.ts` などで表示する拠点の分だけ取得し、拠点を変えたら、表示しない拠点の設備・部署・倉庫の絞り込みは外す。点検フォームの設備・部署も同じ考え方で所属拠点の分だけ出し、別拠点の設備の点検（編集・点検計画からの実施）を開いたときはその設備の拠点に切り替える
- 絞り込みの複数選択: 設備・種別・ステータス・優先度・倉庫は `components/FilterSelect.vue`（未選択は絞り込まない。選んだ項目は先頭1つ＋「ほか N」で表示。選択肢が多いものは `searchable`）。部署だけは単一選択。ダッシュボードのカード・リンクから一覧を開くときは、表示中の拠点（`?site_ids=1,2`。全拠点は `site_ids=all`、クエリなしは自拠点）と絞り込み（`?status=open,in_progress` `?priority=critical` など）をURLのクエリで引き継ぐ（変換は `utils/listQuery.ts`）。カードの数字と、開いた一覧の件数が一致する（E2E `site-scope.spec.ts` が検証）。ダッシュボード自体の拠点は、開き直すと自拠点に戻る
- `InspectionFormView.vue` は `/inspections/new` と `/inspections/:id/edit` で共用
- `orders/` には一覧ビューのみ（詳細ビューなし）

**Axiosインターセプタ:**
- リクエスト: localStorageから `jwt` を読みAuthorizationヘッダーにセット
- レスポンス: バックエンドが `Authorization` ヘッダーを返した場合、localStorageの `jwt` を上書きする。ただし現状トークンを発行するのはログインだけなので、実質ログイン時にしか動かない（ローテーションはしていない）。トークン付きのリクエストが401になったとき（24時間の有効期限切れ・失効）は、トークンを消して `/login?expired=1` に遷移し、ログイン画面に理由を表示する（同時に飛んでいた他のリクエストは保留にして、未捕捉の例外や失敗表示を出さない）。ログイン自体の401（パスワード違い）は対象外

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

### 業務ルール（実装済みの不変条件）
- **点検の承認フロー**: `draft ⇄ submitted → approval_requested → approved`（承認依頼中からは `submitted` へ差し戻し可）。遷移は `Inspection::STATUS_TRANSITIONS` とモデルの検証で強制する。更新できるのは作成者本人か管理者/マネージャー。承認と差し戻し（承認依頼中から出る操作）は管理者/マネージャーのみ（`InspectionPolicy#approve?`。作成者本人でも自分で差し戻せない）。`approved` は誰も変更できず、承認依頼中は内容（項目含む）を編集できない。新規作成できる状態は `draft` / `submitted` のみ
- **点検計画（`inspection_plans`）**: 設備（計器）ごとの周期と次回期限。点検が `draft` を出たとき（`after_save`）に `next_due_on` を「実施日 + 周期」へ進める。期限の「今日」は `InspectionPlan.today`（日本時間）で判定する。点検の設備と計画の設備は一致しなければならない
- **在庫**: 数量は入出庫・移動（`POST /stock_transactions`）でのみ変更する。在庫行を `lock`（`SELECT ... FOR UPDATE`）してから更新し、DBの CHECK 制約（`quantity >= 0`）でも守る。`PATCH /stocks` は数量・倉庫・資材を変更できず、ステータスは「在庫あり」⇔「使用中」の間だけ直接変えられる（修理中・廃棄済は修理管理・廃棄の入出庫を通す）。新規登録できるのも「在庫あり」「使用中」のみ。在庫を初期数量つきで登録すると、入庫として台帳にも残る。移動先に同じロット（資材・購入日・状態が同じでシリアルなし）があれば数量を足す
- **タグ番号**: `instruments.tag_number` は拠点内で一意（別拠点なら同じ番号があり得る）。モデルで拠点内の一意を検証し、DBの一意制約は設備内のみ

- **タイムゾーン**: アプリは日本時間（`config.time_zone = "Tokyo"`。DBへの保存はUTC）。日時の入力は日本時間として解釈され、返す日時は「+09:00」付き。「今日」「今月」はコード上 `Date.current` / `Time.current`（`Date.today` は使わない）。フロントのフォーム初期値は `utils/datetime.ts`（`nowForInput` / `todayForInput`）を使う（`toISOString()` はUTCなので、日本時間の朝に前日になる）
- **ステータス遷移**: `StatusTransitions` concern で、各モデルの `STATUS_TRANSITIONS` に沿わない更新を拒否する（新規作成時は対象外）。トラブル: 未対応/対応中/解決済/完了（完了からは戻せない。解決済からは再対応＝対応中に戻せる）。修理: 依頼中→発送済→修理中→完了、廃棄は完了前のどこからでも（完了・廃棄からは変更不可）。発注: 下書き→発注済→受領済、キャンセルは受領前のみ。受領済・キャンセルでの新規作成は不可
- **トラブルの解決日時**: `resolved_at` はサーバがステータスから記録する（解決済・完了で初めて記録、再対応で消す）。APIで受け付けない
- **計器と設備の整合**: 点検・トラブル・点検計画の `instrument` は、指定した `equipment` に属するものでなければならない（`InstrumentBelongsToEquipment`）。点検項目の計器は、点検の対象設備の計器でなければならない
- **発注の受領 → 入庫**: 発注を受領済にするには入庫先の倉庫（`orders.warehouse_id`）が必要。受領すると、同じロット（資材・倉庫・受領日が同じ）に数量を足すか新しい在庫を作り、入庫を台帳と監査ログに残す（トランザクション内。二重受領しないよう発注の行を `lock!` する）。受領済の発注は数量・資材・入庫先・受領日を変更できない（単価・備考は可）
- **修理**: 修理に出せるのは在庫あり・使用中で数量1以上の在庫のみ。修理は1個ずつで、数量2以上のロットからは1個を別行に切り出して修理の対象にする（残りは使える状態のまま）。修理の状態変更と在庫の状態変更は同一トランザクション（修理の行を `lock!`）。修理は依頼中でしか新規作成できず、更新で修理対象の在庫（`stock_id`）は変えられない

### 簡易実装方針
- 承認フロー: UIのみ（ボタンでステータス変更、ロジックなし）
- 価格履歴: orders テーブルで兼用
- 使用資材記録: テキストカラム（trouble_responses.used_materials 等）
- 監査ログ出力: CSV のみ
- 発注アラート: ダッシュボードにリスト表示のみ（メール通知なし）
- ダッシュボードの在庫アラート: `Material#select` ブロック内で `stocks.sum(:quantity)` を呼ぶため、対象資材数によってN+1が発生（現状のデータ規模では許容）

### バックエンドの規約
- レスポンス形式: 成功 `{ data: ... }`、エラー `{ errors: [...] }`
- ページネーション: `page`/`per_page` パラメータ（`BaseController#pagination_params`。page は1以上、per_page は1〜1000に丸める）→ `{ data: [...], meta: { total_count, page, per_page } }`。ページネーションなしのエンドポイントもあり（users, departments, checklist_templates）
- フィルタリング: コントローラ内で `if params[:x].present?` チェーンで実装。拠点・設備・種別・ステータス・優先度などの複数選択は `BaseController#id_list_param` / `value_list_param`（`site_ids[]=1&site_ids[]=2` の複数指定と、従来の単一指定 `site_id=1` のどちらも受け付ける。指定なしは絞り込まない）。拠点は、設備の拠点（在庫・修理は倉庫の拠点）で絞る。パラメータ名は複数形（`site_ids` `equipment_ids` `statuses` `priorities` `inspection_types` `warehouse_ids`）
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

## API認証の動作確認（curl）

```bash
# ログイン — Authorization ヘッダーでトークンが返る
curl -D - -X POST http://localhost:3000/api/v1/login \
  -H 'Content-Type: application/json' \
  -d '{"user":{"email":"admin@example.com","password":"password"}}'

# 認証付きAPI / ログアウト
curl http://localhost:3000/api/v1/dashboard -H 'Authorization: Bearer <token>'
curl -X DELETE http://localhost:3000/api/v1/logout -H 'Authorization: Bearer <token>'
```

## トラブルシューティング

- **HMRが効かない**: Docker + macOS のため `vite.config.ts` で `usePolling: true` 設定済み。それでも反映されなければ `docker-compose restart frontend`
- **デモアカウントを増やしたい**: `DemoController::DEMO_ACCOUNT_EMAILS` に足す。権限マトリクスは5つの権限（`frontend/src/constants/permissionMatrix.ts` の `MATRIX_ROLES`）が前提なので、権限の組み合わせを増やすときはそちらも直す
- **APIが401**: JWTの有効期限切れ（24時間）。画面ではログイン画面に戻る。再ログインする
- **マイグレーションがずれた（開発DBのみ）**: `db:migrate:reset` → `db:seed`。接続先が開発DBであることを確認してから実行する
- **backendが起動しない**: puma のPIDファイル残り。`docker-compose.yml` の command で `rm -f tmp/pids/server.pid` 済みだが、解消しなければ `docker-compose down` → `up -d`

## 注意事項

- GitHub公開リポジトリ。ポートフォリオ関連の文言をコードやドキュメントに書かない
- 日本語でコミュニケーション
- テストはバックエンド（Minitest、下記「テスト」）とE2E（Playwright、下記「E2Eテスト」）。フロントの単体テストは未導入
- `equipment` は Rails で不可算名詞扱い。`config/initializers/inflections.rb` で `irregular "equipment", "equipments"` を定義済み
- JWT認証: ログイン POST /api/v1/login、ログアウト DELETE /api/v1/logout
- pre-push フック（lefthook）: ESLint → vue-tsc（`-b`）→ RuboCop が直列実行（`docker-compose exec -T` 経由）

## 既知の制約（未対応）

設計レビューで挙がったもののうち、意図的に未対応のもの。手を入れるときはここを更新する。

- トークンはlocalStorage保管（XSSで盗まれうる）で、リフレッシュ（有効期限の延長）はない。24時間で再ログインになる
- オフライン入力に対応していない（通信が切れると入力中の点検が失われる）
- 添付ファイル（ActiveStorage）は `:local` で、Renderの無料プランは再デプロイ・スリープでファイルが消える
- 拠点・会社によるデータの**行の絞り込み**（policy_scope）は users のみ。協力会社でも、APIでは他拠点の設備・点検などを取得できる（拠点の一覧・詳細とユーザ一覧を見られないだけ）
- 在庫の修理は1個ずつ。使用資材はテキストで、出庫がトラブルや整備に紐づかない
- 計測値は文字列で、単位・許容値・判定を持たない。配管・作業指示（Work Order）のエンティティはない
- 発注点は資材マスタに1つ（全拠点共通）で、在庫は拠点別のため、ダッシュボードで拠点を絞ったときのアラートは「その拠点の在庫 vs 全社の発注点」になる
- `users.jti` カラムが残っている（使っていない。次のリリースで削除する）
