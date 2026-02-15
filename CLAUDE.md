# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

PlantKeeper — 石油プラントの保全業務を統合管理するWebアプリケーション。
計装保全の実務経験（ENEOS川崎製油所10年）をベースにしたドメイン特化設計。

## 技術スタック

- フロントエンド: Vue 3 + TypeScript + Vuetify 3 + Pinia + Vue Router 4 + Axios
- バックエンド: Rails 7 API mode + devise + devise-jwt
- DB: PostgreSQL 16
- インフラ: Docker（docker-compose）

## 開発コマンド

```bash
# 起動
docker-compose up -d

# マイグレーション
docker-compose exec backend bundle exec rails db:migrate

# シードデータ
docker-compose exec backend bundle exec rails db:seed

# Railsコンソール
docker-compose exec backend bundle exec rails console

# ログ確認
docker-compose logs -f backend
```

## ログイン情報（開発用）

- 管理者: admin@example.com / password
- 監督者: suzuki@example.com / password
- 作業員: sato@example.com / password

## 設計ドキュメント

- `要求仕様書.md` — 機能要件、業務フロー、設計方針
- `データモデル設計.md` — 26テーブルのER図・テーブル定義・簡易化メモ

## アーキテクチャ

### 機能優先度
1. **保全管理**（メイン）: 設備台帳、点検・作業記録、トラブル管理、定期整備
2. **運転部門チェック統合**: 保全と同じチェックリスト機能を使用、不具合→トラブル自動連携
3. **資材管理**: 資材マスタ、在庫（FIFO）、修理、発注、拠点横断検索
4. **ユーザ管理**: 全員ログイン、6ロール、退職/復帰対応

### データモデルの設計方針
- 論理削除パターン: sites.is_active / users.is_active（履歴保持）
- 履歴パターン: started_on/ended_on（equipment_assignments, department_histories）
- ポリモーフィック監査ログ: audit_logs（auditable_type/auditable_id）
- 自己結合: material_alternatives（代替品）
- 正規化検索: materials.normalized_part_number（ハイフン除去）
- 添付ファイル: ActiveStorage（has_many_attached）— 専用テーブルなし

### 簡易実装方針
- 承認フロー: UIのみ（ボタンでステータス変更、ロジックなし）
- 価格履歴: orders テーブルで兼用
- 使用資材記録: テキストカラム（trouble_responses.used_materials 等）
- 監査ログ出力: CSV のみ
- 発注アラート: ダッシュボードにリスト表示のみ（メール通知なし）

## 注意事項

- GitHub公開リポジトリ。ポートフォリオ関連の文言をコードやドキュメントに書かない
- 日本語でコミュニケーション
- `equipment` は Rails で不可算名詞扱い。`config/initializers/inflections.rb` で `irregular "equipment", "equipments"` を定義済み
- JWT認証: ログイン POST /api/v1/login、ログアウト DELETE /api/v1/logout。トークンは Authorization ヘッダーで送受信
