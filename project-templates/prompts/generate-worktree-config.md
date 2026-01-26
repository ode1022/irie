# irie Worktree設定ファイル生成

このプロジェクト用のirie worktree設定ファイルを生成してください。

## irie対応済みプロジェクトでの動作

このプロンプトは新規プロジェクトだけでなく、**irie対応済みプロジェクト**でも使用できます。

irie関連ファイルが既に存在する場合（`docker-compose.override.traefik-example.yml`等）：
- ファイル生成はスキップ
- **.envファイルのセットアップのみを実行**
- セットアップ完了後、`irie override traefik --setup`を実行

これにより、`irie clone`後に`irie init`を実行するだけで環境構築が完了します。

## 最初に行うこと: .envファイルのセットアップ

cloneした直後は`.env`ファイルが存在しないため、最初に以下を確認してください：

1. テンプレートファイルを検索（`.env.example`、`.env.sample`、`.env.dist`、`example.env`など）
2. ネストしたディレクトリも含めて検索（`packages/*/`、`apps/*/`など）
3. 見つかった場合、ユーザーに一覧を表示して`.env`へのコピーを確認
4. 承認されたらコピーを実行

**対象となるファイルの例：**
- `.env.example` → `.env`
- `.env.testing.example` → `.env.testing`
- `.env.development.local.example` → `.env.development.local`
- `packages/server/.env.example` → `packages/server/.env`

例：
```
以下の.envテンプレートファイルが見つかりました：
  ./.env.example → ./.env
  ./.env.testing.example → ./.env.testing
  ./packages/server/.env.example → ./packages/server/.env

コピーしますか？
```

**重要:** ここでコピーした.envファイルは、post-setup.shでworktree間コピーの対象となる。

## .envファイルの書き換え

.envファイルをコピーした後、以下の書き換えを行ってください：

### プロジェクトREADMEの確認（重要）

APP_PUID/APP_PGID等の設定値は、**プロジェクトのREADME**に推奨値が記載されていることがあります。
まずプロジェクトのREADME.mdを確認し、記載がある場合はその値を使用してください。

例（プロジェクトREADMEに記載されている場合）：
```
WSL2:
APP_PUID=1000
APP_PGID=1000

mac:
APP_PUID=991
APP_PGID=991
```

プロジェクトREADMEに記載がない場合は、ユーザーに確認するか、一般的な値（1000/1000）を使用してください。

### 重複定義の整理

Windows/Mac/Linux用に複数の値が定義されている場合（コメントで切り替え）：
```env
# Windows用
APP_IMAGE=my_project-app:latest

# Mac用
APP_IMAGE=my-project-app:latest
```

→ 現在のOS（`uname`で判定）に適した値のみを残し、他は削除。

### プレースホルダーの置換

以下のようなプレースホルダーが残っている場合は、適切な値に置換：
- `{your PUID. see \`id -u\`}` → プロジェクトREADMEの推奨値、または`1000`
- `{your PGID. see \`id -g\`}` → プロジェクトREADMEの推奨値、または`1000`

## 共有DBのセットアップ

プロジェクトのdocker-compose.yml/yamlからDB種類とバージョンを検出し、共有DBを自動セットアップしてください。

### 1. DB種類とバージョンの検出

docker-compose.yml/yamlの`services:`から以下を検出：
- `postgres` サービス → PostgreSQL（イメージタグからバージョン取得: `postgres:15` → 15）
- `mysql` サービス → MySQL（イメージタグからバージョン取得: `mysql:8.0` → 8.0）

**PostGISの検出:**
postgresサービスのイメージが`postgis`を含む場合、PostGISが必要。

### 2. 共有DBの起動確認とバージョン確認

```bash
# PostgreSQLの場合
docker ps --filter "name=shared-postgres" --format "{{.Names}}" | grep -q shared-postgres
# 起動中のバージョン確認
docker exec shared-postgres psql -U root -c "SHOW server_version;" 2>/dev/null

# MySQLの場合
docker ps --filter "name=shared-mysql" --format "{{.Names}}" | grep -q shared-mysql
```

### 3. バージョンが異なる場合の対応

プロジェクトが既存の共有DBと異なるバージョンを必要とする場合、**別ポートで起動**：

```bash
cd ~/.irie/shared-services

# 例: PostgreSQL 16が必要な場合
cp templates/postgres.yml postgres16.yml
# postgres16.yml を編集:
#   - image: postgres:16
#   - container_name: shared-postgres-16
#   - ports: "127.0.0.1:5433:5432"
#   - volumes: postgres16-data:/var/lib/postgresql/data
docker compose -f postgres16.yml up -d
```

**ポート割り当ての例:**
| DB | ポート |
|-----|--------|
| PostgreSQL (1つ目) | 5432 |
| PostgreSQL (2つ目) | 5433 |
| PostgreSQL (3つ目) | 5434 |
| MySQL (1つ目) | 3306 |
| MySQL (2つ目) | 3307 |

### 4. PostGISが必要な場合

postgres.ymlのイメージを変更：

**macOS (Apple Silicon)の場合:**
```yaml
image: ghcr.io/baosystems/postgis:15-3.5
```

**Linux/WSL2の場合:**
```yaml
image: postgis/postgis:15-3.5
```

### 5. override-example.ymlでのDB_PORT指定

共有DBのポートがデフォルト以外の場合、override-example.ymlで`DB_PORT`環境変数を設定：

```yaml
services:
  app:
    environment:
      DB_HOST: shared-postgres-16  # バージョン別コンテナ名
      DB_PORT: 5433                # バージョン別ポート
```

### 6. ユーザーへの確認

共有DBのセットアップ前にユーザーに確認：
```
このプロジェクトはPostgreSQL 15を使用しています。

共有DBの状態を確認します...
- shared-postgres (PostgreSQL 15) が起動中です ✓

または

共有DBの状態を確認します...
- shared-postgres が起動していません

セットアップしますか？
- PostgreSQL 15 (標準)
- PostgreSQL 15 + PostGIS（地理空間機能が必要な場合）
```

## 参照すべきファイル

1. **このプロジェクトのdocker-compose.yml/yaml** - サービス構成を確認
2. **irieのサンプルテンプレート** - `~/.irie/project-templates/examples/` 以下のファイル

## 生成するファイル

プロジェクトルートに以下のファイルを生成：

1. `docker-compose.override.traefik-example.yml` - Traefik方式用
2. `docker-compose.override.loopback-example.yml` - Loopback方式（独立DB）用
3. `docker-compose.override.loopback-shared-db-example.yml` - Loopback方式（共有DB）用
4. `post-setup.sh` - 初期化スクリプト（実行可能権限を付与）
5. `post-cleanup.sh` - クリーンアップスクリプト（実行可能権限を付与）
6. `WORKTREE.md` - ドキュメント

## 生成ルール

### サービス検出
docker-compose.yml/yamlから以下のサービスを検出し、対応する設定を生成：
- `app`, `web`, `api`, `server` → アプリケーションサービス
- `nginx`, `apache` → Webサーバー（Traefikのエントリーポイント）
- `nodejs`, `node`, `vite` → Node/Vite開発サーバー
- `postgres`, `mysql` → データベース
- `minio` → S3互換ストレージ
- `mailpit` → メールテスト

### イメージ名の指定
元のdocker-compose.yml/yamlで`build:`を使用しており`image:`が指定されていないサービスは、
override側で`image: <プロジェクト名>-<サービス名>:latest`を必ず指定する。

例：プロジェクト名が`my-project`でappサービスの場合
```yaml
services:
  app:
    image: my-project-app:latest
```

これにより、worktreeごとにビルドが実行されることを防ぎ、mainでビルドしたイメージを共有できる。

### プレースホルダー
以下のプレースホルダーを使用（irieスクリプトが自動置換）：
- `{{DIR_NAME}}` - ディレクトリ名
- `{{FQDN}}` - 完全修飾ドメイン名
- `{{TRAEFIK_ID}}` - Traefikルーター識別子
- `{{DB_NAME}}` - データベース名
- `{{LOOPBACK_IP}}` - ループバックIP

### コンテナグループ名
`name: <プロジェクト名>-{{DIR_NAME}}`を指定してworktreeごとにコンテナを分離する。

```yaml
name: my-project-{{DIR_NAME}}
```

### Traefik方式の設定ポイント

#### ポート・ネットワーク
- `ports: !override []` でポートバインドを無効化
- `networks:` に `traefik-network` と `shared-db` を追加
- 外部ネットワークとして `traefik-network` と `shared-db` を定義

#### 依存関係の無効化
DBサービスを無効化する場合、以下も無効化が必要：
- `depends_on: !override []` - DBへの依存を無効化
- `links: !override []` - linksの無効化（元のdocker-compose.ymlにある場合）

#### DBサービスの無効化
```yaml
postgres:  # または mysql
  profiles:
    - disabled
```

#### Traefikラベル（Webサーバー用）
```yaml
nginx:
  labels:
    - "traefik.enable=true"
    # HTTP
    - "traefik.http.routers.{{TRAEFIK_ID}}.rule=Host(`{{FQDN}}`)"
    - "traefik.http.routers.{{TRAEFIK_ID}}.entrypoints=web"
    # HTTPS
    - "traefik.http.routers.{{TRAEFIK_ID}}-secure.rule=Host(`{{FQDN}}`)"
    - "traefik.http.routers.{{TRAEFIK_ID}}-secure.entrypoints=websecure"
    - "traefik.http.routers.{{TRAEFIK_ID}}-secure.tls=true"
    # Service
    - "traefik.http.services.{{TRAEFIK_ID}}.loadbalancer.server.port=80"
    - "traefik.docker.network=traefik-network"
```

#### Traefikラベル（その他サービス用）
Vite、MinIO、Mailpit等は `<サービス名>-{{TRAEFIK_ID}}` をルーター名に使用：
```yaml
nodejs:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.vite-{{TRAEFIK_ID}}.rule=Host(`vite-{{FQDN}}`)"
    - "traefik.http.routers.vite-{{TRAEFIK_ID}}.entrypoints=web"
    - "traefik.http.services.vite-{{TRAEFIK_ID}}.loadbalancer.server.port=5173"
    - "traefik.docker.network=traefik-network"
```

#### 環境変数のオーバーライド
アプリケーションサービスで以下の環境変数を設定：
```yaml
app:
  environment:
    APP_URL: http://{{FQDN}}
    # Laravel Sanctum使用時
    SANCTUM_STATEFUL_DOMAINS: {{FQDN}}
    # Vite開発サーバーURL（Traefik経由）
    VITE_DEV_SERVER_URL: http://vite-{{FQDN}}
    # 共有DB使用時
    DB_HOST: shared-postgres  # または shared-mysql
```

### Loopback方式の設定ポイント
- ポートに `{{LOOPBACK_IP}}:` プレフィックスを追加
- 共有DB版は `networks:` に `shared-db` を追加、DBを無効化
- 共有DB版でDBに`depends_on`/`links`しているサービスは無効化
- 独立DB版はDBポートにも `{{LOOPBACK_IP}}:` を追加

### post-setup.sh
プロジェクトの初期化処理を記述。**コメントアウトではなく、実際に実行されるコードとして生成すること。**

サンプルテンプレート（`~/.irie/project-templates/examples/post-setup.sh`）を参照し、
プロジェクトのdocker-compose.ymlに合わせて以下の処理を含める：

#### 1. irie_info関数（必須）
ファイル先頭に配置。`irie info`コマンドで表示するURL情報を出力。

#### 2. .envファイルのコピー（必須）
**元のworktree（`${WORKTREE_SOURCE_DIR}`）から新しいworktreeに`.env`ファイルをコピー。**

「最初に行うこと: .envファイルのセットアップ」でコピーした`.env`ファイルと同じものを対象にする：
- ルートの`.env`
- サブディレクトリの`.env`（モノレポの場合: `packages/server/.env`等）
- テスト用の`.env.testing`
- 開発用の`.env.development.local`、`.env.local`等

※ `.env.example`、`.env.sample`等のテンプレートファイルはコピー不要（gitで管理されているため）

#### 3. DB設定（PostgreSQL/MySQL使用時）
サンプルテンプレートを参照して以下を実装：
- DBコンテナ名を決定（共有DB or worktree専用DB）
- DB起動待機（`wait_for_postgres`または`wait_for_mysql`）
- 共有DB使用時: .envのDB設定を更新
- テストDB作成（テストDBは常に専用: `${WORKTREE_SEPARATE_DB_NAME}_testing`）

**DB初期化判定（重要）**: `should_init_db`関数を使用して判定：

```bash
# DB初期化判定（should_init_db関数がSHOULD_INIT_DB変数を設定）
# SHOULD_INIT_DB=true となる条件:
#   1. main/masterブランチの場合
#   2. --separate-db指定の場合（WORKTREE_USE_SEPARATE_DB=true）
#   3. DBが存在しない場合
postgres_db_exists "$DB_CONTAINER" "$WORKTREE_DB_NAME" && DB_EXISTS=true || DB_EXISTS=false
should_init_db "$DB_EXISTS"
# MySQLの場合: mysql_db_exists を使用
```

#### 4. 依存関係について（post-setup.shでは不要）

**推奨**: 依存関係はdocker build時にインストールし、post-setup.shでは実行しない。

プロジェクトディレクトリにライブラリフォルダが作成される言語（PHP: `vendor/`、Node.js: `node_modules/`など）では、docker-compose.yamlでanonymous volumeを使用することで、docker build時の依存関係をそのまま利用できる。

```yaml
# docker-compose.yaml での推奨設定
volumes:
  - ./src:/var/www/html        # ソースコードをマウント
  - /var/www/html/vendor       # anonymous volume: Docker側のvendorを使用
```

これにより:
- worktree追加時の時間を大幅に短縮
- post-setup.shで`composer install`等が不要

**post-setup.shに依存関係インストールは記述しないこと。**

#### 5. マイグレーション・シーダー実行（条件付き）

**重要**: DB作成とマイグレーションは `SHOULD_INIT_DB` 変数で判定：

```bash
# メインDB作成
if [ "$SHOULD_INIT_DB" = "true" ]; then
    echo -e "${BLUE}  → メインデータベース ${WORKTREE_DB_NAME} を作成中...${NC}"
    docker exec "$DB_CONTAINER" psql -U root -d postgres -c "CREATE DATABASE ${WORKTREE_DB_NAME};" 2>/dev/null || true
fi

# テストDB作成（worktree専用DB名・並行テスト実行のため分離必須）
echo -e "${BLUE}  → テスト用データベース ${TESTING_DB_NAME} を作成中...${NC}"
docker exec "$DB_CONTAINER" psql -U root -d postgres -c "CREATE DATABASE ${TESTING_DB_NAME};" 2>/dev/null || true

# === マイグレーション・シーダー ===
if [ "$SHOULD_INIT_DB" = "true" ]; then
    echo -e "${BLUE}  → migrate:fresh --seed${NC}"
    docker compose exec -T app php artisan migrate:fresh --seed
fi

# テストDBマイグレーション（常に実行・並行テスト実行のため分離必須）
echo -e "${BLUE}  → migrate:fresh --env=testing${NC}"
docker compose exec -T app php artisan migrate:fresh --env=testing
```

フレームワークごとのコマンド例：
- Laravel: `php artisan migrate:fresh --seed`
- Rails: `rails db:migrate db:seed`
- Django: `python manage.py migrate`

**重要**: サンプルテンプレートではコメントアウトされている処理も、
実際のプロジェクトでは有効なコードとして生成すること。

### post-cleanup.sh
共有DB使用時のデータベース削除処理を記述。

サンプルテンプレート（`~/.irie/project-templates/examples/post-cleanup.sh`）を参照し、以下の処理を含める：

#### 1. 専用DBの削除（--separate-db使用時のみ）
`WORKTREE_USE_SEPARATE_DB` が `true` の場合のみ、メインDBを削除。

#### 2. テストDBの削除
テストDBは常に専用名（`${WORKTREE_SEPARATE_DB_NAME}_testing`）なので、常に削除。

#### 3. 並列テスト用DBの削除（重要）
Laravelの `--parallel` オプション等で作成される並列テスト用DB（`_testing_1`, `_testing_2`, ...）を削除：

```bash
# 並列テスト用DBも削除（_testing_1, _testing_2, ... のパターン）
PARALLEL_DBS=$(docker exec shared-postgres psql -U root -d postgres -t -A \
    -c "SELECT datname FROM pg_database WHERE datname LIKE '${WORKTREE_SEPARATE_DB_NAME}_testing_%';" 2>/dev/null || true)
if [ -n "$PARALLEL_DBS" ]; then
    for db in $PARALLEL_DBS; do
        docker exec shared-postgres psql -U root -d postgres \
            -c "DROP DATABASE IF EXISTS \"$db\";" 2>/dev/null || true
    done
fi
```

MySQL の場合は同様のクエリを MySQL 用に変換する。

## プロジェクト名

gitリモートURLから取得（推奨）：
```bash
git remote get-url origin | sed 's/.*\///' | sed 's/\.git$//'
```

例: `git@github.com:user/my-project.git` → `my-project`

**注意**: worktreeディレクトリ内で実行する場合、`git rev-parse --show-toplevel`はworktreeのパスを返すため、リモートURLから取得すること。

## 出力

生成したファイルの内容を表示し、ユーザーの確認を得てから書き込んでください。

## 完了後の処理

### 新規プロジェクトの場合
ファイル生成完了後、`irie override traefik --setup` を実行してください。
docker-compose.override.ymlの生成、コンテナ起動、post-setup.shの実行まで一括で行います。
（Loopback方式の場合は `irie override loopback --setup`）

### irie対応済みプロジェクトの場合
.envセットアップ完了後、`irie override traefik --setup` を実行してください。
（Loopback方式の場合は `irie override loopback --setup`）
