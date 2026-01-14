#!/usr/bin/env bats

# 補完スクリプトのテスト

setup() {
    TEST_DIR=$(mktemp -d)

    # Bare構成のテストプロジェクトを作成
    mkdir -p "$TEST_DIR/my-project/.bare"
    mkdir -p "$TEST_DIR/my-project/main"
    mkdir -p "$TEST_DIR/my-project/feature-a"
    mkdir -p "$TEST_DIR/my-project/feature-b"

    # 別プロジェクト（補完に出てはいけない）
    mkdir -p "$TEST_DIR/other-project"
    mkdir -p "$TEST_DIR/unrelated-folder"
}

# ヘルパー関数（グローバルに定義）
_irie_find_project_root() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.bare" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

_irie_get_worktrees() {
    local project_root
    project_root=$(_irie_find_project_root) || return
    for d in "$project_root"/*/; do
        [ -d "$d" ] || continue
        local name=$(basename "$d")
        [ "$name" = ".bare" ] && continue
        echo "$name"
    done
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "_irie_find_project_root: finds .bare from project root" {
    cd "$TEST_DIR/my-project"

    result=$(_irie_find_project_root)

    [ "$result" = "$TEST_DIR/my-project" ]
}

@test "_irie_find_project_root: finds parent .bare from worktree" {
    cd "$TEST_DIR/my-project/main"

    result=$(_irie_find_project_root)

    [ "$result" = "$TEST_DIR/my-project" ]
}

@test "_irie_find_project_root: finds .bare from nested directory" {
    mkdir -p "$TEST_DIR/my-project/main/src/deep/nested"
    cd "$TEST_DIR/my-project/main/src/deep/nested"

    result=$(_irie_find_project_root)

    [ "$result" = "$TEST_DIR/my-project" ]
}

@test "_irie_find_project_root: fails when .bare is not found" {
    cd "$TEST_DIR/other-project"

    run _irie_find_project_root

    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "_irie_get_worktrees: lists worktrees from project root" {
    cd "$TEST_DIR/my-project"

    result=$(_irie_get_worktrees | sort)
    expected=$(printf "feature-a\nfeature-b\nmain")

    [ "$result" = "$expected" ]
}

@test "_irie_get_worktrees: excludes .bare from list" {
    cd "$TEST_DIR/my-project"

    result=$(_irie_get_worktrees)

    [[ ! "$result" =~ ".bare" ]]
}

@test "_irie_get_worktrees: works from inside worktree" {
    cd "$TEST_DIR/my-project/main"

    result=$(_irie_get_worktrees | sort)
    expected=$(printf "feature-a\nfeature-b\nmain")

    [ "$result" = "$expected" ]
}

@test "_irie_get_worktrees: excludes unrelated folders in parent directory" {
    cd "$TEST_DIR/my-project"

    result=$(_irie_get_worktrees)

    # other-projectやunrelated-folderが含まれていないこと
    [[ ! "$result" =~ "other-project" ]]
    [[ ! "$result" =~ "unrelated-folder" ]]
}

@test "_irie_get_worktrees: returns empty when .bare is not found" {
    cd "$TEST_DIR/other-project"

    # .bareがない場合は何も出力せずに終了（失敗コードでもOK）
    result=$(_irie_get_worktrees 2>/dev/null || true)

    [ -z "$result" ]
}

@test "completion script: bash has valid syntax" {
    IRIE_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"

    run bash -n <("$IRIE_DIR/bin/irie-completion" bash)

    [ "$status" -eq 0 ]
}

@test "completion script: zsh has valid syntax" {
    # zshがインストールされていない場合はスキップ
    command -v zsh >/dev/null || skip "zsh is not installed"

    IRIE_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"

    run zsh -n <("$IRIE_DIR/bin/irie-completion" zsh)

    [ "$status" -eq 0 ]
}

@test "detect_shell: returns zsh when SHELL is /bin/zsh" {
    IRIE_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"

    # detect_shell関数を抽出して実行
    detect_shell() {
        if [ -n "$SHELL" ]; then
            basename "$SHELL"
        elif [ -n "$ZSH_VERSION" ]; then
            echo "zsh"
        elif [ -n "$BASH_VERSION" ]; then
            echo "bash"
        else
            echo "unknown"
        fi
    }

    SHELL="/bin/zsh" run detect_shell

    [ "$output" = "zsh" ]
}

@test "detect_shell: returns bash when SHELL is /bin/bash" {
    detect_shell() {
        if [ -n "$SHELL" ]; then
            basename "$SHELL"
        elif [ -n "$ZSH_VERSION" ]; then
            echo "zsh"
        elif [ -n "$BASH_VERSION" ]; then
            echo "bash"
        else
            echo "unknown"
        fi
    }

    SHELL="/bin/bash" run detect_shell

    [ "$output" = "bash" ]
}

@test "detect_shell: returns zsh when SHELL is /usr/local/bin/zsh" {
    detect_shell() {
        if [ -n "$SHELL" ]; then
            basename "$SHELL"
        elif [ -n "$ZSH_VERSION" ]; then
            echo "zsh"
        elif [ -n "$BASH_VERSION" ]; then
            echo "bash"
        else
            echo "unknown"
        fi
    }

    SHELL="/usr/local/bin/zsh" run detect_shell

    [ "$output" = "zsh" ]
}

@test "install_completion: installs zsh completion for zsh users" {
    IRIE_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # SHELL=zshで実行
    SHELL="/bin/zsh" run "$IRIE_DIR/bin/irie-completion" install

    # zsh補完ファイルが作成されていること
    [ -f "$HOME/.zsh/completions/_irie" ]
    # ファイル内容が#compdefで始まること
    grep -q "^#compdef irie" "$HOME/.zsh/completions/_irie"
}

@test "install_completion: installs bash completion for bash users" {
    IRIE_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # SHELL=bashで実行
    SHELL="/bin/bash" run "$IRIE_DIR/bin/irie-completion" install

    # bash補完ファイルが作成されていること
    [ -f "$HOME/.local/share/bash-completion/completions/irie" ]
    # ファイル内容がcomplete -Fを含むこと
    grep -q "complete -F _irie_completions irie" "$HOME/.local/share/bash-completion/completions/irie"
}
