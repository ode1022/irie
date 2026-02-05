#!/usr/bin/env bats

# Integration tests - actual worktree creation, HTTP connection, DB connection
# Run: bats tests/test_integration.bats
#
# Prerequisites:
# - Docker is running
# - shared-services (traefik, shared-postgres) are running

IRIE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
FIXTURES_DIR="$IRIE_DIR/tests/fixtures/sample-project"
EXAMPLES_DIR="$IRIE_DIR/project-templates/examples"

# WSL環境判定
is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# macOS環境判定
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# グローバル変数として保持（bats-coreはexport変数を共有しない）
TEST_PROJECT_DIR=""
TEST_PROJECT_NAME="irie-test-project"
TEST_WORKTREE_BASE=""  # worktreeが作成される親ディレクトリ
TEST_ENV_FILE="/tmp/irie-integration-test-env"

setup_file() {
    # 一度だけ実行: テスト用のgitリポジトリを作成
    # 注意: ディレクトリ名にドット(.)を含めない（Traefikラベルで問題になる）
    # 固定名を使用してプロジェクト名を予測可能にする
    # Colima環境では/tmpがマウントされないため、ホームディレクトリを使用
    TEST_PROJECT_DIR="$HOME/irie-integration-test/irie-test-proj"
    # Dockerコンテナがroot権限で作成したファイルがあるため、dockerで削除
    if [ -d "$HOME/irie-integration-test" ]; then
        docker run --rm -v "$HOME:$HOME" alpine rm -rf "$HOME/irie-integration-test" 2>/dev/null || true
    fi
    mkdir -p "$TEST_PROJECT_DIR"

    # テスト用ベースファイルをコピー（docker-compose.yml, html/, docker-compose.override.*.yml）
    # docker-compose.override.*.ymlはテスト用のシンプルなものを使用
    # （project-templates/examplesのものは複雑で、app/nodejs/minio等のサービスが必要）
    cp "$FIXTURES_DIR/docker-compose.yml" "$TEST_PROJECT_DIR/"
    cp -r "$FIXTURES_DIR/html" "$TEST_PROJECT_DIR/"
    cp "$FIXTURES_DIR/docker-compose.override.traefik-example.yml" "$TEST_PROJECT_DIR/"

    # post-setup.shは実際のテンプレートを使用（project-templates/examples/から）
    # これによりテンプレートの環境変数が正しいかどうかをテストできる
    cp "$EXAMPLES_DIR/post-setup.sh" "$TEST_PROJECT_DIR/"
    cp "$EXAMPLES_DIR/post-cleanup.sh" "$TEST_PROJECT_DIR/"

    # post-setup.shにテスト検証用のコードを追加（環境変数をファイルに出力）
    cat >> "$TEST_PROJECT_DIR/post-setup.sh" << 'TESTCODE'

# === テスト検証用（自動追加） ===
# 渡された環境変数をファイルに書き出し
ENV_OUTPUT_FILE=".irie-env-vars"
cat > "$ENV_OUTPUT_FILE" << EOF
WORKTREE_DIR=${WORKTREE_DIR:-}
WORKTREE_BRANCH=${WORKTREE_BRANCH:-}
WORKTREE_FQDN=${WORKTREE_FQDN:-}
WORKTREE_DB_NAME=${WORKTREE_DB_NAME:-}
WORKTREE_SEPARATE_DB_NAME=${WORKTREE_SEPARATE_DB_NAME:-}
WORKTREE_USE_SEPARATE_DB=${WORKTREE_USE_SEPARATE_DB:-}
EOF
echo "post-setup.sh: 環境変数を ${ENV_OUTPUT_FILE} に書き出しました"
TESTCODE

    # gitリポジトリとして初期化
    cd "$TEST_PROJECT_DIR"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    git add .
    git commit -m "Initial commit"

    # worktreeが作成される親ディレクトリを設定
    TEST_WORKTREE_BASE="$(dirname "$TEST_PROJECT_DIR")"

    # 環境変数をファイルに保存
    cat > "$TEST_ENV_FILE" << EOF
TEST_PROJECT_DIR=$TEST_PROJECT_DIR
TEST_WORKTREE_BASE=$TEST_WORKTREE_BASE
EOF
}

teardown_file() {
    # 環境変数を読み込み
    if [ -f "$TEST_ENV_FILE" ]; then
        source "$TEST_ENV_FILE"
    fi

    # テスト終了時にworktreeとコンテナをクリーンアップ
    if [ -n "$TEST_WORKTREE_BASE" ]; then
        for worktree in test-traefik test-same-db test-separate-db test-base-default test-base-explicit test-existing-local test-existing-base; do
            WORKTREE_PATH="$TEST_WORKTREE_BASE/$worktree"
            if [ -d "$WORKTREE_PATH" ]; then
                # Dockerコンテナを停止・削除
                cd "$WORKTREE_PATH" 2>/dev/null && docker-compose down 2>/dev/null || true
                # worktreeを削除
                cd "$TEST_PROJECT_DIR" 2>/dev/null && git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true
                rm -rf "$WORKTREE_PATH" 2>/dev/null || true
            fi
        done
    fi

    # テストプロジェクトを削除（Dockerコンテナがroot権限で作成したファイル対策）
    if [ -d "$HOME/irie-integration-test" ]; then
        docker run --rm -v "$HOME:$HOME" alpine rm -rf "$HOME/irie-integration-test" 2>/dev/null || true
    fi

    rm -f "$TEST_ENV_FILE"
}

setup() {
    # 各テスト前に環境変数を読み込み
    if [ -f "$TEST_ENV_FILE" ]; then
        source "$TEST_ENV_FILE"
    fi
    cd "$TEST_PROJECT_DIR"
}

# === Helper functions ===
# ヘルパー関数

wait_for_container() {
    local container_name="$1"
    local max_wait=30
    local count=0

    while [ $count -lt $max_wait ]; do
        if docker ps --format '{{.Names}}' | grep -q "$container_name"; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

wait_for_http() {
    local url="$1"
    local host_header="$2"
    local max_wait=60  # Colima環境では時間がかかるため60秒に延長
    local count=0

    while [ $count -lt $max_wait ]; do
        local http_code=""
        if [ -n "$host_header" ]; then
            http_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $host_header" "$url" 2>/dev/null)
        else
            http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        fi

        if [ "$http_code" = "200" ]; then
            return 0
        fi

        # デバッグ出力（10秒ごと）
        if [ $((count % 10)) -eq 0 ] && [ $count -gt 0 ]; then
            echo "# Waiting for HTTP 200... (${count}s, got: $http_code)" >&3 2>/dev/null || true
        fi

        sleep 1
        count=$((count + 1))
    done

    # タイムアウト時のデバッグ情報
    echo "# HTTP wait timeout after ${max_wait}s" >&3 2>/dev/null || true
    echo "# URL: $url, Host: $host_header" >&3 2>/dev/null || true
    echo "# Last HTTP code: $http_code" >&3 2>/dev/null || true
    echo "# Containers:" >&3 2>/dev/null || true
    docker ps --format '{{.Names}}: {{.Status}}' >&3 2>/dev/null || true
    echo "# Traefik routers:" >&3 2>/dev/null || true
    curl -s http://localhost:8080/api/http/routers 2>/dev/null | head -c 500 >&3 2>/dev/null || true

    return 1
}

# === Prerequisite checks ===
# 前提条件チェック

# Dockerが起動している
@test "prerequisite: Docker is running" {
    run docker info
    [ "$status" -eq 0 ]
}

# shared-servicesが起動している
@test "prerequisite: shared-services are running" {
    run docker ps --format '{{.Names}}'
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "traefik"
    echo "$output" | grep -q "shared-postgres"
}

# テストフィクスチャが存在する
@test "prerequisite: test fixtures exist" {
    [ -f "$FIXTURES_DIR/docker-compose.yml" ]
    [ -f "$FIXTURES_DIR/docker-compose.override.traefik-example.yml" ]
    [ -f "$FIXTURES_DIR/html/index.html" ]
}

# === Traefik mode tests ===
# Traefik方式テスト

# worktreeを作成できる
@test "Traefik mode: can create worktree" {
    cd "$TEST_PROJECT_DIR"

    # テスト用ブランチを作成
    git checkout -b feat/test-traefik
    git checkout main

    run "$IRIE_DIR/bin/irie" add test-traefik
    [ "$status" -eq 0 ]

    # worktreeディレクトリが作成されている（親ディレクトリに作成される）
    [ -d "$TEST_WORKTREE_BASE/test-traefik" ]

    # docker-compose.override.ymlが生成されている
    [ -f "$TEST_WORKTREE_BASE/test-traefik/docker-compose.override.yml" ]
}

# プレースホルダーが全て置換されている
@test "Traefik mode: all placeholders are replaced in override.yml" {
    skip_if_no_worktree "test-traefik"

    OVERRIDE_FILE="$TEST_WORKTREE_BASE/test-traefik/docker-compose.override.yml"

    # 未置換のプレースホルダー（{{...}}）が残っていないことを確認
    run grep -E '\{\{[A-Z_]+\}\}' "$OVERRIDE_FILE"
    if [ "$status" -eq 0 ]; then
        echo "# Unreplaced placeholders found:" >&3
        echo "$output" >&3
    fi
    [ "$status" -ne 0 ]  # grep が見つからない（exit 1）ことを期待
}

# HTTPでアクセスできる
@test "Traefik mode: can access via HTTP" {
    skip_if_no_worktree "test-traefik"

    # 生成されたdocker-compose.override.ymlからFQDNとコンテナプレフィックスを取得
    OVERRIDE_FILE="$TEST_WORKTREE_BASE/test-traefik/docker-compose.override.yml"
    # macOS対応: grep -Pの代わりにsedを使用
    FQDN=$(sed -n "s/.*Host(\`\([^\`]*\)\`).*/\1/p" "$OVERRIDE_FILE" | head -1)
    CONTAINER_PREFIX=$(grep "^name:" "$OVERRIDE_FILE" | awk '{print $2}')

    # デバッグ情報
    echo "# FQDN: $FQDN, CONTAINER_PREFIX: $CONTAINER_PREFIX" >&3

    # コンテナが起動するまで待機
    wait_for_container "$CONTAINER_PREFIX"
    echo "# Container is running" >&3

    # デバッグ: コンテナ内のファイル状態を確認
    echo "# Checking files in container..." >&3
    docker exec "${CONTAINER_PREFIX}-nginx-1" ls -la /usr/share/nginx/html/ >&3 2>&1 || echo "# Failed to list files" >&3
    docker exec "${CONTAINER_PREFIX}-nginx-1" cat /usr/share/nginx/html/index.html >&3 2>&1 || echo "# Failed to read index.html" >&3

    # Traefikがルートを検出するまで追加で待機
    sleep 3

    # HTTP接続テスト（Hostヘッダー指定）
    run wait_for_http "http://localhost" "$FQDN"
    [ "$status" -eq 0 ]

    # レスポンス内容を確認
    response=$(curl -s -H "Host: $FQDN" http://localhost)
    echo "$response" | grep -q "OK"
}

# HTTPSでアクセスできる
@test "Traefik mode: can access via HTTPS" {
    skip_if_no_worktree "test-traefik"

    # 生成されたdocker-compose.override.ymlからFQDNを取得
    OVERRIDE_FILE="$TEST_WORKTREE_BASE/test-traefik/docker-compose.override.yml"
    # macOS対応: grep -Pの代わりにsedを使用
    FQDN=$(sed -n "s/.*Host(\`\([^\`]*\)\`).*/\1/p" "$OVERRIDE_FILE" | head -1)

    # HTTPS接続テスト（自己署名証明書のため -k オプション）
    run curl -s -k -o /dev/null -w "%{http_code}" -H "Host: $FQDN" https://localhost
    [ "$output" = "200" ]
}

# cleanupできる
@test "Traefik mode: can cleanup" {
    skip_if_no_worktree "test-traefik"

    cd "$TEST_PROJECT_DIR"
    run "$IRIE_DIR/bin/irie" remove test-traefik --force
    [ "$status" -eq 0 ]

    # worktreeディレクトリが削除されている
    [ ! -d "$TEST_WORKTREE_BASE/test-traefik" ]
}

# === DB sharing mode tests ===
# DB共有モードテスト

# デフォルト（same-db）でmainと同じDB名が使用される
@test "DB mode: default uses main's db name (same-db)" {
    cd "$TEST_PROJECT_DIR"

    # テスト用ブランチを作成
    git checkout -b feat/test-same-db 2>/dev/null || true
    git checkout main

    # デフォルトモード（--separate-dbなし）でworktree作成
    run "$IRIE_DIR/bin/irie" add test-same-db
    [ "$status" -eq 0 ]

    # worktreeディレクトリが作成されている
    [ -d "$TEST_WORKTREE_BASE/test-same-db" ]

    # 環境変数ファイルを確認
    ENV_FILE="$TEST_WORKTREE_BASE/test-same-db/.irie-env-vars"
    [ -f "$ENV_FILE" ]

    # DB名がmainと同じ（irie_test_proj_main）であることを確認
    run grep "^WORKTREE_DB_NAME=" "$ENV_FILE"
    echo "# DB_NAME: $output" >&3
    echo "$output" | grep -q "irie_test_proj_main"

    # WORKTREE_SEPARATE_DB_NAME がworktree専用のDB名であることを確認
    run grep "^WORKTREE_SEPARATE_DB_NAME=" "$ENV_FILE"
    echo "# SEPARATE_DB_NAME: $output" >&3
    echo "$output" | grep -q "irie_test_proj_test_same_db"

    # WORKTREE_USE_SEPARATE_DB=false であることを確認（デフォルト=same-db）
    run grep "^WORKTREE_USE_SEPARATE_DB=" "$ENV_FILE"
    echo "# USE_SEPARATE_DB: $output" >&3
    echo "$output" | grep -q "false"
}

# --separate-dbで専用DB名が使用される
@test "DB mode: --separate-db uses dedicated db name" {
    cd "$TEST_PROJECT_DIR"

    # テスト用ブランチを作成
    git checkout -b feat/test-separate-db 2>/dev/null || true
    git checkout main

    # --separate-dbオプション付きでworktree作成
    run "$IRIE_DIR/bin/irie" add test-separate-db --separate-db
    [ "$status" -eq 0 ]

    # worktreeディレクトリが作成されている
    [ -d "$TEST_WORKTREE_BASE/test-separate-db" ]

    # 環境変数ファイルを確認
    ENV_FILE="$TEST_WORKTREE_BASE/test-separate-db/.irie-env-vars"
    [ -f "$ENV_FILE" ]

    # DB名が専用（irie_test_proj_test_separate_db）であることを確認
    run grep "^WORKTREE_DB_NAME=" "$ENV_FILE"
    echo "# DB_NAME: $output" >&3
    echo "$output" | grep -q "irie_test_proj_test_separate_db"

    # WORKTREE_SEPARATE_DB_NAME がworktree専用のDB名であることを確認
    run grep "^WORKTREE_SEPARATE_DB_NAME=" "$ENV_FILE"
    echo "# SEPARATE_DB_NAME: $output" >&3
    echo "$output" | grep -q "irie_test_proj_test_separate_db"

    # WORKTREE_USE_SEPARATE_DB=true であることを確認（--separate-db）
    run grep "^WORKTREE_USE_SEPARATE_DB=" "$ENV_FILE"
    echo "# USE_SEPARATE_DB: $output" >&3
    echo "$output" | grep -q "true"
}

# same-dbモードでは異なるworktreeでも同じDB名
@test "DB mode: different worktrees share same db name in same-db mode" {
    # test-same-dbとtest-traefikが同じDB名を持つことを確認
    skip_if_no_worktree "test-same-db"
    skip_if_no_worktree "test-traefik"

    ENV_FILE_1="$TEST_WORKTREE_BASE/test-same-db/.irie-env-vars"
    ENV_FILE_2="$TEST_WORKTREE_BASE/test-traefik/.irie-env-vars"

    DB_NAME_1=$(grep "^WORKTREE_DB_NAME=" "$ENV_FILE_1" | cut -d= -f2)
    DB_NAME_2=$(grep "^WORKTREE_DB_NAME=" "$ENV_FILE_2" | cut -d= -f2)

    echo "# test-same-db DB: $DB_NAME_1" >&3
    echo "# test-traefik DB: $DB_NAME_2" >&3

    [ "$DB_NAME_1" = "$DB_NAME_2" ]
}

# separate-dbモードでは異なるworktreeで異なるDB名
@test "DB mode: different worktrees have different db names in separate-db mode" {
    skip_if_no_worktree "test-separate-db"
    skip_if_no_worktree "test-same-db"

    ENV_FILE_1="$TEST_WORKTREE_BASE/test-separate-db/.irie-env-vars"
    ENV_FILE_2="$TEST_WORKTREE_BASE/test-same-db/.irie-env-vars"

    DB_NAME_1=$(grep "^WORKTREE_DB_NAME=" "$ENV_FILE_1" | cut -d= -f2)
    DB_NAME_2=$(grep "^WORKTREE_DB_NAME=" "$ENV_FILE_2" | cut -d= -f2)

    echo "# test-separate-db DB: $DB_NAME_1" >&3
    echo "# test-same-db DB: $DB_NAME_2" >&3

    [ "$DB_NAME_1" != "$DB_NAME_2" ]
}

# DBモードテスト用worktreeをクリーンアップ
@test "DB mode: cleanup test worktrees" {
    cd "$TEST_PROJECT_DIR"

    for worktree in test-same-db test-separate-db; do
        WORKTREE_PATH="$TEST_WORKTREE_BASE/$worktree"
        if [ -d "$WORKTREE_PATH" ]; then
            cd "$WORKTREE_PATH" 2>/dev/null && docker-compose down 2>/dev/null || true
            cd "$TEST_PROJECT_DIR"
            run "$IRIE_DIR/bin/irie" remove "$worktree" --force
        fi
    done

    [ ! -d "$TEST_WORKTREE_BASE/test-same-db" ]
    [ ! -d "$TEST_WORKTREE_BASE/test-separate-db" ]
}

# === Base branch tests ===
# ベースブランチテスト

# worktree内から--baseなしで実行すると、現在のブランチから派生する
@test "Base branch: defaults to current branch when run from worktree" {
    cd "$TEST_PROJECT_DIR"

    # featureブランチを作成してチェックアウト
    git checkout -b feat/base-test-feature
    echo "feature content" > feature.txt
    git add feature.txt
    git commit -m "Add feature content"

    # このブランチから--baseなしでworktree作成
    run "$IRIE_DIR/bin/irie" add test-base-default
    [ "$status" -eq 0 ]

    # worktreeが作成されている
    [ -d "$TEST_WORKTREE_BASE/test-base-default" ]

    # 作成されたworktreeにfeature.txtが存在する（feat/base-test-featureから派生した証拠）
    [ -f "$TEST_WORKTREE_BASE/test-base-default/feature.txt" ]

    # mainに戻る
    git checkout main
}

# --baseを明示的に指定すると、そのブランチから派生する
@test "Base branch: uses specified branch when --base is provided" {
    cd "$TEST_PROJECT_DIR"

    # featureブランチにいる状態から、mainを--baseに指定
    git checkout feat/base-test-feature 2>/dev/null || git checkout -b feat/base-test-feature

    run "$IRIE_DIR/bin/irie" add test-base-explicit --base main
    [ "$status" -eq 0 ]

    # worktreeが作成されている
    [ -d "$TEST_WORKTREE_BASE/test-base-explicit" ]

    # feature.txtが存在しない（mainから派生した証拠）
    [ ! -f "$TEST_WORKTREE_BASE/test-base-explicit/feature.txt" ]

    # mainに戻る
    git checkout main
}

# 既存のローカルブランチがある場合、チェックアウトされる（-bなし）
@test "Base branch: checks out existing local branch without -b" {
    cd "$TEST_PROJECT_DIR"

    # 事前にブランチだけ作成（worktreeではない）
    git branch feat/test-existing-local 2>/dev/null || true

    # irie addで既存ブランチをチェックアウト
    run "$IRIE_DIR/bin/irie" add feat/test-existing-local
    [ "$status" -eq 0 ]

    # worktreeが作成されている
    [ -d "$TEST_WORKTREE_BASE/test-existing-local" ]

    # 出力に「既存ブランチ」のメッセージが含まれている
    echo "$output" | grep -q "既存ブランチ"
}

# --baseを指定しても既存ブランチがある場合はチェックアウトされ、--baseは無視される
@test "Base branch: ignores --base when branch already exists" {
    cd "$TEST_PROJECT_DIR"

    # 事前にブランチだけ作成
    git branch feat/test-existing-base 2>/dev/null || true

    # --base付きでirie add
    run "$IRIE_DIR/bin/irie" add feat/test-existing-base --base main
    [ "$status" -eq 0 ]

    # worktreeが作成されている
    [ -d "$TEST_WORKTREE_BASE/test-existing-base" ]

    # --baseが無視された旨のメッセージが含まれている
    echo "$output" | grep -q "無視されます"
}

# ベースブランチテスト用worktreeをクリーンアップ
@test "Base branch: cleanup test worktrees" {
    cd "$TEST_PROJECT_DIR"

    for worktree in test-base-default test-base-explicit test-existing-local test-existing-base; do
        WORKTREE_PATH="$TEST_WORKTREE_BASE/$worktree"
        if [ -d "$WORKTREE_PATH" ]; then
            cd "$WORKTREE_PATH" 2>/dev/null && docker-compose down 2>/dev/null || true
            cd "$TEST_PROJECT_DIR"
            run "$IRIE_DIR/bin/irie" remove "$worktree" --force
        fi
    done

    [ ! -d "$TEST_WORKTREE_BASE/test-base-default" ]
    [ ! -d "$TEST_WORKTREE_BASE/test-base-explicit" ]
    [ ! -d "$TEST_WORKTREE_BASE/test-existing-local" ]
    [ ! -d "$TEST_WORKTREE_BASE/test-existing-base" ]
}

# === Shared DB connection tests ===
# 共有DB接続テスト

# PostgreSQLに接続できる
@test "Shared DB: can connect to PostgreSQL" {
    # shared-postgresコンテナに接続テスト
    run docker exec shared-postgres psql -U root -d postgres -c "SELECT 1;"
    [ "$status" -eq 0 ]
}

# データベースを作成・削除できる
@test "Shared DB: can create and drop database" {
    TEST_DB_NAME="irie_integration_test_db"

    # DB作成
    run docker exec shared-postgres psql -U root -d postgres -c "CREATE DATABASE ${TEST_DB_NAME};"
    [ "$status" -eq 0 ]

    # DB存在確認
    run docker exec shared-postgres psql -U root -d postgres -c "SELECT datname FROM pg_database WHERE datname = '${TEST_DB_NAME}';"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "$TEST_DB_NAME"

    # DB削除
    run docker exec shared-postgres psql -U root -d postgres -c "DROP DATABASE ${TEST_DB_NAME};"
    [ "$status" -eq 0 ]
}

# === Helper functions (skip) ===
# ヘルパー関数（skip用）

skip_if_no_worktree() {
    local worktree_name="$1"
    if [ ! -d "$TEST_WORKTREE_BASE/$worktree_name" ]; then
        skip "worktree '$worktree_name' does not exist"
    fi
}
