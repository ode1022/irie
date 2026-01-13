#!/usr/bin/env bats

# git-helpers.sh のテスト
# 実行: bats tests/test_git_helpers.bats

# IRIE_LIB_DIRが環境変数で設定されていない場合のみデフォルト値を使用
if [ -z "$IRIE_LIB_DIR" ]; then
    IRIE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    IRIE_LIB_DIR="${IRIE_DIR}/lib"
fi

setup() {
    # テスト用一時ディレクトリ（macOSでは/varが/private/varへのシンボリックリンクなので正規化）
    TEST_TMP_DIR=$(mktemp -d)
    TEST_TMP_DIR=$(cd "$TEST_TMP_DIR" && pwd -P)
}

teardown() {
    # テスト用一時ディレクトリを削除
    rm -rf "$TEST_TMP_DIR"
}

# === find_bare_dir tests ===
# find_bare_dir のテスト

# .bareディレクトリがある場合に検出できる
@test "find_bare_dir: detects .bare directory when present" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    # Bare構成を作成
    mkdir -p "$TEST_TMP_DIR/project/.bare"
    mkdir -p "$TEST_TMP_DIR/project/main"

    result=$(find_bare_dir "$TEST_TMP_DIR/project")
    [ "$result" = "$TEST_TMP_DIR/project/.bare" ]
}

# worktree内から親の.bareを検出できる
@test "find_bare_dir: detects parent .bare from within worktree" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    # Bare構成を作成
    mkdir -p "$TEST_TMP_DIR/project/.bare"
    mkdir -p "$TEST_TMP_DIR/project/main/src"

    result=$(find_bare_dir "$TEST_TMP_DIR/project/main/src")
    [ "$result" = "$TEST_TMP_DIR/project/.bare" ]
}

# .bareがない場合は空を返す
@test "find_bare_dir: returns empty when .bare not found" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    mkdir -p "$TEST_TMP_DIR/project"

    run find_bare_dir "$TEST_TMP_DIR/project"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

# === find_project_root tests ===
# find_project_root のテスト

# .bareの親ディレクトリを返す
@test "find_project_root: returns parent directory of .bare" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    mkdir -p "$TEST_TMP_DIR/project/.bare"
    mkdir -p "$TEST_TMP_DIR/project/main"

    result=$(find_project_root "$TEST_TMP_DIR/project/main")
    [ "$result" = "$TEST_TMP_DIR/project" ]
}

# .bareがない場合は失敗
@test "find_project_root: fails when .bare not found" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    mkdir -p "$TEST_TMP_DIR/project"

    run find_project_root "$TEST_TMP_DIR/project"
    [ "$status" -eq 1 ]
}

# === is_bare_structure tests ===
# is_bare_structure のテスト

# Bare構成の場合はtrue
@test "is_bare_structure: returns true for bare structure" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    mkdir -p "$TEST_TMP_DIR/project/.bare"

    run is_bare_structure "$TEST_TMP_DIR/project"
    [ "$status" -eq 0 ]
}

# 通常構成の場合はfalse
@test "is_bare_structure: returns false for normal structure" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    mkdir -p "$TEST_TMP_DIR/project/.git"

    run is_bare_structure "$TEST_TMP_DIR/project"
    [ "$status" -eq 1 ]
}

# === get_git_dir tests ===
# get_git_dir のテスト

# Bare構成で.bareを返す
@test "get_git_dir: returns .bare for bare structure" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    mkdir -p "$TEST_TMP_DIR/project/.bare"

    result=$(get_git_dir "$TEST_TMP_DIR/project")
    [ "$result" = "$TEST_TMP_DIR/project/.bare" ]
}

# 通常のgitリポジトリで.gitを返す
@test "get_git_dir: returns .git for normal repository" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    # 通常のgitリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/project"
    cd "$TEST_TMP_DIR/project"
    git init -q

    result=$(get_git_dir "$TEST_TMP_DIR/project")
    [ "$result" = "$TEST_TMP_DIR/project/.git" ]
}

# === list_worktrees tests ===
# list_worktrees のテスト

# Bare構成のworktree一覧を取得できる
@test "list_worktrees: can get worktree list in bare structure" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    # Bareリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/project"
    cd "$TEST_TMP_DIR/project"
    git init --bare .bare
    git --git-dir=.bare config user.email "test@example.com"
    git --git-dir=.bare config user.name "Test User"

    # 最初のコミットを作成（空のツリー）
    TREE=$(git --git-dir=.bare hash-object -t tree /dev/null)
    COMMIT=$(echo "Initial commit" | git --git-dir=.bare commit-tree $TREE)
    git --git-dir=.bare update-ref refs/heads/main $COMMIT

    # worktreeを追加
    git --git-dir=.bare worktree add main main

    result=$(list_worktrees "$TEST_TMP_DIR/project")

    # mainが含まれていることを確認
    echo "$result" | grep -q "main"
}

# bare自体は出力に含まれない
@test "list_worktrees: excludes bare itself from output" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    # Bareリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/project"
    cd "$TEST_TMP_DIR/project"
    git init --bare .bare
    git --git-dir=.bare config user.email "test@example.com"
    git --git-dir=.bare config user.name "Test User"

    # 最初のコミットを作成
    TREE=$(git --git-dir=.bare hash-object -t tree /dev/null)
    COMMIT=$(echo "Initial commit" | git --git-dir=.bare commit-tree $TREE)
    git --git-dir=.bare update-ref refs/heads/main $COMMIT

    # worktreeを追加
    git --git-dir=.bare worktree add main main

    result=$(list_worktrees "$TEST_TMP_DIR/project")

    # .bareが含まれていないことを確認
    ! echo "$result" | grep -q "\.bare"
}

# === list_worktree_paths tests ===
# list_worktree_paths のテスト

# worktreeのパス一覧を取得できる
@test "list_worktree_paths: can get worktree path list" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    # Bareリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/project"
    cd "$TEST_TMP_DIR/project"
    git init --bare .bare
    git --git-dir=.bare config user.email "test@example.com"
    git --git-dir=.bare config user.name "Test User"

    # 最初のコミットを作成
    TREE=$(git --git-dir=.bare hash-object -t tree /dev/null)
    COMMIT=$(echo "Initial commit" | git --git-dir=.bare commit-tree $TREE)
    git --git-dir=.bare update-ref refs/heads/main $COMMIT

    # worktreeを追加
    git --git-dir=.bare worktree add main main

    result=$(list_worktree_paths "$TEST_TMP_DIR/project")

    [ "$result" = "$TEST_TMP_DIR/project/main" ]
}

# === list_worktree_names tests ===
# list_worktree_names のテスト

# worktreeのディレクトリ名のみ取得できる
@test "list_worktree_names: can get only directory names" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    # Bareリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/project"
    cd "$TEST_TMP_DIR/project"
    git init --bare .bare
    git --git-dir=.bare config user.email "test@example.com"
    git --git-dir=.bare config user.name "Test User"

    # 最初のコミットを作成
    TREE=$(git --git-dir=.bare hash-object -t tree /dev/null)
    COMMIT=$(echo "Initial commit" | git --git-dir=.bare commit-tree $TREE)
    git --git-dir=.bare update-ref refs/heads/main $COMMIT

    # worktreeを追加
    git --git-dir=.bare worktree add main main

    result=$(list_worktree_names "$TEST_TMP_DIR/project")

    [ "$result" = "main" ]
}

# === git_cmd tests ===
# git_cmd のテスト

# Bare構成でgitコマンドを実行できる
@test "git_cmd: can execute git commands in bare structure" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    # Bareリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/project"
    cd "$TEST_TMP_DIR/project"
    git init --bare .bare
    git --git-dir=.bare config user.email "test@example.com"

    # git_cmdでconfig値を取得
    result=$(git_cmd config --get user.email)
    [ "$result" = "test@example.com" ]
}

# === Color variable tests ===
# カラー変数のテスト

# git-helpers.shでカラー変数が定義される
@test "color variables: git-helpers.sh defines color variables" {
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    [ -n "$BLUE" ]
    [ -n "$GREEN" ]
    [ -n "$YELLOW" ]
    [ -n "$RED" ]
    [ -n "$NC" ]
}

# 既存の値を上書きしない
@test "color variables: does not override existing values" {
    export BLUE="custom_blue"
    source "${IRIE_LIB_DIR}/git-helpers.sh"

    [ "$BLUE" = "custom_blue" ]
}
