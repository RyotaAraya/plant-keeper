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

## ログイン情報（開発用）

- 管理者(admin): admin@example.com / password
- 監督者(supervisor): suzuki@example.com / password
- 一般(member): sato@example.com / password

## 設計ドキュメント

- `要求仕様書.md` — 機能要件、業務フロー、設計方針
- `データモデル設計.md` — 27テーブルのER図・テーブル定義・簡易化メモ
- `DEVELOPMENT.md` — 開発環境構築ガイド

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
| 権限 | system_role | admin / member | supervisor / worker |

- 会社タイプ変更で雇用区分・権限の選択肢が連動
- 協力会社は部署（department）なし

### 部署の階層構造
- departments テーブル: parent_id 自己参照で3階層（division→section→team）
- 拠点（site）ごとに独立したツリー
- `Department#full_path` → "保全部 > 計器保全課 > 計器Aチーム"
- `Department#ancestor_chain` → 階層配列（UI用）
- API: `GET /departments?tree=true` でネストされたツリー取得

### バックエンド構造
- API: `/api/v1` 名前空間、全コントローラが `BaseController`（`authenticate_user!`）を継承
- 認証: devise-jwt、トークンは Authorization ヘッダーで送受信
- レスポンス: `{ data: ... }` 形式。User は `user_json` ヘルパーで company/department をネスト返却

### フロントエンド構造
- ルーティング: `meta: { requiresAuth: true }` でガード、遅延ロード
- 認証: `stores/auth.ts` で JWT を localStorage 管理、axios インターセプタで自動付与
- 画面パターン: `*ListView.vue`（一覧+フィルタ） + `*DetailView.vue`（詳細+編集ダイアログ）
- UIパターン: カスケードセレクト（拠点→部→課→チーム）に `initializing` フラグで watch 連鎖抑制

### データモデルの設計方針
- 論理削除: sites.is_active / users.is_active / companies.is_active（履歴保持）
- 履歴パターン: started_on/ended_on（equipment_assignments, department_histories）
- ポリモーフィック監査ログ: audit_logs（auditable_type/auditable_id）
- 自己結合: departments（parent_id）、material_alternatives（代替品）
- 正規化検索: materials.normalized_part_number（ハイフン除去）
- 添付ファイル: ActiveStorage（has_many_attached）— 専用テーブルなし

### 簡易実装方針
- 承認フロー: UIのみ（ボタンでステータス変更、ロジックなし）
- 価格履歴: orders テーブルで兼用
- 使用資材記録: テキストカラム（trouble_responses.used_materials 等）
- 監査ログ出力: CSV のみ
- 発注アラート: ダッシュボードにリスト表示のみ（メール通知なし）

### バックエンドの規約
- レスポンス形式: 成功 `{ data: ... }`、エラー `{ errors: [...] }`
- ページネーション: `page`/`per_page` パラメータ → `{ data: [...], meta: { total_count, page, per_page } }`
- フィルタリング: コントローラ内で `if params[:x].present?` チェーンで実装
- enum はすべて文字列型（integer ではない）
- 論理削除リソースには `destroy` ルートなし（`is_active` フラグで管理）
- JSON シリアライズ: `as_json(include: ...)` インライン。ActiveModel::Serializers 不使用（UserSerializer のみ PORO）
- シードファイル: `db/seeds/` 配下に 01〜13 の番号付きファイルで分割
- 点検で不具合検出時、InspectionsController 内でトラブルを自動作成（モデルコールバックではなくコントローラロジック）

### フロントエンドの規約
- API呼び出し: `src/api/axios.ts` の単一 Axios インスタンスを直接使用（サービス層なし）
- 型定義: `src/types/models.ts` に全インターフェースを集約
- 認証ストア: `stores/auth.ts` で singleton promise パターンによる初期化（レースコンディション防止）
- レイアウト: `MainLayout.vue` → `AppBar.vue` + `SideNav.vue` のスロット構成

## 注意事項

- GitHub公開リポジトリ。ポートフォリオ関連の文言をコードやドキュメントに書かない
- 日本語でコミュニケーション
- テストスイートなし（RSpec/Minitest/Vitest いずれも未導入）
- `equipment` は Rails で不可算名詞扱い。`config/initializers/inflections.rb` で `irregular "equipment", "equipments"` を定義済み
- JWT認証: ログイン POST /api/v1/login、ログアウト DELETE /api/v1/logout
- pre-push フック（lefthook）: ESLint + vue-tsc + RuboCop が自動実行される
- vue-tsc は Vuetify の型定義で既知のエラーあり。ビルド確認は `npx vite build` を使用
- シードの audit_log 部分で `Auditable must exist` バリデーションエラーが出るが、ユーザ・設備等の主要データには影響なし
