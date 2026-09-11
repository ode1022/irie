#!/usr/bin/env bats

# editors.sh のテスト
# 実行: bats tests/test_editors.bats

# IRIE_LIB_DIRが環境変数で設定されていない場合のみデフォルト値を使用
if [ -z "$IRIE_LIB_DIR" ]; then
    IRIE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    IRIE_LIB_DIR="${IRIE_DIR}/lib"
fi

setup() {
    # テスト用一時ディレクトリ（macOSでは/varが/private/varへのシンボリックリンクなので正規化）
    TEST_TMP_DIR=$(mktemp -d)
    TEST_TMP_DIR=$(cd "$TEST_TMP_DIR" && pwd -P)

    # Windows側のインストール先を模したディレクトリ
    PROGRAM_FILES="$TEST_TMP_DIR/Program Files/JetBrains"
    LOCAL_PROGRAMS="$TEST_TMP_DIR/Users/user/AppData/Local/Programs"
    mkdir -p "$PROGRAM_FILES" "$LOCAL_PROGRAMS"

    source "${IRIE_LIB_DIR}/editors.sh"
}

teardown() {
    rm -rf "$TEST_TMP_DIR"
}

# IDEのインストール済みフォルダを作る
# 引数: 親ディレクトリ フォルダ名 [実行ファイル名]
create_ide() {
    local parent="$1"
    local folder="$2"
    local exe="${3:-phpstorm64.exe}"
    mkdir -p "$parent/$folder/bin"
    touch "$parent/$folder/bin/$exe"
}

# === jetbrains_folder_version ===

# フォルダ名末尾のバージョンを取り出す
@test "jetbrains_folder_version: バージョン付きフォルダ名からバージョンを取り出す" {
    run jetbrains_folder_version "PhpStorm 2026.2.2"
    [ "$status" -eq 0 ]
    [ "$output" = "2026.2.2" ]
}

# バージョンが付かないフォルダ名は0扱い
@test "jetbrains_folder_version: バージョンが無い場合は0を返す" {
    run jetbrains_folder_version "PhpStorm"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

# === detect_wsl_jetbrains ===

# Program Files 配下のみの場合でも検出できる（従来の動作）
@test "detect_wsl_jetbrains: Program Files 配下を検出する" {
    create_ide "$PROGRAM_FILES" "PhpStorm 2025.2.6"

    IRIE_JETBRAINS_ROOTS="$PROGRAM_FILES:$LOCAL_PROGRAMS" run detect_wsl_jetbrains
    [ "$status" -eq 0 ]
    [ "$output" = "phpstorm:PhpStorm:$PROGRAM_FILES/PhpStorm 2025.2.6/bin/phpstorm64.exe" ]
}

# ユーザー単位インストール（AppData\Local\Programs）も検出できる
@test "detect_wsl_jetbrains: AppData\\Local\\Programs 配下を検出する" {
    create_ide "$LOCAL_PROGRAMS" "PhpStorm 2026.2.2"

    IRIE_JETBRAINS_ROOTS="$PROGRAM_FILES:$LOCAL_PROGRAMS" run detect_wsl_jetbrains
    [ "$status" -eq 0 ]
    [ "$output" = "phpstorm:PhpStorm:$LOCAL_PROGRAMS/PhpStorm 2026.2.2/bin/phpstorm64.exe" ]
}

# インストール先が違っても、バージョンが新しい方が選ばれる
@test "detect_wsl_jetbrains: インストール先をまたいで最新バージョンを選ぶ" {
    create_ide "$PROGRAM_FILES" "PhpStorm 2023.2.2"
    create_ide "$PROGRAM_FILES" "PhpStorm 2025.2.6"
    create_ide "$LOCAL_PROGRAMS" "PhpStorm 2026.2.2"

    IRIE_JETBRAINS_ROOTS="$PROGRAM_FILES:$LOCAL_PROGRAMS" run detect_wsl_jetbrains
    [ "$status" -eq 0 ]
    [ "$output" = "phpstorm:PhpStorm:$LOCAL_PROGRAMS/PhpStorm 2026.2.2/bin/phpstorm64.exe" ]
}

# 古いバージョンがユーザー単位インストール側にあっても、新しい方（Program Files側）が選ばれる
@test "detect_wsl_jetbrains: ユーザー単位インストールが古い場合はProgram Files側を選ぶ" {
    create_ide "$PROGRAM_FILES" "PhpStorm 2026.2.2"
    create_ide "$LOCAL_PROGRAMS" "PhpStorm 2025.2.6"

    IRIE_JETBRAINS_ROOTS="$PROGRAM_FILES:$LOCAL_PROGRAMS" run detect_wsl_jetbrains
    [ "$status" -eq 0 ]
    [ "$output" = "phpstorm:PhpStorm:$PROGRAM_FILES/PhpStorm 2026.2.2/bin/phpstorm64.exe" ]
}

# 実行ファイルが無いフォルダは候補にしない
@test "detect_wsl_jetbrains: 実行ファイルが無いフォルダは無視する" {
    create_ide "$PROGRAM_FILES" "PhpStorm 2025.2.6"
    mkdir -p "$LOCAL_PROGRAMS/PhpStorm 2026.2.2/bin"

    IRIE_JETBRAINS_ROOTS="$PROGRAM_FILES:$LOCAL_PROGRAMS" run detect_wsl_jetbrains
    [ "$status" -eq 0 ]
    [ "$output" = "phpstorm:PhpStorm:$PROGRAM_FILES/PhpStorm 2025.2.6/bin/phpstorm64.exe" ]
}

# 存在しない検索ルートが混ざっていてもエラーにしない
@test "detect_wsl_jetbrains: 存在しない検索ルートは無視する" {
    create_ide "$LOCAL_PROGRAMS" "PhpStorm 2026.2.2"

    IRIE_JETBRAINS_ROOTS="$TEST_TMP_DIR/not-exists:$LOCAL_PROGRAMS" run detect_wsl_jetbrains
    [ "$status" -eq 0 ]
    [ "$output" = "phpstorm:PhpStorm:$LOCAL_PROGRAMS/PhpStorm 2026.2.2/bin/phpstorm64.exe" ]
}

# IDEが1つも無い場合は何も出力しない
@test "detect_wsl_jetbrains: 未インストールなら何も出力しない" {
    IRIE_JETBRAINS_ROOTS="$PROGRAM_FILES:$LOCAL_PROGRAMS" run detect_wsl_jetbrains
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# 複数種類のIDEをそれぞれ検出する
@test "detect_wsl_jetbrains: 複数のIDEをそれぞれ検出する" {
    create_ide "$PROGRAM_FILES" "DataGrip 2025.1.3" "datagrip64.exe"
    create_ide "$LOCAL_PROGRAMS" "PhpStorm 2026.2.2"

    IRIE_JETBRAINS_ROOTS="$PROGRAM_FILES:$LOCAL_PROGRAMS" run detect_wsl_jetbrains
    [ "$status" -eq 0 ]
    [[ "$output" == *"phpstorm:PhpStorm:$LOCAL_PROGRAMS/PhpStorm 2026.2.2/bin/phpstorm64.exe"* ]]
    [[ "$output" == *"datagrip:DataGrip:$PROGRAM_FILES/DataGrip 2025.1.3/bin/datagrip64.exe"* ]]
}
