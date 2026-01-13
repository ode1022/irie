#!/usr/bin/env bats

# helpers.sh のテスト
# 実行: bats tests/test_helpers.bats

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

# === Color variable tests ===
# カラー変数のテスト

# BLUEにシングルクォートが含まれていない
@test "color variables: BLUE does not contain single quotes" {
    source "${IRIE_LIB_DIR}/helpers.sh"
    # シングルクォートがリテラルとして含まれていないことを確認
    # バグ: : "${BLUE:='\033[0;34m'}" だとシングルクォートが含まれてしまう
    [[ "$BLUE" != *"'"* ]]
}

# GREENにシングルクォートが含まれていない
@test "color variables: GREEN does not contain single quotes" {
    source "${IRIE_LIB_DIR}/helpers.sh"
    [[ "$GREEN" != *"'"* ]]
}

# YELLOWにシングルクォートが含まれていない
@test "color variables: YELLOW does not contain single quotes" {
    source "${IRIE_LIB_DIR}/helpers.sh"
    [[ "$YELLOW" != *"'"* ]]
}

# NCにシングルクォートが含まれていない
@test "color variables: NC does not contain single quotes" {
    source "${IRIE_LIB_DIR}/helpers.sh"
    [[ "$NC" != *"'"* ]]
}

# echo -eで正しく色が出力される（制御文字が含まれる）
@test "color variables: echo -e outputs colors correctly with control characters" {
    source "${IRIE_LIB_DIR}/helpers.sh"
    # echo -e で出力した際にエスケープシーケンスが展開されることを確認
    output=$(echo -e "${BLUE}test${NC}")
    # 出力に制御文字が含まれていることを確認（\033 = \x1b = ESC）
    # バグがあると '\033[' のようにリテラルが出力される
    [[ "$output" == *$'\033['* ]] || [[ "$output" == *$'\x1b['* ]]
}

# 既存の値がある場合は上書きしない
@test "color variables: does not override existing values" {
    export BLUE="custom_blue"
    source "${IRIE_LIB_DIR}/helpers.sh"
    [ "$BLUE" = "custom_blue" ]
}

# === copy_if_exists tests ===
# copy_if_exists のテスト

# 存在するファイルをコピーできる
@test "copy_if_exists: can copy existing file" {
    source "${IRIE_LIB_DIR}/helpers.sh"

    # テストファイル作成
    echo "test content" > "${TEST_TMP_DIR}/source.txt"

    copy_if_exists "${TEST_TMP_DIR}/source.txt" "${TEST_TMP_DIR}/dest.txt"

    [ -f "${TEST_TMP_DIR}/dest.txt" ]
    [ "$(cat "${TEST_TMP_DIR}/dest.txt")" = "test content" ]
}

# 存在しないファイルでもエラーにならない
@test "copy_if_exists: no error for non-existent file" {
    source "${IRIE_LIB_DIR}/helpers.sh"

    # copy_if_existsを呼び出し、戻り値が0であることを確認
    copy_if_exists "${TEST_TMP_DIR}/nonexistent.txt" "${TEST_TMP_DIR}/dest.txt"
    result=$?

    [ "$result" -eq 0 ]
    [ ! -f "${TEST_TMP_DIR}/dest.txt" ]
}

# 戻り値が常に0（set -e互換）
@test "copy_if_exists: always returns 0 (set -e compatible)" {
    source "${IRIE_LIB_DIR}/helpers.sh"

    # 存在しないファイルの場合でも戻り値が0であることを確認
    # バグ: return 1 があると set -e 環境でスクリプトが終了する
    copy_if_exists "${TEST_TMP_DIR}/nonexistent.txt" "${TEST_TMP_DIR}/dest.txt"
    [ $? -eq 0 ]
}

# set -e環境でファイルが存在しない場合でも継続する
@test "copy_if_exists: continues in set -e environment when file missing" {
    # 別スクリプトファイルを作成して実行（set -eの挙動を正確にテスト）
    cat > "${TEST_TMP_DIR}/test_script.sh" << EOF
#!/bin/bash
set -e
source '${IRIE_LIB_DIR}/helpers.sh'
copy_if_exists '${TEST_TMP_DIR}/nonexistent.txt' '${TEST_TMP_DIR}/dest.txt'
echo 'reached_end'
EOF
    chmod +x "${TEST_TMP_DIR}/test_script.sh"

    # スクリプトを実行
    run "${TEST_TMP_DIR}/test_script.sh"

    # スクリプトが最後まで実行されたことを確認
    [ "$status" -eq 0 ]
    [[ "$output" == *"reached_end"* ]]
}

# === sed_inplace tests ===
# sed_inplace のテスト

# ファイルを正しく置換できる
@test "sed_inplace: can replace file content correctly" {
    source "${IRIE_LIB_DIR}/helpers.sh"

    # テストファイル作成
    echo "DB_HOST=localhost" > "${TEST_TMP_DIR}/test.env"

    sed_inplace "s/^DB_HOST=.*/DB_HOST=shared-postgres/" "${TEST_TMP_DIR}/test.env"

    [ "$(cat "${TEST_TMP_DIR}/test.env")" = "DB_HOST=shared-postgres" ]
}

# 複数行のファイルで特定行のみ置換
@test "sed_inplace: replaces only specific line in multi-line file" {
    source "${IRIE_LIB_DIR}/helpers.sh"

    # テストファイル作成
    cat > "${TEST_TMP_DIR}/test.env" << 'EOF'
DB_HOST=localhost
DB_PORT=5432
DB_DATABASE=mydb
EOF

    sed_inplace "s/^DB_DATABASE=.*/DB_DATABASE=newdb/" "${TEST_TMP_DIR}/test.env"

    grep -q "^DB_DATABASE=newdb$" "${TEST_TMP_DIR}/test.env"
    grep -q "^DB_HOST=localhost$" "${TEST_TMP_DIR}/test.env"
    grep -q "^DB_PORT=5432$" "${TEST_TMP_DIR}/test.env"
}

# === wait_for_postgres tests (mock) ===
# wait_for_postgres のテスト（モック）

# 関数が定義されている
@test "wait_for_postgres: function is defined" {
    source "${IRIE_LIB_DIR}/helpers.sh"
    declare -f wait_for_postgres > /dev/null
}

# 引数なしでエラー出力
@test "wait_for_postgres: errors with no arguments" {
    source "${IRIE_LIB_DIR}/helpers.sh"

    # macOSではtimeoutコマンドがないためスキップ
    if [[ "$OSTYPE" == "darwin"* ]] && ! command -v timeout &>/dev/null; then
        skip "timeout command not available on macOS (install with: brew install coreutils)"
    fi

    # dockerコマンドが失敗するのでタイムアウト（短縮版でテスト）
    # 実際のDockerテストは統合テストで行う
    run -127 timeout 2 bash -c "
        source '${IRIE_LIB_DIR}/helpers.sh'
        wait_for_postgres 'nonexistent-container' 2>/dev/null
    " || true

    # タイムアウトまたはエラーで終了することを確認
    [ "$status" -ne 0 ] || [ "$status" -eq 124 ]
}

# === wait_for_mysql tests (mock) ===
# wait_for_mysql のテスト（モック）

# 関数が定義されている
@test "wait_for_mysql: function is defined" {
    source "${IRIE_LIB_DIR}/helpers.sh"
    declare -f wait_for_mysql > /dev/null
}

# === Combined helper function tests ===
# ヘルパー関数の組み合わせテスト

# post-setup.shパターンが動作する
@test "combined: post-setup.sh pattern works" {
    source "${IRIE_LIB_DIR}/helpers.sh"

    # テスト用の.envファイル作成
    cat > "${TEST_TMP_DIR}/.env" << 'EOF'
DB_HOST=localhost
DB_DATABASE=original_db
EOF

    # 共有DBの典型的なパターン
    DB_CONTAINER="shared-postgres"
    WORKTREE_DB_NAME="myproject_feature"

    sed_inplace "s/^DB_HOST=.*/DB_HOST=${DB_CONTAINER}/" "${TEST_TMP_DIR}/.env"
    sed_inplace "s/^DB_DATABASE=.*/DB_DATABASE=${WORKTREE_DB_NAME}/" "${TEST_TMP_DIR}/.env"

    grep -q "^DB_HOST=shared-postgres$" "${TEST_TMP_DIR}/.env"
    grep -q "^DB_DATABASE=myproject_feature$" "${TEST_TMP_DIR}/.env"
}
