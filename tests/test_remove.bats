#!/usr/bin/env bats

# irie-remove.sh のテスト
# 実行: bats tests/test_remove.bats

setup() {
    TEST_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "$TEST_DIR"
}

# === DB name generation tests ===
# DB名生成のテスト

# ディレクトリ名からDB名を生成
@test "db name generation: generates db name from directory name" {
    PROJECT_NAME="myproject"
    DB_PREFIX=$(echo "$PROJECT_NAME" | tr '-' '_')
    DIR_NAME="new-feature"

    DB_NAME_TEMP=$(echo "$DIR_NAME" | tr '/-' '__' | tr '[:upper:]' '[:lower:]')
    DB_NAME="${DB_PREFIX}_${DB_NAME_TEMP}"
    DB_NAME_TESTING="${DB_NAME}_testing"

    [ "$DB_NAME" = "myproject_new_feature" ]
    [ "$DB_NAME_TESTING" = "myproject_new_feature_testing" ]
}

# ハイフン付きプロジェクト名
@test "db name generation: handles hyphenated project name" {
    PROJECT_NAME="my-project"
    DB_PREFIX=$(echo "$PROJECT_NAME" | tr '-' '_')
    DIR_NAME="feature-a"

    DB_NAME_TEMP=$(echo "$DIR_NAME" | tr '/-' '__' | tr '[:upper:]' '[:lower:]')
    DB_NAME="${DB_PREFIX}_${DB_NAME_TEMP}"

    [ "$DB_NAME" = "my_project_feature_a" ]
}

# === DB service detection tests ===
# DBサービス判定のテスト

# PostgreSQLのコンテナ名とコマンド
@test "db service: PostgreSQL container name and command" {
    DB_SERVICE="postgres"
    DB_NAME="myproject_test"

    case "$DB_SERVICE" in
        postgres*)
            SHARED_DB_CONTAINER="shared-postgres"
            DB_DROP_CMD="psql -U root -d postgres -c \"DROP DATABASE IF EXISTS ${DB_NAME};\""
            ;;
        mysql*)
            SHARED_DB_CONTAINER="shared-mysql"
            DB_DROP_CMD="mysql -u root -proot -e \"DROP DATABASE IF EXISTS ${DB_NAME};\""
            ;;
    esac

    [ "$SHARED_DB_CONTAINER" = "shared-postgres" ]
    [[ "$DB_DROP_CMD" == *"psql"* ]]
    [[ "$DB_DROP_CMD" == *"$DB_NAME"* ]]
}

# MySQLのコンテナ名とコマンド
@test "db service: MySQL container name and command" {
    DB_SERVICE="mysql"
    DB_NAME="myproject_test"

    case "$DB_SERVICE" in
        postgres*)
            SHARED_DB_CONTAINER="shared-postgres"
            DB_DROP_CMD="psql -U root -d postgres -c \"DROP DATABASE IF EXISTS ${DB_NAME};\""
            ;;
        mysql*)
            SHARED_DB_CONTAINER="shared-mysql"
            DB_DROP_CMD="mysql -u root -proot -e \"DROP DATABASE IF EXISTS ${DB_NAME};\""
            ;;
    esac

    [ "$SHARED_DB_CONTAINER" = "shared-mysql" ]
    [[ "$DB_DROP_CMD" == *"mysql"* ]]
    [[ "$DB_DROP_CMD" == *"$DB_NAME"* ]]
}

# === Branch name detection tests ===
# ブランチ名検出のテスト

# DIR_NAMEからfeat/プレフィックス付きブランチを検出
@test "branch detection: finds feat/ prefixed branch from DIR_NAME" {
    DIR_NAME="new-feature"
    # シミュレート: git branch --listの出力
    BRANCH_LIST="  main
  feat/new-feature
  feat/other-feature"

    BRANCH_NAME=$(echo "$BRANCH_LIST" | grep -E "feat/${DIR_NAME}|${DIR_NAME}" | head -1 | tr -d ' *')
    [ "$BRANCH_NAME" = "feat/new-feature" ]
}

# DIR_NAMEと同名のブランチを検出
@test "branch detection: finds branch with same name as DIR_NAME" {
    DIR_NAME="main"
    BRANCH_LIST="* main
  feat/new-feature"

    BRANCH_NAME=$(echo "$BRANCH_LIST" | grep -E "feat/${DIR_NAME}|${DIR_NAME}" | head -1 | tr -d ' *')
    [ "$BRANCH_NAME" = "main" ]
}

# === Worktree removal tests ===
# worktree内からの削除テスト

# 削除対象のworktree内から実行した場合、別のworktreeを見つける
@test "worktree removal: finds alternative worktree when run from target" {
    # テスト用ディレクトリ構造を作成
    mkdir -p "$TEST_DIR/project/main"
    mkdir -p "$TEST_DIR/project/feature-a"
    mkdir -p "$TEST_DIR/project/docker-compose-worktree"

    WORKTREE_PATH="$TEST_DIR/project/feature-a"
    WORK_DIR="$TEST_DIR/project/feature-a"  # worktree内から実行
    DIR_NAME="feature-a"

    # WORK_DIRが削除対象と同じかチェック
    WORKTREE_REALPATH=$(realpath "$WORKTREE_PATH")
    WORK_DIR_REALPATH=$(realpath "$WORK_DIR")

    if [ "$WORKTREE_REALPATH" = "$WORK_DIR_REALPATH" ]; then
        # 親ディレクトリの別worktreeを探す
        PARENT_DIR="$(dirname "$WORKTREE_PATH")"
        ALTERNATIVE_DIR=""
        for dir in "$PARENT_DIR"/*/; do
            dir_name=$(basename "$dir")
            if [ "$dir_name" != "$DIR_NAME" ] && [ -d "$dir" ]; then
                ALTERNATIVE_DIR="$dir"
                break
            fi
        done
        [ -n "$ALTERNATIVE_DIR" ]
        [ "$ALTERNATIVE_DIR" = "$TEST_DIR/project/docker-compose-worktree/" ] || [ "$ALTERNATIVE_DIR" = "$TEST_DIR/project/main/" ]
    fi
}

# 別のworktreeから実行した場合、移動不要
@test "worktree removal: no move needed when run from different worktree" {
    mkdir -p "$TEST_DIR/project/main"
    mkdir -p "$TEST_DIR/project/feature-a"
    mkdir -p "$TEST_DIR/project/docker-compose-worktree"

    WORKTREE_PATH="$TEST_DIR/project/feature-a"
    WORK_DIR="$TEST_DIR/project/docker-compose-worktree"  # 別worktreeから実行
    DIR_NAME="feature-a"

    WORKTREE_REALPATH=$(realpath "$WORKTREE_PATH")
    WORK_DIR_REALPATH=$(realpath "$WORK_DIR")

    # 異なるディレクトリなので移動不要
    [ "$WORKTREE_REALPATH" != "$WORK_DIR_REALPATH" ]
}

# 別のworktreeを選択する
@test "worktree removal: selects alternative worktree" {
    # テスト用ディレクトリ構造を作成
    mkdir -p "$TEST_DIR/project/feature-a/.git"
    mkdir -p "$TEST_DIR/project/feature-b/.git"

    DIR_NAME="feature-a"
    PARENT_DIR="$TEST_DIR/project"

    # 別のworktreeを探す（シンプルなロジック）
    ALTERNATIVE_DIR=""
    for dir in "$PARENT_DIR"/*/; do
        dir_name=$(basename "$dir")
        if [ "$dir_name" != "$DIR_NAME" ] && { [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; }; then
            ALTERNATIVE_DIR="$dir"
            break
        fi
    done

    # feature-bが選択されていること
    [ "$ALTERNATIVE_DIR" = "$TEST_DIR/project/feature-b/" ]
}

# === Warning display tests ===
# 削除したworktree内にいる場合の警告テスト

# 削除したworktree内にいた場合に警告が必要
@test "warning display: warning needed when in deleted worktree" {
    mkdir -p "$TEST_DIR/project/feature-a"

    WORKTREE_PATH="$TEST_DIR/project/feature-a"
    WORK_DIR="$TEST_DIR/project/feature-a"  # 同じディレクトリ

    WORKTREE_REALPATH=$(realpath "$WORKTREE_PATH")
    WORK_DIR_REALPATH=$(realpath "$WORK_DIR")

    # 警告が必要な条件
    [ "$WORK_DIR_REALPATH" = "$WORKTREE_REALPATH" ]
}

# 別のworktreeから実行した場合は警告不要
@test "warning display: no warning needed when run from different worktree" {
    mkdir -p "$TEST_DIR/project/feature-a"
    mkdir -p "$TEST_DIR/project/main"

    WORKTREE_PATH="$TEST_DIR/project/feature-a"
    WORK_DIR="$TEST_DIR/project/main"  # 別ディレクトリ

    WORKTREE_REALPATH=$(realpath "$WORKTREE_PATH")
    WORK_DIR_REALPATH=$(realpath "$WORK_DIR")

    # 警告が不要な条件
    [ "$WORK_DIR_REALPATH" != "$WORKTREE_REALPATH" ]
}
