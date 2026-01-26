#!/bin/bash
# irie ヘルパー関数
# post-setup.sh や post-cleanup.sh で source して使用できる
#
# 使用例:
#   source "${IRIE_LIB_DIR}/helpers.sh"

# カラー出力用（未定義の場合のみ設定）
BLUE=${BLUE:-$'\033[0;34m'}
GREEN=${GREEN:-$'\033[0;32m'}
YELLOW=${YELLOW:-$'\033[1;33m'}
NC=${NC:-$'\033[0m'}

# sed -i のOS差異を吸収
sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# PostgreSQLの起動待機（最大30秒）
wait_for_postgres() {
    local container="$1"
    local user="${2:-root}"
    echo -e "${BLUE}  → PostgreSQLの起動を待機中...${NC}"
    for i in $(seq 1 30); do
        if docker exec "$container" pg_isready -U "$user" -d postgres &>/dev/null; then
            echo -e "${GREEN}    ✓ PostgreSQL準備完了${NC}"
            return 0
        fi
        sleep 1
    done
    echo -e "${YELLOW}    → PostgreSQL待機タイムアウト${NC}"
    return 1
}

# MySQLの起動待機（最大30秒）
wait_for_mysql() {
    local container="$1"
    local user="${2:-root}"
    local password="${3:-}"
    echo -e "${BLUE}  → MySQLの起動を待機中...${NC}"
    for i in $(seq 1 30); do
        if docker exec "$container" mysqladmin ping -u"$user" ${password:+-p"$password"} --silent &>/dev/null; then
            echo -e "${GREEN}    ✓ MySQL準備完了${NC}"
            return 0
        fi
        sleep 1
    done
    echo -e "${YELLOW}    → MySQL待機タイムアウト${NC}"
    return 1
}

# PostgreSQLでDBが存在するかチェック
# 戻り値: 存在すれば0、なければ1
postgres_db_exists() {
    local container="$1"
    local db_name="$2"
    local user="${3:-root}"
    local password="${4:-}"
    if [ -n "$password" ]; then
        docker exec "$container" env PGPASSWORD="$password" psql -U "$user" -d postgres -tAc \
            "SELECT 1 FROM pg_database WHERE datname = '${db_name}'" 2>/dev/null | grep -q "1"
    else
        docker exec "$container" psql -U "$user" -d postgres -tAc \
            "SELECT 1 FROM pg_database WHERE datname = '${db_name}'" 2>/dev/null | grep -q "1"
    fi
}

# MySQLでDBが存在するかチェック
# 戻り値: 存在すれば0、なければ1
mysql_db_exists() {
    local container="$1"
    local db_name="$2"
    local user="${3:-root}"
    local password="${4:-root}"
    docker exec "$container" mysql -u"$user" -p"$password" -e \
        "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${db_name}';" 2>/dev/null | grep -q "$db_name"
}

# DB初期化が必要かどうかを判定し、SHOULD_INIT_DB変数を設定
# 引数: $1=db_exists (true|false) - DBが存在するかどうか
# 結果: SHOULD_INIT_DB変数に true/false を設定
# 判定条件:
#   1. mainブランチの場合（最初のセットアップ）
#   2. --separate-db指定の場合（専用DB）
#   3. DBが存在しない場合（安全策）
# 使用例:
#   postgres_db_exists "$DB_CONTAINER" "$WORKTREE_DB_NAME" && DB_EXISTS=true || DB_EXISTS=false
#   should_init_db "$DB_EXISTS"
should_init_db() {
    local db_exists="${1:-false}"

    SHOULD_INIT_DB=false

    if [ "$WORKTREE_DIR" = "main" ] || [ "$WORKTREE_DIR" = "master" ]; then
        SHOULD_INIT_DB=true
        echo -e "${BLUE}  → mainブランチのためDB初期化を実行${NC}"
    elif [ "$WORKTREE_USE_SEPARATE_DB" = "true" ]; then
        SHOULD_INIT_DB=true
        echo -e "${BLUE}  → 専用DBモードのためDB初期化を実行${NC}"
    elif [ "$db_exists" != "true" ]; then
        SHOULD_INIT_DB=true
        echo -e "${BLUE}  → DBが存在しないためDB初期化を実行${NC}"
    else
        echo -e "${BLUE}  → mainと同じDBを使用（マイグレーション・シーダーをスキップ）${NC}"
    fi
}

# ファイルが存在すればコピー（存在しなくてもエラーにはしない）
copy_if_exists() {
    local src="$1"
    local dest="$2"
    if [ -f "$src" ]; then
        # ソースとデスティネーションが同じ場合はスキップ
        if [ "$(realpath "$src")" = "$(realpath "$dest" 2>/dev/null)" ]; then
            echo -e "${YELLOW}    → $(basename "$src") は同じファイルのためスキップ${NC}"
            return 0
        fi
        cp "$src" "$dest"
        echo -e "${GREEN}    ✓ $(basename "$src")${NC}"
    else
        echo -e "${YELLOW}    → $(basename "$src") が存在しないためスキップ${NC}"
    fi
}

# チケットシステムのプロジェクトキーを削除
# 対応形式: PROJ-123, PROJ_NAME-456, ENG-1 など（Backlog/Jira/Linear）
# 引数: $1=DIR_NAME（feat/除去済み、例: PROJ_NAME-123-new-feature）
# 出力: プロジェクトキー削除後の文字列（例: 123-new-feature）
strip_ticket_project_key() {
    local dir_name="$1"
    # パターン: 大文字で始まり、大文字/数字/アンダースコアが続き、ハイフンで終わる
    # 例: PROJ_NAME- や PROJ- や PRODUCT_2013- を削除
    echo "$dir_name" | sed 's/^[A-Z][A-Z0-9]*\(_[A-Z0-9][A-Z0-9]*\)*-//'
}

# DB名を安全な長さに変換
# 引数: $1=プロジェクト名, $2=ディレクトリ名
# 出力: 44文字以内のDB名
# 計算: 63文字(PostgreSQL制限) - 8文字(_testing) - 8文字(_test_16) - 3文字(余裕) = 44文字
generate_safe_db_name() {
    local project_name="$1"
    local dir_name="$2"
    local max_length=44

    # プロジェクト名をDB用に変換（ハイフン→アンダースコア）
    local db_prefix=$(echo "$project_name" | tr '-' '_')

    # チケットのプロジェクトキーを削除（DB名短縮のため）
    local stripped_dir=$(strip_ticket_project_key "$dir_name")

    # DB名用に変換（スラッシュ/ハイフン→アンダースコア、小文字化）
    local db_suffix=$(echo "$stripped_dir" | tr '/-' '__' | tr '[:upper:]' '[:lower:]')

    # DB名を生成
    local db_name="${db_prefix}_${db_suffix}"

    # 長さ制限チェック（44文字で単純に切り詰め）
    if [ ${#db_name} -gt $max_length ]; then
        db_name="${db_name:0:$max_length}"
    fi

    echo "$db_name"
}
