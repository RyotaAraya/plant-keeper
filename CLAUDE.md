# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

PlantKeeper — 石油プラントの保全業務を統合管理するWebアプリケーション。
計装保全の実務経験をベースにしたドメイン特化設計。

## 技術スタック

UIの配色・部品・レスポンシブの共通方針は [デザインガイド.md](デザインガイド.md) を参照（2026-09-21刷新）。

- フロントエンド: Vue 3 + TypeScript + Vuetify 3 (日本語ロケール) + Pinia + Vue Router 4 + Axios
- バックエンド: Rails 8 API mode + devise + devise-jwt
- DB: PostgreSQL 16
- インフラ: Docker（docker-compose、3コンテナ構成）。デプロイ先は Render（本番・stg）、stg のDBのみ Neon
- テスト: バックエンド Minitest、E2E Playwright（フロントの単体テストは未導入）
- CI/CD・依存更新: GitHub Actions、Renovate（Dependabot は使わない。脆弱性アラートは GitHub 側の Dependabot alerts を参照）
- AI: Claude API（`anthropic` gem。不具合報告の整理・類似トラブルの提示・対応記録の整理。既定モデルは Haiku 4.5）。キー未設定の環境では機能ごと無効で、他の機能は変わらない

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

`backend/test/` に、認証・権限（Pundit）・点検の承認フロー・点検計画・在庫台帳・点検→トラブル自動作成・AI支援（`ai_defect_drafts_test.rb`・`ai_similar_troubles_test.rb`・`ai_response_drafts_test.rb`。AIのAPIは呼ばず、`AiClient.override` でスタブに差し替える。スタブと環境変数の準備は `test/support/ai_test_support.rb`）・校正の傾向（`calibration_trend_test.rb`。5点校正の記録を古い順に並べた調整前・調整後の最大誤差と、過去の校正記録のデモ用データの読みの計算が `CalibrationSheet` と一致すること）・周期の見直しの候補（`calibration_interval_review_test.rb`。延長・短縮のルール、法令の計器は延長しない、インターロックの注意、周期を変えたあとは同じ候補を出さない、絞り込み）・インターロックのバイパス（`interlock_bypasses_test.rb`。申請 → 承認 → 実施 → 復帰 → 復帰確認の流れ、申請した本人は承認できない・復帰した本人は確認できない、復帰期限超過）・機器の自己診断の受け口（`device_diagnostics_test.rb`。状態が変わったときだけ履歴を増やす、古い日時は反映しない・未来の日時は誤り、1件ずつの結果と誤り、トークンの拠点の計器だけ、トークンなし・失効・ユーザのJWTは401、トークンの発行・失効は管理者だけで平文は発行時だけ・監査ログに値を残さない、計器の一覧の絞り込みと詳細の履歴）・点検のまとまり（`inspection_plan_groups_test.rb`。まとまりを指定しない計画の入れ先、基準器の校正のまとまり、違う拠点のまとまりの拒否、作成・変更の権限と監査ログ、計画の一覧の絞り込み。移行は `inspection_plan_groups_migration_test.rb`）・ホーム（`home_board_test.rb`。エリアがチーム → 課 → 部の順で、点検計画・作業・トラブルはその部署に直接割り当てたものだけ、期限超過・今日・明日、バイパスは拠点全体、承認待ちは自社の管理者・マネージャーだけ、運転員の自分の報告、協力会社・別の拠点は拠点全体の1エリアで協力会社は拠点を選べない、夕会の実績のエリア分け）・資材の型番検索・モデル検証のテストがある。フィクスチャは使わず、`test/support/test_data.rb` のヘルパーでテストごとにデータを作る。CI（`backend_test`）でも実行される。

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

`e2e/` に、ブラウザ経由のスモークテストがある（認証、主要画面の遷移と権限、ロール別（自社/協力会社 × マネージャー/作業員）のメニューと操作ボタンの出し分け、一覧の拠点スコープ（自拠点が初期値・複数選択・協力会社は切替不可）と複数選択の絞り込み、点検で不具合報告 → トラブル自動登録、点検の承認ボタンの出し分け、点検計画の期限超過表示、設備の適用法規（法規区分の表示・色・選択欄・法定検査の周期）の表示、計器の校正条件と5点校正の入力・合否の表示、計器の「校正の傾向」（FT-301 の調整前の最大誤差の推移と各回の結果）、点検計画のまとまり（法規区分・まとまりでの絞り込み、業務管理者がまとまりを選んで計画を追加すると既定の周期が入る。追加した `E2E ` で始まる計画は最後に無効にする）、「計画」画面（`plans.spec.ts`。まとまりを開くと計器ごとの周期と「点検を実施」、系列を開くと各回と回の詳細、法規区分で絞ると定期整備を出さないこと、旧URLの転送、業務管理者のまとまりの追加・編集。追加した `E2E ` で始まるまとまりは最後に無効にする）、点検計画の周期の見直しの候補（一般ユーザは根拠だけ、業務管理者は周期を変えられる。変える操作は、実行のたびにAPIで作る `E2E ` で始まるPT-701の計画で行い、最後に無効にする）、基準器の台帳・校正の状態・点検での基準器の選択と提出時の拒否、チェックリストの機器 × 周期の構成と廃止したテンプレートが選択肢に出ないこと、複数設備の定期整備を作って検収を記録し完了まで進める流れ、系列に登録して次回を作ると周期が来た設備だけが対象になること、計器を一括追加して作業から点検を実施すると完了になり未完了の作業がある間は検収へ進めないこと、トラブルを定期整備に回すと定修待ちになり作業の完了・見送りに連動すること、シードのデモ（A号ボイラー整備の系列）の表示、不具合報告のAI下書き（`ai-defect-draft.spec.ts`）の作成・反映・保存時の提案IDの送信、類似トラブルの提示（`ai-similar-troubles.spec.ts`。トラブル詳細と点検フォーム）、対応記録のAI下書き（`ai-response-draft.spec.ts`）の作成・反映・保存時の提案IDの送信、設備を変えたときの下書きの消去と、下書きを作っている間に設備を変えたときの古い応答の破棄（`ai-defect-draft.spec.ts`）、インターロックのバイパス（`interlocks.spec.ts`。ダッシュボード・台帳で復帰期限超過が目立つこと、申請 → 承認 → 実施 → 復帰 → 別の人の確認で完了する流れと本人にボタンが出ないこと。実行のたびに I-752 に完了のバイパス（理由が `E2E ` で始まる）を1件ずつ追加し、始める前に終わっていないバイパスをAPIで片付ける。対象設備にバイパスが残っている定期整備は検収へ進めないこと（シードの I-701 を使い、ボイラー設備の定期整備を1件作る））。検収まで進める定期整備のE2E（`maintenances.spec.ts`・`maintenance-tasks.spec.ts`）は、デモのバイパスが残るボイラー設備・発電設備を使わず、インターロックのない設備（接触改質装置・減圧蒸留装置・流動接触分解装置）で行う、詳細画面の変更履歴が日本語のラベル・呼び方で出てカラム名・IDが出ないこと（`resource-history.spec.ts`。実行のたびに、APIで `E2E ` で始まるトラブルを1件作る）、機器の自己診断（`device-diagnostics.spec.ts`。管理者が外部連携の画面でトークンを発行し、試しに送ると計器の一覧・詳細に出て、失効したトークンは401。診断はシードの計器を変えないよう、E2E 専用の計器 `E2E-DIAG`（なければAPIで作る）に送り、最後に正常に戻してトークンを失効する。一般ユーザは外部連携を開けない）、ホーム（`home-todo.spec.ts`。ログインするとホームが開き、バイパス → チーム → 課 → 部のエリアが並ぶこと、課のまとまりの計画が課のエリアにだけ出て点検へ進めること、自分が報告した緊急のトラブルがチームのエリアの先頭側に出ること、作業は作業の部署のエリアにだけ出ること、マネージャーの承認待ち、運転員の不具合報告のボタン、協力会社の拠点全体の1エリア、旧URLの転送、夕会の実績と積み残し、印刷ボタンと印刷のレイアウト（`emulateMedia('print')` とA4の幅で、メニュー・操作ボタンを出さず横にはみ出さない）。確かめる計画・トラブル・定期整備は、実行のたびにAPIで `E2E ` で始まるものを作り、最後に無効・完了にする（夕会の点検は消せないため、`E2E ` で始まる備考の提出済みの点検が1件ずつ残る）。シードのデモは相対日付のため件数を決め打ちしない））。テスト中に未捕捉のJS例外・API 5xxが出ていないことも全テストで検証する（`e2e/tests/support.ts`）。CI（`e2e` ジョブ）では、ビルド済みフロント（`vite preview`）+ APIサーバー + シード済みDBに対して、**2つのジョブに分けて**（`--shard=1/2`・`2/2`。別のマシン）実行する（1台の中で並列にしても、ランナーのCPUを取り合って短くならなかった）。テストは並列で流れる前提で書く（ほかのテストのデータの件数・順番に依存しない。データを変えるテストは自分用のデータを作る）。

```bash
# 初回のみ（ホストのNodeで実行。docker-compose up 済みが前提）
cd e2e && npm install && npx playwright install chromium

# ローカル（http://localhost:5173）に対して実行
npx playwright test

# stgに対して実行（本番のデモ環境は設定で拒否される）。無料プランでAPIがスリープしていると起動に1分近くかかるため、先に起こしておく
curl -s -o /dev/null -m 120 https://plant-keeper-api-stg.onrender.com/up
E2E_BASE_URL=https://plant-keeper-web-stg.onrender.com npx playwright test
```

- **AI支援のE2Eは、本物のAPIを呼ばない**。バックエンドが `AI_PROVIDER=fake`（APIを呼ばないダミー）のときだけ実行し、本物のAI（キーあり。stg など）や無効（キーなし）ではスキップする（判定は `GET /ai/status` の `provider`）。判定は `support.ts` の `requireFakeAi(provider)`（AIのE2Eはこれを使う）。CI は `ci.yml` の「Start API」で fake にしてあり、fake でなければ失敗にして黙ってスキップされるのを防ぐ。`ai-response-draft.spec.ts` は実行のたびに、シードのトラブル「FT-301 オリフィス閉塞疑い」に対応記録（内容が `E2E ` で始まる）を1件ずつ追加する（類似トラブルのE2Eは何も保存しない）。ローカルで実行するには `AI_PROVIDER=fake docker-compose up -d backend`
- シードのデモアカウントに依存する（`backend/db/seeds`）。点検のテストは実行のたびに点検とトラブル（タイトルが `E2E ` で始まる）を1件ずつ追加するため、繰り返し実行すると一覧に溜まる。ローカルは `db:seed:replant`、stg は管理者の `admin/reseed` で戻せる
- トラブル一覧の行クリックは初期表示の再描画で空振りすることがあるため、詳細画面へは `openFirstTrouble()` を使う（遷移までリトライし、到達も検証する）
- 承認・点検計画のテストは、提出・承認まではせず画面の出し分けと遷移までを確認する（提出すると計画の期限が進み、シードの状態が変わって再実行できなくなるため）
- ログアウトするテストは専用アカウント（`ACCOUNTS.logout`）を使う（ログアウトの副作用を他のテストから切り離すため。トークンは端末ごとに失効するので、共有しても巻き込みはしない）
- テストの「今日」（`todayForInput()` など。テストを動かすNodeのローカル時間を使う）は、`playwright.config.ts` の `process.env.TZ = 'Asia/Tokyo'` でアプリと同じ日本時間にしている。CI（GitHub Actions）はUTCのため、これがないと日本時間の0〜9時（UTCでは前日）に、アプリが記録する日付とずれて失敗する（再現は `TZ=UTC npx playwright test`。`use.timezoneId` はブラウザだけで、Node側には効かない）
- ローカルの `vite dev` は、再起動後の初回アクセスで依存の再最適化とリロードが走り、初回だけ失敗することがある（`retries: 1` で吸収）。CI は `vite preview` のため影響しない
- Vuetify の `v-select` は入力要素が覆われているため、`selectFirstOption()` / `selectOption()`（`support.ts`。入力欄 `.v-field` を操作し、選んだあとに Escape でメニューを閉じる。複数選択のメニューは選んでも開いたままで、次の操作を邪魔するため。名前が他の選択肢に含まれるとき（「巡回点検」と「根岸 巡回点検」）は `{ exact: true }`）を使う
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
- 自社 一般・製造部の運転員（ホームが運転員向けになる）: shimizu@example.com / password

ログイン画面のデモアカウント一覧（`GET /demo_accounts`）は、上の**権限ごとに1人ずつの5人と、末尾に運転員の1人**を返す（`DemoController::DEMO_ACCOUNT_EMAILS`。所属拠点 `site_name` も返し、名前の横に表示する）。シードのユーザ（数十人）は点検の実施者や設備担当など、データの整合のために残してあり、減らしていない。

## デプロイ（Render）

- 設定ファイル: `render.yaml`（Blueprint）。本番・stg の両サービスをこの1ファイルで定義
- タブの favicon は環境ごとに色を変えている（本番=ネイビー `favicon.svg`・stg=橙 `favicon-stg.svg`・ローカルなど未設定=緑 `favicon-dev.svg`）。ビルド時の `VITE_APP_ENV`（`render.yaml` で `production` / `stg`）を見て、`vite.config.ts` が `index.html` の href を差し替える。3つとも `frontend/public/` にあり、どの環境にも配信される（E2E の `resetSession` は、アプリを起動しない静的ファイルとして `/favicon.svg` を開く）
- 無料プランのため、アクセスが一定時間ない場合スリープする（初回アクセス時に起動待ちで数十秒かかることがある）
- `admin/reseed`（管理者によるデモデータの全削除→再投入）は環境変数 `ALLOW_DEMO_RESEED=true` のサーバでだけ動く。`render.yaml` で stg のAPIにだけ設定しており、**本番は既定で無効**（デモ管理者のパスワードが公開されているため、誰でも本番の全データを消せる状態にしない）。本番で必要なときだけRenderダッシュボードで一時的に設定する
- 再投入は数分（stgのNeonで約4分）かかるため、**非同期**: `POST /admin/reseed` はバックグラウンドのスレッドで始めて202ですぐ返し（`DemoReseed`。実行中の再実行は409）、状態（idle/running/succeeded/failed）は `GET /admin/reseed` で返す。**状態の確認はログイン不要**（再投入中は users も空になり、認証が通らないため。返すのは状態だけ）。状態はプロセス内に持つので、実行中にサーバが再起動すると失われる（画面は失敗として扱う）。**stgへデプロイ（developへのpush）すると、実行中の再投入は止まる**。**画面は `/settings/reseed`（管理者のみ）で、設定画面・メニューにはリンクを出さない**（危険な操作を目につく場所に置かないため。画面を隠すだけでは防御にならず、サーバ側の `ALLOW_DEMO_RESEED` が本体）。`ALLOW_DEMO_RESEED` が無効なサーバでは、実行の操作を出さず無効である旨を案内する。実行中は進捗を出して閉じても続き、完了・失敗をページに表示する。再実行を押してしまう心配はない

### ブランチ運用
- `develop` に push → stg に自動デプロイ。動作確認後、`develop` → `main` の PR をマージして本番リリース
  - `develop` → `main` の PR は `.github/workflows/release-pr.yml` が自動で作る（`develop` への push のたびに、開いている PR がなければ作り、あれば本文の変更の一覧を更新する。マージは手動で、**マージコミットで行う**（squash・rebase だと develop のコミットが main の祖先にならず、次のリリース PR に同じ変更が並び続ける）。手動で動かすときは Actions の workflow_dispatch）。リポジトリの設定「Allow GitHub Actions to create and approve pull requests」が必要。リリース PR では pull_request の CI は動かさないが（`ci.yml` の `branches-ignore`）、同じコミットの `develop` への push の CI の結果が PR に出る
- `main` に push/マージすると即本番に自動デプロイされる（GitHub連携によるauto-deploy）。直接 push しない
- 依存関係の更新は Renovate（`.github/renovate.json5`）。更新PRは `develop` 向け。設定ファイル自体は既定ブランチ `main` から読まれる
  - patch: 公開3日後、CI成功で `develop` へ自動マージ（`main` へのリリースは手動PR）
  - minor: PR作成のみ（手動マージ）。major: Dependency Dashboard（Issue）で承認してからPR作成
  - 更新は stg で動作確認してから `main` へ
- 認証まわり（devise / jwt / warden-jwt_auth / rack 等）の更新では、ログインだけでなく「認証付きAPI → ログアウト（204）→ 失効済みトークンの再利用（401）」まで確認する。バックエンドのテスト（`test/integration/authentication_test.rb`）がこれを検証するが、フロント経由の動作は別途 stg で確認する
  - 実例: devise 5.0.4 で `respond_to_on_destroy` がキーワード引数付きで呼ばれるようになり、`SessionsController` のオーバーライドが ArgumentError → ログアウトが500になりJWTが失効しなかった（`respond_to_on_destroy(**)` で修正）
- CI（`.github/workflows/ci.yml`）は PR と `develop` への push で実行。同じコミットで何度も動かさないよう、**main 向けの PR（リリース PR）と `main` への push では動かさない**（main に入るのは develop で CI を通したコミットとマージコミットだけ。リリース PR には develop への push の結果が出る。Render の自動デプロイは CI を待たない）。同じブランチに続けて push すると、古いコミットの CI は止まる（`concurrency`）。ただし、変更が Markdown（`**/*.md`）・`.claude/`・`.agents/` だけのときは動かない（`paths-ignore`。コードから参照している Markdown はない。ブランチ保護で CI を必須のチェックにしていないため、動かなくてもマージは止まらない）。ジョブは5つ:
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
- AI支援を使うには、本番・stg のAPIに環境変数 `ANTHROPIC_API_KEY`（`render.yaml` に `sync: false` で定義済み。ダッシュボードで設定）を入れる。未設定なら点検フォーム・トラブル詳細にAIのボタンは出ない。任意で `AI_MODEL`（既定 `claude-haiku-4-5`）、`AI_DAILY_LIMIT_PER_USER`（既定20）、`AI_DAILY_LIMIT_TOTAL`（既定200）、`AI_ENABLED=false`（キーがあっても止める）。公開デモの費用の濫用を防ぐため、上限は必ず効いている（0以下や数値でない値は既定に戻す）。ローカルは `ANTHROPIC_API_KEY=... docker-compose up -d backend`（`docker-compose.yml` が環境変数を渡す）
- 初回のみシード投入が必要（Render無料プランはシェルが使えないためローカルから実行。`db:migrate` は初回デプロイで実行済みのため `db:seed` のみ）:
  ```bash
  docker-compose exec -e DATABASE_URL='<Neonの接続文字列>' backend bundle exec rails db:seed
  ```
  （`db:seed:replant` は全データ削除のため、接続先を確認してから使うこと）
- pre-push フック（lefthook）を通過すれば push 自体は成功するが、Render側のビルド・デプロイ完了までは別途数分かかる。デプロイ状況はRenderダッシュボードで確認が必要（Claude Codeからは確認不可）

## 設計ドキュメント

- `要求仕様書.md` — 機能要件、業務フロー、設計方針
- `データモデル設計.md` — 48テーブルのER図・テーブル定義・簡易化メモ
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
- `Department#full_path` → "保全部 > 計装保全課 > 計器Aチーム"
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
  - 自分の所属拠点は、協力会社にも分かるようにヘッダー右上のアカウントメニューに表示する（`UserSerializer` が `site: { id, name }` を返す）。拠点の一覧を見られない協力会社の画面（ダッシュボード・設備台帳・装置計器）は、拠点の選択欄を出さず、所属拠点で固定する。ユーザ一覧を見られない協力会社のトラブル編集は、担当者の選択欄を出さない
  - `policy_scope` を使っているのは users のみ（一覧の許可を緩めても、協力会社には自社メンバーだけを返す多重防御）。それ以外の一覧は拠点・会社での**行の絞り込み**をしていない（APIでは他拠点のデータも取得できる。画面の拠点は初期値と選択欄の有無で絞っているだけ）
  - users の一覧は、メールアドレスは管理者と自社ユーザのみ、出身県・前職・入社年・退職日は管理者のみに返す（`UserPolicy#view_email?` / `view_profile_details?`）
  - ダッシュボードAPIは `DashboardPolicy` で、在庫アラート・発注・修理の集計を、それぞれの一覧を見られる人にだけ返す（権限のない人にはキー自体を含めない）。現在の画面では情報量を抑えるため表示しないが、APIは互換性のため維持する
  - 資材の拠点別の在庫も同じ扱い。資材一覧の `stock_by_site`（拠点ごとの使える在庫。自拠点が先頭）と、詳細の `stock_summary` / `total_stock` / `usable_stock`（倉庫ごと・拠点付き）は、在庫を見られる人（自社）にだけ返し、協力会社にはキー自体を含めない。「使える在庫」は利用可（`available`）で数量1以上のもの（使用中・修理中・廃棄済みは数えない）。一覧の `stock_availability=own|others_only|none`（自拠点にあり／他拠点にだけあり／どこにもなし）も在庫を見られる人にだけ効く。資材マスタ自体は全拠点共通で、拠点で絞らない（自拠点になければ他拠点にあるかを、同じ行で探せるのが目的）
- 監査ログ: `BaseController#record_audit_log(action, resource, changes: nil)` ヘルパーで統一記録（既定は `resource.saved_changes` を `changes_json` に保存。削除のように `saved_changes` が空になる操作では `changes:` で削除時点の属性を渡す）。ログイン（`login`）・ログアウト（`logout`。トークンで認証できたときだけ記録）、承認依頼（`approval_request`）、点検項目の追加・変更・削除も記録する
  - 監査ログには変更されたデータの拠点（`audit_logs.site_id`）を持たせる。記録時に `AuditLog.site_id_for(resource)` が対象から求める（設備・点検・トラブルは設備の拠点、在庫・発注・修理は倉庫の拠点、ユーザ・ログインは所属拠点。資材・メーカー・流体などの全社共通マスタは NULL）。**拠点を指定した絞り込みでは NULL のログは出ない**（全拠点＝指定なしのときだけ出る）。対象の種類を増やすときは `site_id_for` にも足す
  - 一覧APIの絞り込み: `site_ids`（複数可）、`from` / `to`（日本時間の日付 `YYYY-MM-DD`。開始日の0時〜終了日の終わり。不正な値は422）、`log_action`、`auditable_type`。画面の初期値は自拠点・直近1か月。並びは新しい順（同時刻は id 降順）
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
- ダッシュボードの画面はホームに吸収した（2026-09-27。`/dashboard` はホームへ転送）。API `GET /dashboard`（`DashboardPolicy`。部署範囲は `Department.subtree_ids`、トラブルの所属判定は `Trouble.for_departments`）は互換のため残し、集計の整合は `dashboard_scope_test.rb` で検証する
- **ホーム（やること）**（`views/home/HomeTodoView.vue`、`/home`、`GET /home`。要求仕様書 2.8。2026-09-27に朝会・夕会ボードとダッシュボードを吸収）: **ログイン後の最初の画面**（`utils/loginDestination.ts`・権限のない画面から戻る先も `/home`。`/dashboard` と `/meeting-board` はホームへ転送し、`?mode=evening` は引き継ぐ）。集めるのは `HomeBoard`（PORO。点検計画・実施中の定期整備の作業・トラブル・インターロックのバイパス）で、新しいテーブルはない。**範囲は本人の所属**で、部署は選べない（拠点だけ、自社の人が選べる。協力会社は所属拠点で固定し、APIも `site_id` を無視する）。**エリアは所属のチーム → 課 → 部の順で、各エリアはその部署に直接割り当てたものだけ**（配下・上位を混ぜない）: 点検計画はまとまりの担当部署（期限超過・今日・明日）、作業は実施中の定期整備の未着手・実施中の作業の部署、トラブルは未対応・対応中で報告者か担当者の所属がその部署（報告者と担当者の部署が違えば、両方のエリアに出る）。部署のない人（協力会社など）と、所属と別の拠点を選んだときは拠点全体の1エリア。エリアの中は種類（点検・作業・トラブル）のラベルつきの1本のリストで、期限超過・緊急 → 今日・高・実施中 → そのほか → 明日の順。**インターロックのバイパスは拠点全体で先頭**（あるときだけ出す）。**役割でホームが変わる**（`HomeBoard#kind`）: 自社の管理者・マネージャーは先頭に承認待ち（承認依頼中の点検・申請中のバイパス）、所属の部署の `department_type` が運転（operation）の人は「不具合を報告する」（点検フォーム `/inspections/new?inspection_type=operation_check`）と自分が報告したトラブル（完了を除く）、そのほかは「やること」だけ。**朝会と夕会は `?mode=evening` で切り替える**（夕会は、エリアごとに今日の実績（点検日が今日で提出した点検・今日の対応記録・今日完了した作業。点検は記録の部署、対応記録は記録した人の所属、作業は作業の部署）と積み残し（下書きのままの点検と、明日の分を除くやること）、明日の予定。提出日時の列はないため、点検日で数える）。**印刷**は、共通の印刷用CSS（`assets/main.css` の `@media print`: メニュー・ヘッダー・`.pk-no-print` を消す、A4）と、ホームの `@media print`（操作・説明を消す、行でページを分けない）。出力した時刻は `beforeprint` で入れる。計画から点検を開くリンクは `utils/inspectionPlan.ts`（「計画」画面と共用）。デモは `db/data/meeting_board.rb`（実施中の「FCC 計器点検（SDW）」と今日・明日が期限の月次点検、夕会の場面＝今日提出したFT-601の点検・下書きのままのLT-601の点検・LT-403の今日の対応記録。日付はシード・`SeedMeetingBoardDemo`・`SeedMeetingBoardEveningDemo` を実行した日から相対）。デモアカウントの運転員は shimizu（製造部 > 第1運転課 > 直A）
- UIパターン: カスケードセレクト（拠点→部→課→チーム）に `initializing` フラグで watch 連鎖抑制
- 拠点スコープ（拠点に属するデータの一覧すべて: 設備台帳・装置計器・点検計画・点検・作業記録・トラブル管理・定期整備・在庫管理・修理管理）: 日常は自拠点だけ見れば足りるため、初期値は所属拠点（`user.site_id`）で、一覧を直接開いたときは部署を絞らない。表示する拠点は絞り込み項目と分けて、絞り込みの行の左端に `components/SiteScopeTag.vue`（淡い青の拠点セレクター）を置く。**拠点は複数選択で、空は全拠点**（メニューに「所属拠点だけ」「全拠点」のボタンがある）。全拠点にすると拠点をまたいで見られる。協力会社は拠点の一覧を見られないため、切替なしで所属拠点の表示のみ。設備・部署・倉庫の選択肢は `composables/useSiteScopeOptions.ts` などで表示する拠点の分だけ取得し、拠点を変えたら、表示しない拠点の設備・部署・倉庫の絞り込みは外す。点検フォームの設備・部署も同じ考え方で所属拠点の分だけ出し、別拠点の設備の点検（編集・点検計画からの実施）を開いたときはその設備の拠点に切り替える。協力会社の点検は `Inspection` の検証でも所属拠点の設備だけに制限し、URLやAPIの直接指定でこの境界を越えられないようにする
- 絞り込みの複数選択: 設備・種別・ステータス・優先度・倉庫は `components/FilterSelect.vue`（未選択は絞り込まない。選んだ項目は先頭1つ＋「ほか N」で表示。選択肢が多いものは `searchable`）。部署だけは単一選択（点検・トラブルは配下を含む）。ダッシュボードのカード・リンクから一覧を開くときは、表示中の拠点（`?site_ids=1,2`。全拠点は `site_ids=all`、クエリなしは自拠点）と絞り込み（`?status=open,in_progress` `?priority=critical` `?department_id=1` など）をURLのクエリで引き継ぐ（変換は `utils/listQuery.ts`）。カードの数字と、開いた一覧の件数が一致する（E2E `site-scope.spec.ts` が検証）。ダッシュボードは、開き直すと自分の所属拠点・部署に戻る
- **機器の自己診断（NAMUR NE 107）**（要求仕様書 2.9）: 受け口 `POST /api/v1/integrations/device_diagnostics`（`Integrations::DeviceDiagnosticsController`）は **`BaseController` を継承せず、ユーザのJWTでは通らない**。ヘッダー `X-Integration-Token` の連携用のトークン（`IntegrationToken`。SHA-256 だけを保存し、平文は発行の応答にだけ入れる。拠点ごと）で認証する。1件ずつの反映は `DeviceDiagnosticIntake`（トークンの拠点のタグ番号で計器を探す。状態・コード・内容がいまと同じなら履歴を増やさず `diagnostic_received_at` だけ更新、いまより古い日時は `stale`、5分を超える未来の日時は誤り）。いまの状態は `instruments.diagnostic_status` 等、変化の記録は `instrument_diagnostics`。状態の呼び方・記号・色は `constants/diagnostics.ts`（バックエンドは `InstrumentDiagnostic::STATUSES`）と `components/DiagnosticChip.vue`。トークンの発行・失効は `/settings/integrations`（管理者。設定画面からリンク）で、監査ログにトークンの値・ダイジェストを残さない。画面の「試しに送る」は、共通の `api`（ユーザのトークンを付け、401でログイン画面へ戻す）を使わず `window.fetch` で受け口へ送る（連携の401でログアウトさせないため）。デモは `db/data/device_diagnostics.rb`（川崎の「AMS Device Manager（川崎）」から、PT-502 保守要求・LT-701 仕様外・TV-602 故障・PV-601 機能点検中ほか。シードと `SeedDeviceDiagnostics` が共有。トークンの平文はない）
- **計器の履歴**（要求仕様書 2.3）: `components/InstrumentHistoryList.vue`（`kind` = `troubles` / `inspections`。既存の一覧API `GET /troubles`・`GET /inspections` の `instrument_id` を使い、新しい順に数件。`excludeTroubleId` で、トラブル詳細から開いたそのトラブル自身を外す）を、トラブル詳細の「この計器の履歴」と計器詳細のトラブル履歴・点検履歴で共用する。「すべて見る」は、その計器で絞り込んだ一覧（`/troubles?instrument_id=..&site_ids=all`、`/inspections?...`）を開き、一覧の上の `components/InstrumentFilterChip.vue`（×で外す）で絞り込みを示す（クエリの変換は `utils/listQuery.ts` の `idFromQuery`）。**`<router-view>` にはキーがなく、同じルートでパラメータ・クエリだけが変わると画面は使い回される**。そのため、トラブル詳細は `route.params.id` を `watch` して読み込み直し（`onMounted` だけでは前のトラブルが表示されたままになる。取得は `latestGuard` で古い応答を捨て、保存後の再取得は `keepContent` で画面を作り直さない）、トラブル一覧・点検一覧は `route.query` を `watch` して、クエリの絞り込み（自拠点・ステータス・優先度・計器）に合わせ直す（計器で絞り込み中にサイドバーから開き直すと外れる）。計器・トラブルへのリンクは `<router-link>`（Ctrl/Cmd-クリックで新しいタブ。一覧の行の中では `@click.stop`）。状態・優先度・点検種別などの呼び方と色は `constants/recordLabels.ts`（トラブル・点検の一覧・詳細、履歴、類似トラブルで共用。新しい画面でも、ここから import する）。E2E は `instrument-history.spec.ts`。トラブル一覧の行の中に計器へのリンクがあるため、E2Eで一覧の行を開くときは、行の端を押す（`openListRow`）
- **変更履歴**（詳細画面の `components/ResourceHistory.vue`。トラブル・定期整備・計器・設備・基準器）: 監査ログの `changes_json`（`{ カラム名: [前, 後] }`）を、`utils/auditChanges.ts` の `formatAuditChanges` で、日本語のラベル・状態の呼び方・日時（日本時間）に変換して出す。**履歴を出す対象にカラムを足したら、`FIELD_LABELS`（と、値に呼び方があれば `STATUS_BY_TYPE` / `VALUE_LABELS`）にも足す**（足さないと、カラム名のまま出る）。ID のカラム（`*_id`）は、作成では出さず、更新では「変更あり」とだけ出す（名前が分からない ID を並べても意味がないため。ID そのものが要る管理者は監査ログの画面で見る。`AuditLogView` はこの変換を使わない）。E2E は `resource-history.spec.ts`
- **プラナ（AIアシスタント）**: AI支援の画面上の名前とキャラクター。**AIの処理・API・データは変えず、見せ方だけ**（ボタン「プラナに整えてもらう」、提案の見出し「プラナが整理しました」「プラナが選んだ候補です」、作業場、サイドバーの入口、公開トップのプラナの節）。「下書き」は初見の人に前提（報告書を書く途中、という文脈）を要求するため、AIが作った内容の見出し・ボタンには使わず、動詞「整える／整理する」で示す（点検・発注の記録状態としての「下書き」＝`draft`ステータスとは別物で、そちらは変えない）。**提案 → 人が確認 → 反映**（AIは自動で確定しない）は、名前が変わっても守る。画像は `assets/plana/plana.webp` の1枚（透過の切り抜き。元の大きな画像はリポジトリに入れない）で、`components/plana/PlanaAvatar.vue` が大きさを使い分ける（`face`＝顔まわりの角丸アイコン。ボタン・提案の見出し・サイドバー・ログイン画面 / `full`＝上半身。公開トップのプラナの節）。提案カードの見出しは `PlanaNote.vue`。色は `main.css` の `--pk-plana-*`（ネイビー・ブルー・水色・橙）で、業務画面の共通配色にも使う（デザインガイド.md）。作業場 `/plana`（`views/plana/PlanaView.vue`。サイドバーの「プラナ」とホームの「プラナを開く」から開く。2026-09-27まではログイン後の初期画面だった）は、仕事（`?task=defect-draft|similar-troubles|response-draft`）を選び、その場で対象を選んで進める: 不具合報告は選んだ設備・計器を点検フォームの不具合欄へ引き継ぎ、類似トラブルはその場で探し、対応記録はトラブルを探して対応記録の入力を開く（技能員には対応記録を出さない）。初期表示ではAIを呼ばず `GET /ai/status` だけ。**チャットではない**（自由な質問に答える入力欄はない。以前の相談欄 `PlanaConsultBar` は、回答しないのに入力させていたため撤去した）。「プラナでできること」は `constants/planaCapabilities.ts`（実装済みだけを載せる。公開トップと作業場が読む。説明は「〜を作成します」「〜を探します」の言い回しにそろえる。設備の履歴の要約・マニュアル検索などを足すときは、ここに足す）。E2E は `plana.spec.ts`・`home.spec.ts`
- `InspectionFormView.vue` は `/inspections/new` と `/inspections/:id/edit` で共用
- `orders/` には一覧ビューのみ（詳細ビューなし）

**Axiosインターセプタ:**
- リクエスト: localStorageから `jwt` を読みAuthorizationヘッダーにセット
- レスポンス: バックエンドが `Authorization` ヘッダーを返した場合、localStorageの `jwt` を上書きする。ただし現状トークンを発行するのはログインだけなので、実質ログイン時にしか動かない（ローテーションはしていない）。トークン付きのリクエストが401になったとき（24時間の有効期限切れ・失効）は、トークンを消して `/login?expired=1` に遷移し、ログイン画面に理由を表示する（同時に飛んでいた他のリクエストは保留にして、未捕捉の例外や失敗表示を出さない）。すでにログイン画面にいるとき（ログアウト直後に返ってきた読み込み中の取得）の401も、同じく保留にする（呼び出し元の未捕捉の例外にしない）。ログイン自体の401（パスワード違い）は対象外

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
- **複数の設備をまとめた点検・点検計画**（巡回など。要求仕様書 2.2）: `equipment_id` は**代表の設備**（先頭に選んだ設備。一覧・拠点の絞り込み・集計・監査ログの拠点はこれで判定）で、対象の設備の全体は中間テーブル（点検は `inspection_equipments`、計画は `inspection_plan_equipments`。代表の設備を必ず含み、同じ拠点だけ。設備が1つでも1行持つ。基準器の校正計画は持たない）。共通の処理は、モデルの `CoversEquipments`（`covered_equipment_ids`・同じ拠点の検証・保存後の同期。含めるクラスが `equipment_links` を定義する）とコントローラの `EquipmentIdsParam`。API は `equipment_ids`（先頭が代表になる）か従来の `equipment_id` を受け付ける。**`*_params` に `equipment_ids` を入れない**（`has_many :equipments` の `equipment_ids=` が、検証なしに直接書き込むため。`apply_equipment_ids` が代表の設備と入力をセットする）。計画は、計器を指定できるのが設備1つのときだけ。計画から点検を開くと、対象の設備すべてを引き継ぐ（画面のクエリ `equipment_ids`）。**計画に基づく点検は、計画の対象設備をすべて含まなければならない**（`Inspection#plan_matches_equipment`。一部だけでは期限が進まないため。確認は、作成時と、計画・設備を変えるときだけで、計画に設備があとから足されても、過去の点検の承認などの更新は止めない）。デモの巡回の計画（川崎・根岸の「製造部 巡回点検」）は、`GroupDemoPatrolPlans` が既存環境をまとめ設備にする。以下は点検について。項目に `equipment_id`（不具合の設備。空は代表の設備）を持ち、トラブルはその設備で作る。点検の計器は代表の設備のものなので、別の設備のトラブルには引き継がない。設備の絞り込みは `inspection_equipments` で行う（代表の設備でなくても当てはまる）。承認依頼中は設備を変えられない。設備の増減は監査ログの `changes_json.equipment_ids`（[前, 後]）に残す。フロントは、点検フォームの「設備」が複数選択で、複数選択のときは点検の計器を選ばず、不具合の項目に「不具合の設備」を出す
- **点検の承認フロー**: `draft ⇄ submitted → approval_requested → approved`（承認依頼中からは `submitted` へ差し戻し可）。遷移は `Inspection::STATUS_TRANSITIONS` とモデルの検証で強制する。更新できるのは作成者本人か管理者/マネージャー。承認と差し戻し（承認依頼中から出る操作）は管理者/マネージャーのみ（`InspectionPolicy#approve?`。作成者本人でも自分で差し戻せない）。`approved` は誰も変更できず、承認依頼中は内容（項目含む）を編集できない。新規作成できる状態は `draft` / `submitted` のみ
- **点検計画（`inspection_plans`）**: 設備（計器）ごとの周期と次回期限。点検が `draft` を出たとき（`after_save`）に `next_due_on` を「実施日 + 周期」へ進める。期限の「今日」は `InspectionPlan.today`（日本時間）で判定する。点検の設備と計画の設備は一致しなければならない
- **点検のまとまり（`inspection_plan_groups`。点検計画の親）**: 拠点・担当部署（任意。同じ拠点）・法規区分（任意）・既定の周期（計画を足すときの初期値）。**点検計画は必ずまとまりに属し（NOT NULL）、計画と同じ拠点のまとまりだけ**。周期・次回期限・チェックリスト・設備は子の計画が持つ。**まとまりを指定しない計画は `InspectionPlanGroup.default_for` が入れる**（拠点 × チェックリストの名前。担当部署はチェックリストの部署。基準器の年次校正は「拠点名 基準器の年次校正」、チェックリストなしは「チェックリストなしの点検」。なければ計画と一緒に作る）。既存の計画は同じ規則で `CreateInspectionPlanGroups` が移した（既定の周期は、まとめた計画で最も多い周期。シード `24_inspection_plan_groups.rb` も同じにそろえ、デモの法規区分 `db/data/inspection_plan_groups.rb` を付ける）。API は `/inspection_plan_groups`（一覧・詳細（子の計画つき）・作成・更新。作成・更新は管理者と自社のマネージャー、閲覧は全員。拠点は変えられない。監査ログに残す）。点検計画の一覧は `inspection_plan_group_ids`・`regulation_ids`・`department_id`（まとまりの担当部署。配下を含む）で絞り込める。まとまりの一覧は担当部署（配下を含む）・法規区分で絞り込め、計画の数・期限超過の数・いちばん近い次回期限を付ける。画面は下の「計画」
- **在庫**: 数量は入出庫・移動（`POST /stock_transactions`）でのみ変更する。入出庫（出庫・廃棄・移動・入庫）できるのは「在庫あり」「使用中」の在庫だけ（`Stock::TRANSACTABLE_STATUSES`。画面は `constants/stock.ts` のミラーで、それ以外の在庫には入出庫ボタンを出さない）で、修理待ち・修理中の在庫は修理管理の操作だけで変える。在庫行を `lock`（`SELECT ... FOR UPDATE`）してから更新し、DBの CHECK 制約（`quantity >= 0`）でも守る。`PATCH /stocks` は数量・倉庫・資材を変更できず、ステータスは「在庫あり」⇔「使用中」の間だけ直接変えられる（修理中・廃棄済は修理管理・廃棄の入出庫を通す）。新規登録できるのも「在庫あり」「使用中」のみ。在庫を初期数量つきで登録すると、入庫として台帳にも残る。移動先に同じロット（資材・購入日・状態が同じでシリアルなし）があれば数量を足す
- **法規区分**: 設備に適用する法規（`regulations`。高圧ガス・ボイラー・電気事業法・消防法・計量法）は、法定検査の周期（`regulation_inspections`。日数）と共に、付属機器の点検周期を決める起点。`target=instrument`（計量法）の区分は設備には付けられない（`Equipment` のバリデーション）。適用法規の付け外しは設備の更新（`regulation_ids`）で行い、変更前後のIDを監査ログ（`changes_json.regulation_ids`）に残す。マスタの定義は `db/data/regulations.rb`（シードと `SeedRegulations` マイグレーションが共有。周期はデモ用の想定）
- **5点校正**: 計器に校正条件（範囲・許容差・出力特性・DCS換算。`instruments`）を持たせ、点検項目の種別 `calibration` で0/25/50/75/100%の上昇・下降の出力（mA）とDCS表示を記録する。期待値・誤差・合否・ヒステリシスは `CalibrationSheet`（PORO。誤差は出力=16mA（ポジショナは範囲の幅）、DCS=DCS範囲の幅に対する%を、許容差と比べる）が計算し、画面の `utils/calibration.ts` は同じ規則をミラーしている（**規則を変えるときは両方と、両方のテスト（`calibration_sheet_test.rb`・E2E `calibration.spec.ts`）を直す**）。記録は `inspection_items.calibration_data`（校正時の条件 `snapshot` を凍結して保存。送られた `snapshot` は無視し、サーバーが計器から作る）と `calibration_result`。測定値を記録するには計器に範囲と許容差が必要（未設定は422）。調整した場合は調整後が最終の判定。範囲・許容差の既定値はデモ用の想定で、`db/data/instrument_calibration.rb`（シードと `SeedInstrumentCalibration` マイグレーションが共有）
- **基準器**: 校正に使う基準器の台帳（`reference_standards`）、メーカー校正の履歴（`reference_standard_calibrations`。実施日・校正した機関・証明書番号・結果・トレーサビリティ・有効期限）、点検で使った基準器と使用前の1点チェック（`inspection_reference_standards`）。点検日 D に効いていた校正＝D 以前で最新のもの（`ReferenceStandard#calibration_on`）で、合格かつ有効期限 ≧ D なら使える（`unusable_reasons`。画面の `utils/referenceStandard.ts` は同じ規則のミラー。変えるときは両方を直す）。**提出（下書きを出る）時に `Inspection#check_reference_standards!` が、使った基準器の状態・校正・使用前チェック（未確認もNG扱い）・取引用の計器のトレーサビリティを確認し、使えなければ422（理由は基準器ごとに配列で返る）。5点校正の測定値を提出するには基準器の指定が必要**。下書きの間は確認しない。承認依頼中は使った基準器を変更できない（`reference_standards` を送ると内容の編集扱い）。基準器の作成時に年次校正の点検計画（周期365日）を自動で作り、校正を記録すると（最新の校正のときだけ）計画の次回期限が校正の有効期限に進む。点検計画の対象は設備か基準器のどちらか一方（DBのCHECKとモデルで検証）。合格の校正の記録で、校正中の基準器は使用可に戻る。最新の校正が不合格のとき、基準器の詳細で、前回の合格した校正以降に使った点検（影響範囲）を返す。デモ用のデータは `db/data/reference_standards.rb`（シードと `SeedReferenceStandards` マイグレーションが共有。校正した機関・証明書番号は架空）
- **定期整備**: 関連設備を停止して行う整備の1回分の**親**（`scheduled_maintenances`。設計は `定期整備の再設計.md`）。対象設備は中間テーブル `scheduled_maintenance_equipments` で複数（1つ以上、すべて定期整備と同じ拠点。`equipment_ids` で付け外し、変更前後を監査ログ `changes_json.equipment_ids` に残す）。拠点は親の `site_id`（省略すれば対象設備の拠点）。状態は 計画中 → 準備中 → 実施中 → 検収 → 完了（`STATUS_TRANSITIONS`。画面の `constants/maintenanceStatus.ts` は同じ遷移のミラー。変えるときは両方を直す）。作成時の状態は常に計画中（指定は無視）。**完了にするには検収（検収日・検収者・結果）の記録が必要で、結果が「手直しあり」なら完了にできず実施中に戻して手直しする**（状態を完了に変えるときだけ検証するので、移行した完了済みの既存データは編集できる）。検収者は省略すれば記録した人。実施中にしたとき実績の開始日、完了にしたとき実績の終了日を、未入力なら自動で入れる。作成・編集・状態変更・検収は管理者と自社のマネージャー、見るのは全員。旧の `equipment_id` / `scheduled_date` / `completed_date` は使わない（NULL可で残してあり、次のリリースで削除）
- **定期整備の系列と複製**: 系列（`maintenance_series`）は繰り返しのまとまりで、設備ごとの周期（`maintenance_series_equipments.interval_months`）を持つ。定期整備は `maintenance_series_id` で系列に属す（同じ拠点の系列だけ）。「次回を作る」は `MaintenanceSuccessor` が提案する（`GET /scheduled_maintenances/:id/next_suggestion`。日付=前回の予定開始日+系列の最短の周期、名称の年を進める（年がなければ先頭に付ける）、対象設備=前回まで最後に含めた日から「周期−1か月」を過ぎた系列の設備。系列の周期が未登録の設備は入れない。系列に属さない整備は対象設備を引き継ぎ日付は空）。確認・修正した内容で `POST /scheduled_maintenances/:id/duplicate` が複製する（系列・説明・担当者を引き継ぎ、状態は計画中。検収・実績・使用資材は引き継がない）。系列の作成・編集・複製・提案は管理者と自社のマネージャー、見るのは全員。系列の周期の変更前後は監査ログ `changes_json.intervals` に残す
- **定期整備の作業**（`maintenance_tasks`）: 部署ごとの、設備・計器の点検・整備・交換・工事（`kind`）。対象設備は定期整備の対象設備のどれか、計器はその設備の計器、部署は定期整備と同じ拠点（未定は NULL）、チェックリストは点検の作業だけ（`MaintenanceTask` の検証）。状態は 未着手/実施中/完了/見送り（`STATUS_TRANSITIONS`）で、完了にすると完了日が入る。**一括追加**（`POST /scheduled_maintenances/:id/tasks/bulk`）は、設備の計器を種類ごとの定修点検つきで点検の作業にする（`MaintenanceTask.template_key_for`: 伝送器・調節弁（positioner）・遮断弁（`shutoff_valve`）・安全弁（`safety_valve`）。手動弁など対応がない計器と、すでに作業のある計器は飛ばす）。**点検（`inspections.maintenance_task_id`）が下書きを出ると作業を完了にする**（完了日は点検日。見送りは変えない）。**検収へ進めるのは未完了の作業がないとき**、**作業のある設備は対象設備から外せない**（`ScheduledMaintenance` の検証）。追加・削除・一括追加は管理者と自社のマネージャー、**状態・備考の更新は全員**（`MaintenanceTaskPolicy`。それ以外の項目は管理者・マネージャーの更新だけが反映される）。「次回を作る」は、対象設備に残る設備の作業を未着手に戻して引き継ぐ。チェックリストの周期（`checklist_templates.cycle`: patrol/monthly/annual/turnaround）が定修のものは点検計画に使えない（`InspectionPlan` の検証。変更したときだけ）
- **トラブルの定期整備への持ち込み**: トラブルの状態 `deferred`（定修待ち）は手動では選べず、`POST /troubles/:id/defer_to_maintenance`（既存の `scheduled_maintenance_id`＝計画中・準備中・同じ拠点、または `new_maintenance`）でだけなる。対象は未対応・対応中で、有効な作業がまだないトラブル。整備（`overhaul`）の作業を `trouble_id` つきで作り、トラブルの設備が定期整備の対象設備になければ追加して監査ログに残す。**作業の状態にトラブルが連動する**（`MaintenanceTask` のコールバック: 完了→解決済、見送り・削除→未対応。作業を進め直せば定修待ちに戻る）。定修待ちのトラブルは、有効な作業がなければならない（`Trouble` の検証）。操作は管理者と自社のマネージャー（`TroublePolicy#defer_to_maintenance?`）。「次回を作る」ではトラブルの作業は引き継がない
- **AI支援（不具合報告の下書き。設計は要求仕様書 2.5）**: `POST /ai/defect_drafts`（現場メモ → タイトル・内容・優先度と、参考の推定原因・確認したい点）と `GET /ai/status`（ボタンを出すか・残り回数）。**AIは提案までで、何も保存しない**（提案の記録 `ai_suggestions` と監査ログだけ。トラブルができるのは、人が反映して点検を保存したとき）。構成は `AiConfig`（環境変数）→ `AiClient`（`Claude`=Anthropic API / `Fake`=`AI_PROVIDER=fake`）→ `DefectDraftGenerator`（プロンプト・JSONスキーマ・出力の検証）→ `AiController`。スキーマ（`output_config.format`）では文字数・個数の制約を表せないため、長さ・個数・未知の優先度は `sanitize` で検証して捨てる。**プロンプト（`SYSTEM_PROMPT`）・スキーマ（`SCHEMA`）・`sanitize` は3点セットで直す**。メモは指示ではなくデータとして `<memo>` に入れ、`< >` は全角にして区切りの偽装を防ぐ。応急処置・運転継続の判断・担当者や状態の指定は出させない（プロンプトで禁止）。設備・計器の情報はサーバーがDBから作る（個人情報は渡さない）。**1日（日本時間）の回数はユーザ別・全体の上限**で、`AiSuggestion.reserve!` がアドバイザリロックの中で数えて記録を作り、失敗した呼び出しも数える。失敗（APIの障害・拒否・切れた応答・不正な形）は502、タイムアウト（15秒。再試行しない）は504で、点検の入力は止めない。**502/504にするのは `AiController::AI_FAILURES`（Anthropic の例外・`UnusableResponse`・各ジェネレータの `InvalidOutput`）だけで、コードの不具合（`NoMethodError` など）はAIの障害に見せかけず500のまま**（提案の記録は失敗にする）。フロントの `DefectAiAssist` は、設備・計器が変わったら下書きを消し、作っている間に変わったときの古い応答は捨てる（`ResponseAiAssist` はトラブルが変わったとき。どちらもメモの手直しでは消さない）。**失敗として記録するのはAIの呼び出しと出力の検証（`request_draft`）だけ**で、成功の記録（状態と監査ログ）は1つのトランザクション（監査ログが書けなければ成功の記録も戻して500。呼び出しは数えたまま）。点検の項目に `ai_suggestion_id` を付けて保存すると、点検から自動作成されたトラブルの監査ログ（`changes_json.ai_suggestion_id`）に残る。本人が今回の設備・計器について作った成功済みの提案のIDだけを認め、それ以外は黙って無視する（設備を変えたあとに送られても点検の保存を止めない）。フロントは `components/DefectAiAssist.vue`（点検フォームの不具合入力欄）。**画面では、AIは「プラナ」という呼び名・キャラクターで見せる（下の「プラナ」。処理・APIは変わらない）**。
  - **類似トラブル**（要求仕様書 2.5.1）: `POST /ai/similar_troubles`（`equipment_id`・`instrument_id`・`memo`・`exclude_trouble_id`）。`SimilarTroubleFinder` が**候補をSQLで絞り**（同じ計器 → 同じ種類・同じ流体の計器 → 同じ設備。最大20件。拠点をまたぐ）、AIは症状が似ているものを最大3件選んで対応を要約するだけ。**返ったIDが候補になければ捨て**、タイトル・状態などはDBの値を返す（AIの文章は `similarity`・`how_handled` だけ）。候補が0件のときはAIを呼ばず、回数にも数えない（`candidates_count: 0`）。**選ぶ前に、症状を書き出して比べさせる**（`memo_symptom`・`candidate_symptom`・`same_symptom`。`same_symptom` が真でない・症状が空のものは `sanitize` が捨てる。文章の指示だけでは、実際のモデルが症状の違う候補や、症状のないメモへの候補を選んだため）。対応記録のない候補の `how_handled` は「対応記録なし」に固定（AIの文章を使わない）。プロンプト・スキーマ・`sanitize` は3点セット。フロントは `composables/useSimilarTroubles.ts`（点検フォームの `DefectAiAssist` とトラブル詳細で共用）と `components/SimilarTroubleList.vue`（トラブルへのリンクは、入力中の画面を離れないよう別タブ）
  - **対応記録の下書き**（要求仕様書 2.5.2）: `POST /ai/response_drafts`（`trouble_id`・`memo`。設備・計器はトラブルからサーバーが求める）。`ResponseDraftGenerator`（対応種別・対応内容・使用資材・確認したい点。種別が決められないときは `unknown` → 提案なし）。権限は `TroubleResponsePolicy#create?`（協力会社の技能員は使えない）。対応記録の作成時に `trouble_response[ai_suggestion_id]` を送ると、本人が同じトラブルについて作った成功済みの `response_draft` のIDだけを認め、対応記録作成の監査ログ（`changes_json.ai_suggestion_id`）に残す（一致しないIDは黙って無視）。フロントは `components/ResponseAiAssist.vue`（対応記録ダイアログ）
  - 3つのジェネレータで共有する部品（設備・計器の説明、状態・優先度・対応種別の呼び方、`<>` のエスケープ、長さの検証）は `AiPromptSupport`。**1日の回数の上限は3機能で合算**（`AiSuggestion.reserve!` が種類を問わず数える）。`AiController` は上限の予約 → 呼び出し → 成功の記録の流れを `run_ai` に共通化していて、種類ごとの違い（画面に出す文言）は `KIND_TEXT`。失敗（502/504）・上限（429）の応答にも `remaining_today` を含める（失敗も回数に数えるため、画面の残り回数をそれで合わせる）。`AiClient::Fake` はスキーマの項目で何を返すか決める
- **点検の項目の判定と基準**（`ChecklistCriteria`。テンプレートの項目と点検の項目が共有する concern）: 種別は 確認（`check`）/ 測定値（`measurement`）/ 選択式（`choice`。`options` から選んだ値を `text_value` に）/ 自由記述（`text`）/ 5点校正。項目は区分（`section`。作業前・点検・復旧の見出し）・判定基準（`criterion`）・単位と許容範囲（`unit`・`lower_limit`・`upper_limit`。片側だけでも可）・必須（`required`）を持つ。**点検の項目は、テンプレートの項目から作るとき（`on: :create`）に基準をサーバーが写す**（送られた基準は無視。あとでテンプレートを変えても過去の記録は変わらない。その場で追加した項目だけ画面の値を受け付ける）。**判定 `result`**（good=良好 / defect=不具合あり / na=該当なし「－」）が「不具合あり」`has_defect` を決める（`InspectionItem#derive_result`。従来の `has_defect` / `checked` だけを送るAPIも受け付ける。未判定なら、確認済み→良好、測定値の範囲内→良好・範囲外→不具合あり、5点校正の合格→良好を自動で選ぶ。5点校正の不合格は不具合にしない＝点検者が決める）。**範囲外の測定値・不合格の校正は良好にできない**、許容範囲があるときの測定値は数値（全角は半角として読む）、選択式・自由記述に良好は付けない（モデルの検証）。**必須の項目が未記入なら提出（下書きを出る）できない**（`Inspection#check_required_items!`。判定を付ける種別は判定、選択式・自由記述は値か「－」。下書きの間は止めない。提出後に項目を変えたときも確認する）。測定値の判定の規則は画面の `utils/checklistCriteria.ts` がミラーする（**変えるときは両方を直す**）。画面は `components/ItemResultToggle.vue`（判定の3つのボタン。もう一度押すと未判定）で、測定値を入れると判定を自動で選ぶ（人が選んだ判定は、良好が範囲外になったときだけ変える）。条件つきの項目（「インターロックに関わる計器のみ」など）は、判定基準に書き、当てはまらなければ「－」を付ける。E2Eで提出するときは `support.ts` の `judgeAllItems()` で全項目に判定を付ける
- **タグ番号**: `instruments.tag_number` は拠点内で一意（別拠点なら同じ番号があり得る）。モデルで拠点内の一意を検証し、DBの一意制約は設備内のみ

- **タイムゾーン**: アプリは日本時間（`config.time_zone = "Tokyo"`。DBへの保存はUTC）。日時の入力は日本時間として解釈され、返す日時は「+09:00」付き。「今日」「今月」はコード上 `Date.current` / `Time.current`（`Date.today` は使わない）。フロントのフォーム初期値は `utils/datetime.ts`（`nowForInput` / `todayForInput`）を使う（`toISOString()` はUTCなので、日本時間の朝に前日になる）
- **ステータス遷移**: `StatusTransitions` concern で、各モデルの `STATUS_TRANSITIONS` に沿わない更新を拒否する（新規作成時は対象外）。トラブル: 未対応/対応中/解決済/完了（完了からは戻せない。解決済からは再対応＝対応中に戻せる）。修理: 依頼中→発送済→修理中→完了、廃棄は完了前のどこからでも（完了・廃棄からは変更不可）。発注: 下書き→発注済→受領済、キャンセルは受領前のみ。受領済・キャンセルでの新規作成は不可
- **トラブルの解決日時**: `resolved_at` はサーバがステータスから記録する（解決済・完了で初めて記録、再対応で消す）。APIで受け付けない
- **計器と設備の整合**: 点検・トラブル・点検計画の `instrument` は、指定した `equipment` に属するものでなければならない（`InstrumentBelongsToEquipment`）。点検項目の計器は、点検の対象設備の計器でなければならない
- **発注の受領 → 入庫**: 発注を受領済にするには入庫先の倉庫（`orders.warehouse_id`）が必要。受領すると、同じロット（資材・倉庫・受領日が同じ）に数量を足すか新しい在庫を作り、入庫を台帳と監査ログに残す（トランザクション内。二重受領しないよう発注の行を `lock!` する）。受領済の発注は数量・資材・入庫先・受領日を変更できない（単価・備考は可）
- **修理**: 修理に出せるのは在庫あり・使用中で数量1以上の在庫のみ。修理は1個ずつで、数量2以上のロットからは1個を別行に切り出して修理の対象にする（残りは使える状態のまま）。修理の状態変更と在庫の状態変更は同一トランザクション（修理の行を `lock!`）。在庫の状態を修理に合わせるのは、**修理の状態が変わったときだけ**で、そのとき在庫が修理待ち・修理中でなければ422（修理の外で廃棄された在庫を「在庫あり」に戻さない）（備考・費用だけの更新で、そのあと入出庫で変えた在庫の状態を戻さない）。修理の作成（修理待ちにする・1個を切り出す）・更新で在庫を変えたときは、在庫の監査ログも残す。修理は依頼中でしか新規作成できず、更新で修理対象の在庫（`stock_id`）は変えられない

### 簡易実装方針
- 価格履歴: orders テーブルで兼用
- 使用資材記録: テキストカラム（trouble_responses.used_materials 等）
- 監査ログ出力: CSV のみ（画面の「CSV出力」ボタン。APIは追加せず、フロントが条件に合う全件をページごとに取得して `utils/csv.ts` で組み立てる。BOM付きUTF-8、数式として解釈される先頭文字は「'」でエスケープ）
- 発注アラート: 集計APIは維持するが、ダッシュボードには表示しない（メール通知なし）
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
- シードファイル: `db/seeds/` 配下に 01〜19 の番号付きファイルで分割。定期整備のデモは、単体の整備（`11_maintenances.rb`）に加えて、川崎の「A号ボイラー整備」の系列（`19_maintenance_series.rb`。ボイラー24か月・発電設備48か月で、2022年（両方）・2024年（ボイラーのみ）・2026年（両方・計画中）の3回。作業、定修待ちのトラブル「FT-702」から回した整備の作業つき。既存環境にはマイグレーションで入れず、シード専用）
- チェックリストテンプレートは「機器の種類 × 周期」（月次・年次・定修。伝送器は月次・年次・定修、調節弁・遮断弁・安全弁は年次・定修、タンク液面計は年次）。**巡回だけは機器で分けず、装置単位の「巡回点検」1つ**（拠点ごとに同じ内容。装置をざっくり見て回り、異常があったときだけ記録するため、指示値の確認は項目に入れない。単独の計器の巡回点検はない）。定義は `db/data/checklist_templates.rb`（`ChecklistTemplateCatalog::TEMPLATES`: 名前・種別・拠点・項目）。シードと、既存環境（stg・本番）へ反映するマイグレーション（`RebuildChecklistTemplates`、機器ごとの巡回を装置単位に置き換えた `ReplacePatrolTemplates`）が共有する。5点校正の項目（`calibration`）は校正をする周期（伝送器の年次・定修、調節弁の年次・定修、タンク液面計の年次）にだけ置き、運転中に行う点検（伝送器の月次・年次、遮断弁の年次、タンク液面計の年次）にはインターロックのバイパス申請番号と解除・復帰後の確認の項目を入れる。1テンプレートは12項目まで（過剰にしない。`checklist_template_catalog_test.rb` が検証）。項目は `[内容, 種別, 基準]`（基準は区分・判定基準・単位・許容範囲・選択肢・必須。`item_attributes` が列の形にする。自由記述以外は既定で必須。判定基準・許容範囲の値はデモ用の想定）。**カタログの項目を変えたら、`UpgradeChecklistTemplateItems` と同じやり方の新しいマイグレーションで既存環境のテンプレートの項目を作り直す**（カタログと同じ名前のテンプレートの項目を消して作り直し、過去の点検の項目からの参照 `checklist_template_item_id` だけ外す）。テンプレートを増やすときはカタログに足す（シードが作る）。**テンプレートは消さずに廃止（`is_active=false`）する**（過去の点検記録が参照しているため）。`GET /checklist_templates` は廃止を除き、`include_inactive=true` で含める（設定画面用）。`RebuildChecklistTemplates` は、旧テンプレートを廃止にし、それを使っていた点検計画を新しいテンプレートに付け替え（デモの計画は名前・周期も合わせる）、利用者が作ったテンプレートには触れない。カタログの項目を変えても、既存環境のテンプレートの項目は更新されない（新しいマイグレーションが要る）
- 点検で不具合検出時、InspectionsController 内でトラブルを自動作成（モデルコールバックではなくコントローラロジック）。`has_defect && defect_title.present? && trouble.nil?` の条件で重複作成を防止。作成したトラブルは監査ログにも記録する（AIの下書きをもとにしたときは `ai_suggestion_id` も）

### フロントエンドの規約
- API呼び出し: `src/api/axios.ts` の単一 Axios インスタンスを直接使用（サービス層なし）
- 一覧の取得は、拠点や絞り込みを続けて変えると応答の順序が入れ替わるため、`utils/latestGuard.ts` で古い応答を破棄する（新しい一覧を作るときも使う）
- 型定義: `src/types/models.ts` に全インターフェースを集約
- 認証ストア: `stores/auth.ts` で singleton promise パターンによる初期化（レースコンディション防止）
- レイアウト: `MainLayout.vue` → `AppBar.vue` + `SideNav.vue` のスロット構成。サイドバーは仕事の流れ（ホーム → 記録する → 計画する）のあとに設備の台帳・資材と調達・組織と設定を並べ、プラナの入口は最後に置く（2026-09-27）。見える項目のないグループは出さない（項目名はE2Eがリンク名で辿るため変えない）。メニューの項目の `also`（`useNavigation.ts`）は、その項目に属するほかのパスで、ヘッダーの現在地に使う（定期整備の回の詳細 `/maintenances/:id` は「計画」）
- **計画**（`views/plans/PlanView.vue`、`/plans`。2026-09-27に点検計画・定期整備の一覧を統合）: 表示は「すべて・定期点検・定期整備・点検の期限順」（`?tab=inspection|maintenance|due`）。切り替え（`components/plans/PlanTabs.vue`）は、ホームの朝会・夕会と同じく絞り込みの行の拠点のすぐ右に置く（期限順は `InspectionPlanDueList` の `view` スロットで同じ位置に入れる）。**定期点検**はまとまりの表（期限超過のあるもの → 次回期限の近い順）で、行を押すとその場で子の点検計画を開く（`components/plans/InspectionGroupPlans.vue`。点検を実施・周期の見直し・このまとまりに計画を追加）。**定期整備**は系列（親。行を押すと各回を開き、回を押すと `/maintenances/:id`）を先に、系列に属さない単発の整備を後に、それぞれ予定の新しい順。系列の代表の回（予定期間・作業・状態）は終わっていない回のうち最も早いもので、状態で絞っているときはその状態の回。担当部署・法規区分はまとまりだけが持つため、それで絞っている間は定期整備を出さない。**点検の期限順**は旧の点検計画の一覧（`components/plans/InspectionPlanDueList.vue`。期限超過・周期の見直しの候補・まとまり・法規区分・担当部署の絞り込み）。追加・編集は管理者と自社のマネージャー: まとまり（`InspectionPlanGroupDialog.vue`）、点検計画（`InspectionPlanDialog.vue`。まとまりは必須で、選ぶと既定の周期を入れる）、定期整備（`MaintenanceCreateDialog.vue`）、系列の編集（`MaintenanceSeriesDialog.vue`。系列を新しく作るのは今までどおり回の詳細の「系列に登録」）。**旧の `/inspection-plans` は `?tab=due`、`/maintenances` は `?tab=maintenance` へ転送し、クエリ（`interval_review`・`overdue`・`status`・`site_ids`）を引き継ぐ**。期限の色・表示は `utils/inspectionPlan.ts` の `dueColor`/`dueLabel`。E2E は `plans.spec.ts`、メニューから開くのは `support.ts` の `openPlans(page, tab)`、ページをまたいで行を探すのは `findListRow`
- 画面の見出し: `components/layout/PageHeader.vue`。画面名（h1）と、その画面の役割を1行で示す。右端は操作ボタン（スロット）
- 詳細画面の頭: `components/layout/DetailHeader.vue`（戻る先の一覧・種類・名前（h1）・状態のチップ・補足・右端の操作）。**すべての詳細画面で使う**。戻るリンクの名前は「〜に戻る」（サイドバーの同じ名前のリンクと区別するため）。頭の下の概要は `.pk-summary__grid`（`main.css`）、関連の一覧はタブ（選んだタブは `?tab=`。`composables/useDetailTab.ts` に、出すタブの一覧を渡す。先頭が既定）。すべての詳細画面がこの形（関連の一覧がない修理はタブなし）。次の操作を止めるもの（定期整備の状態の流れ・検収・残っているバイパス）はタブに隠さない。E2E でタブの中の要素を見るときは、先にタブを押すか `?tab=` で開く
- 状態のチップ: `components/StatusChip.vue`（`kind` と `value` から、`constants/statusChip.ts` の規則で呼び方・色・塗りを決める。表にないバイパス・期限などは `label`・`color`・`alert` を渡す）。**状態は淡い色（tonal）のラベル型、緊急・期限超過・復帰期限超過だけ塗りつぶす**（デザインガイド「状態の表示」）。新しい画面で状態を出すときも、`v-chip` を直接書かずにこれを使う。E2E は `detail-layout.spec.ts`
- 絞り込み行: `class="pk-filters"`（`assets/main.css`）。白い面に入力欄をまとめ、条件を入れた項目は淡い青で示す
- トップページ（`views/HomeView.vue`）は、**「PlantKeeperとは何か」→「プラナとは何か」→「1件のトラブルでのプラナの仕事」の順**に見せる（2026-09-23。プラナを主役にした構成では、アプリが何なのか分かりにくかったため）。上から、ヒーロー（h1は「PlantKeeper」、キャッチは「設備保全に必要な情報を、ひとつの場所へ。」。**まず何を一元管理するシステムかを言う**。プラナは `#plana` への札1つだけ。画面はトラブル詳細 `assets/screenshots/trouble-detail.png`）→ 保全の流れ（`#features`。設備 → 点検 → トラブル → 修理 → 資材 → 在庫 → 発注。説明は実装済みの動作だけ）→ インターロックのバイパス（`#safety`。申請 → 承認 → バイパス → 復帰 → 復帰の確認の流れと、復帰期限超過・定期整備の検収の制限。画面はデモの I-701 の詳細 `assets/screenshots/interlock-bypass.png`。要求仕様書 2.7 に合わせる）→ 校正と周期の見直し（`#calibration`。5点校正 → 校正の傾向 → 周期の見直しの候補。画面はデモの FT-301 の校正の傾向 `assets/screenshots/calibration-trend.png`。要求仕様書 2.3 に合わせる）→ 日々の確認（`#daily`。ホーム（やること） `home.png`（シードの計器Aチームの sato で、朝会の画面の上部を幅1120で撮ったもの）と機器の自己診断 `device-diagnostics.png`。状態の表示は `DiagnosticChip` を使う。要求仕様書 2.8・2.9 に合わせる）→ プラナの紹介（`#plana`。キャラクターと短い紹介だけ。表示は左向きのため、画像は右の列。要求仕様書 2.5 に合わせる）→ プラナの仕事（`#plana-work`）。**本体の機能とプラナの境目を見せる**: `#features` の上に章の見出し「PlantKeeperの機能」、プラナの紹介と仕事は1つの色の帯（`.landing-plana-zone`）にまとめ、紹介の文はプラナがすることを平叙で書くだけにする（対比の決め台詞は置かない。ルールで動く機能の説明には、必要に応じて「AIは使いません」と書く）→ 体験の手順（`#try-guide`）→ 権限（`#permissions`）→ 開発の背景 → CTA。旧の `dashboard.png` などのスクリーンショットは旧デザインのため使わない。**文言と情報量**（2026-09-26）: 各節は「見出し ＋ 1〜2文 ＋ 画像か図1つ」を目安にし、ルールの細部は画面に任せる。見出しは「〜を、〜。」のキャッチコピーの形を並べず（ヒーローのキャッチだけ）、名詞の見出しにする。「ひとつ」「つなぐ」「支える」などの決まり文句や、「確定的に表示」のような設計メモの言葉は使わない
  - **プラナの3つの仕事は、同じ1件のトラブル（FT-301の指示低下）でつなげる**（仕事ごとに別の例にすると、どれも浅くなるため）: 1 点検で気づく（不具合報告の整理。見立てに導圧管・オリフィス）→ 2 過去の事例を見る（類似トラブル。過去に導圧管のブローで復旧した事例）→ 3 対応を記録する（対応記録の整理。ブローで復旧したメモ）。例を変えるときは、3つの話がつながったままにする（E2E `home.spec.ts` が、3つともFT-301で、2に導圧管が出ることを検証）。表示例は架空で、AIは呼ばない。1の定型項目は `instrument_troubleshooting_catalog.rb` の流量伝送器と同じ内容。各場面の「〜を試す」は `constants/planaCapabilities.ts` の `to`（`/plana?task=...`）へ
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

- **マイグレーションのあと、一部の一覧が500になる（`undefined method ...` など）**: 動いている開発サーバーが古い列情報を持っている（JOIN経由の読み込みで出る）。`docker-compose restart backend`
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
- 測定値の許容範囲は絶対値だけ（「設定圧力の±3%」のような、ほかの値に対する範囲は判定基準の文で示し、判定は人が付ける）。条件つきの項目（インターロックに関わる計器のみ等）は、計器の属性で自動にせず、当てはまらなければ人が「－」を付ける。温度の伝送器も圧力と同じ伝送器のテンプレート（均圧のゼロ点・導圧管は「－」）。配管・作業指示（Work Order）のエンティティはない
- `inspection_items.checked` が残っている（使っていない。判定 `result` に置き換え。次のリリースで削除する）
- 発注点は資材マスタに1つ（全拠点共通）で、在庫は拠点別のため、ダッシュボードで拠点を絞ったときのアラートは「その拠点の在庫 vs 全社の発注点」になる
- AIの呼び出しは同期で、最大15秒 puma のスレッドを占有する（デモの規模では許容。上限で頻度は抑えている）
- 本物のAnthropic APIを呼ぶ経路（`AiClient::Claude`）は、自動テストではスタブ・fakeのため検証していない。キーを設定したら、stg で下書きが返ることを手で確認する（リクエストの形は、SDKを通してローカルのスタブに送って確認済み）
- 類似トラブル・対応記録の下書きのプロンプトは、実際のモデル（Haiku 4.5）で評価した（2026-09-21。開発DBのシードデータ。評価のスクリプトはリポジトリにない）。類似トラブルは、症状の書き出しと `same_symptom` の判定を入れて、無関係なメモ・指示だけのメモ・症状の違うメモ（3種類×4回）は全回0件、信号途絶のメモは配線断線を4/4で選んだ。**残る限界**: 同じ設備の別の計器の「指示の低下」（例: 流量伝送器の徐々の低下に、液位計の指示低）を似ているとして混ぜることがある（4回中2回）。対応の要約が、記録より少し断定的になることがある（例:「配線を交換した」を「断線が原因と確認した」と書く）。対応記録の下書きは、8種類のメモ（清掃・交換・読み取れない・様子見・指示を仕込む・校正・運転継続の判断つき・調査と交換）で、メモにない原因・数値・資材の追加や、運転継続の判断・指示への追従はなかった（確認したい点に「〜は必要か」のような、作業を促す質問が混ざることがある）。モデルやプロンプトを変えたら、同じ観点で評価し直す
- `users.jti` カラムが残っている（使っていない。次のリリースで削除する）
- `scheduled_maintenances` の旧の列（`equipment_id` / `scheduled_date` / `completed_date`）が残っている（使っていない。次のリリースで削除する。移行は `BackfillScheduledMaintenanceParents`）
