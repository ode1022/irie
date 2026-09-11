# CLAUDE.md

このファイルはAIコーディングエージェント向けのプロジェクト指示を提供します。

## コード・ドキュメントの例示ルール

irieは汎用ツールのため、ドキュメントやコード例では**実際のプロジェクト名やチケット番号を使用しない**こと。

### 使用する汎用的な例

| 項目 | 使用する例 | 使用しない例 |
|------|-----------|-------------|
| プロジェクト名 | `my-project`, `my_project` | 実際のプロジェクト名 |
| ブランチ名 | `feat/new-feature`, `fix/bug-fix` | 実際のチケット名 |
| チケットキー | `PROJ-123`, `PROJ_NAME-456` | 実際のBacklog/Jiraキー |
| チケット説明 | `new-feature`, `fix-bug`, `update-api` | 実際のタスク名 |
| DB名 | `my_project_new_feature` | 実際のDB名 |
| ホスト名 | `new-feature.my-project.localhost` | 実際のホスト名 |

### 例

```bash
# Good
feat/PROJ_NAME-123-new-feature
my-project
my_project_123_new_feature
```

## 競合ツール調査

新機能を検討する際は [docs/competitors.md](docs/competitors.md) を参照して、既存ツールのアプローチを確認すること。

**主な競合ツール:**
- gtr - 複数worktreeでコマンド一括実行
- wtp - fzf連携、shell-init方式
- gwq - ghq風のworktree管理

**irieの差別化ポイント:**
- Docker Compose連携（共有DB、Traefik）
- プロジェクト固有フック（post-setup.sh）
- Claude Code連携（irie init）

## bash互換性

macOSの`/bin/bash`はバージョン3.2のため、**bash 3.2互換のコードを書くこと**。

以下の機能は使用禁止:
- `declare -A`（連想配列） → `"key|value"`形式の通常配列で代替
- `${var,,}` / `${var^^}`（大文字小文字変換） → `tr`コマンドで代替
- `mapfile` / `readarray` → `while read`ループで代替
- `|&`（stderrパイプ） → `2>&1 |`で代替
- `&>>`（追記リダイレクト） → `>> file 2>&1`で代替

## テスト

```bash
# 全テスト実行
bats tests/

# 個別テスト実行
bats tests/test_name_conversion.bats
```

### テスト名は英語で書く

`@test "..."` のテスト名に日本語（非ASCII文字）を使わないこと。

macOSのbatsは日本語を含むテスト名を解決できず、`bats: unknown test name` となって
**そのファイルのテストが1件も実行されない**。TAPの計画数と実行数がずれるため、
`Executed 135 instead of expected 145 tests` でCI（test-macos）が失敗する。
Linux側は成功するので、ローカルで気づきにくい。

```bash
# Good
@test "detect_wsl_jetbrains: picks newest version across install locations" {

# Bad（macOSで実行されない）
@test "detect_wsl_jetbrains: インストール先をまたいで最新バージョンを選ぶ" {
```

テスト名は英語、テスト内のコメントは日本語でよい。

## リリース

- mainブランチへのpushでrelease-pleaseが自動実行される
- セマンティックバージョニングに従ったコミットメッセージを使用する
  - `feat:` - 新機能（マイナーバージョンアップ）
  - `fix:` - バグ修正（パッチバージョンアップ）
  - `feat!:` または `BREAKING CHANGE:` - 破壊的変更（メジャーバージョンアップ）
