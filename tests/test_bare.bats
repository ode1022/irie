#!/usr/bin/env bats

# Bareリポジトリ構成のテスト（clone/convert）
# 実行: bats tests/test_bare.bats

IRIE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
source "${IRIE_DIR}/lib/git-helpers.sh"

setup() {
    # テスト用一時ディレクトリ（macOSでは/varが/private/varへのシンボリックリンクなので正規化）
    TEST_TMP_DIR=$(mktemp -d)
    TEST_TMP_DIR=$(cd "$TEST_TMP_DIR" && pwd -P)
    cd "$TEST_TMP_DIR"
}

teardown() {
    # テスト用一時ディレクトリを削除
    cd /tmp
    rm -rf "$TEST_TMP_DIR"
}

# === irie clone tests ===
# irie clone テスト

# ローカルリポジトリをBare構成でクローンできる
@test "irie clone: can clone local repository to bare structure" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test content" > README.md
    git add .
    git commit -m "Initial commit"

    # クローン実行
    cd "$TEST_TMP_DIR"
    run "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" cloned-project
    [ "$status" -eq 0 ]

    # 構成を確認
    [ -d "$TEST_TMP_DIR/cloned-project/.bare" ]
    [ -d "$TEST_TMP_DIR/cloned-project/main" ]
    [ -f "$TEST_TMP_DIR/cloned-project/main/README.md" ]
}

# .bareがBareリポジトリとして構成されている
@test "irie clone: .bare is configured as bare repository" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # .bareがBareリポジトリであることを確認
    run git --git-dir="$TEST_TMP_DIR/test-project/.bare" config --get core.bare
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

# mainワークツリーでgit操作ができる
@test "irie clone: can perform git operations in main worktree" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "original" > file.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # worktree内でgit操作
    cd "$TEST_TMP_DIR/test-project/main"
    run git status
    [ "$status" -eq 0 ]

    run git log --oneline
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Initial"
}

# --no-mainオプションでmainワークツリーを作成しない
@test "irie clone: --no-main option skips main worktree creation" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン（--no-main）
    cd "$TEST_TMP_DIR"
    run "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project --no-main
    [ "$status" -eq 0 ]

    # .bareのみ存在
    [ -d "$TEST_TMP_DIR/test-project/.bare" ]
    [ ! -d "$TEST_TMP_DIR/test-project/main" ]
}

# 既存ディレクトリがある場合はエラー
@test "irie clone: fails if directory already exists" {
    mkdir -p "$TEST_TMP_DIR/existing-dir"

    cd "$TEST_TMP_DIR"
    run "$IRIE_DIR/bin/irie" clone "https://example.com/repo.git" existing-dir
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "既に存在"
}

# === irie convert tests ===
# irie convert テスト

# 通常リポジトリをBare構成に変換できる
@test "irie convert: can convert normal repository to bare structure" {
    # 通常のgitリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/normal-repo"
    cd "$TEST_TMP_DIR/normal-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test content" > README.md
    git add .
    git commit -m "Initial commit"

    # 変換実行
    run "$IRIE_DIR/bin/irie" convert
    [ "$status" -eq 0 ]

    # 構成を確認
    [ -d "$TEST_TMP_DIR/normal-repo/.bare" ]
    [ -d "$TEST_TMP_DIR/normal-repo/main" ]
    [ -f "$TEST_TMP_DIR/normal-repo/main/README.md" ]
    [ ! -d "$TEST_TMP_DIR/normal-repo/.git" ]
}

# 変換後のworktreeでgit操作ができる
@test "irie convert: can perform git operations after conversion" {
    # 通常のgitリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/normal-repo"
    cd "$TEST_TMP_DIR/normal-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "original" > file.txt
    git add .
    git commit -m "Initial"

    # 変換
    "$IRIE_DIR/bin/irie" convert

    # worktree内でgit操作
    cd "$TEST_TMP_DIR/normal-repo/main"
    run git status
    [ "$status" -eq 0 ]

    run git log --oneline
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Initial"
}

# ファイル内容が保持される
@test "irie convert: preserves file contents" {
    # 通常のgitリポジトリを作成（複数ファイル）
    mkdir -p "$TEST_TMP_DIR/normal-repo/src"
    cd "$TEST_TMP_DIR/normal-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "readme content" > README.md
    echo "source code" > src/main.js
    echo "config data" > config.json
    git add .
    git commit -m "Initial"

    # 変換
    "$IRIE_DIR/bin/irie" convert

    # ファイル内容を確認
    [ "$(cat "$TEST_TMP_DIR/normal-repo/main/README.md")" = "readme content" ]
    [ "$(cat "$TEST_TMP_DIR/normal-repo/main/src/main.js")" = "source code" ]
    [ "$(cat "$TEST_TMP_DIR/normal-repo/main/config.json")" = "config data" ]
}

# コミット履歴が保持される
@test "irie convert: preserves commit history" {
    # 複数コミットのリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/normal-repo"
    cd "$TEST_TMP_DIR/normal-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "first" > file.txt
    git add .
    git commit -m "First commit"
    echo "second" > file.txt
    git commit -am "Second commit"
    echo "third" > file.txt
    git commit -am "Third commit"

    # 変換
    "$IRIE_DIR/bin/irie" convert

    # コミット履歴を確認
    cd "$TEST_TMP_DIR/normal-repo/main"
    run git log --oneline
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "First commit"
    echo "$output" | grep -q "Second commit"
    echo "$output" | grep -q "Third commit"
}

# すでにBare構成の場合はエラー
@test "irie convert: fails if already bare structure" {
    # .gitと.bareの両方がある状態を作成（変換途中の状態をシミュレート）
    mkdir -p "$TEST_TMP_DIR/bare-repo/.git"
    mkdir -p "$TEST_TMP_DIR/bare-repo/.bare"
    cd "$TEST_TMP_DIR/bare-repo"

    run "$IRIE_DIR/bin/irie" convert
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "bare構成"
}

# gitリポジトリでない場合はエラー
@test "irie convert: fails if not a git repository" {
    mkdir -p "$TEST_TMP_DIR/not-a-repo"
    cd "$TEST_TMP_DIR/not-a-repo"

    run "$IRIE_DIR/bin/irie" convert
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "gitリポジトリ"
}

# --dry-runで実行せずに内容を表示
@test "irie convert: --dry-run shows plan without executing" {
    # 通常のgitリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/normal-repo"
    cd "$TEST_TMP_DIR/normal-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # dry-run実行
    run "$IRIE_DIR/bin/irie" convert --dry-run
    [ "$status" -eq 0 ]

    # 実際には変換されていない
    [ -d "$TEST_TMP_DIR/normal-repo/.git" ]
    [ ! -d "$TEST_TMP_DIR/normal-repo/.bare" ]
}

# === irie list (Bare structure) tests ===
# irie list (Bare構成) テスト

# Bare構成でworktree一覧を表示できる
@test "irie list: shows worktree list in bare structure" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # worktree内からlist
    cd "$TEST_TMP_DIR/test-project/main"
    run "$IRIE_DIR/bin/irie" list
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "main"
}

# プロジェクトルートからworktree一覧を表示できる
@test "irie list: shows worktree list from project root" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # プロジェクトルートからlist
    cd "$TEST_TMP_DIR/test-project"
    run "$IRIE_DIR/bin/irie" list
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "main"
}

# Bare構成で名前のみ表示
@test "irie list --name: shows only names in bare structure" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    cd "$TEST_TMP_DIR/test-project/main"
    run "$IRIE_DIR/bin/irie" list --name
    [ "$status" -eq 0 ]
    [ "$output" = "main" ]
}

# Bare構成でパスのみ表示
@test "irie list --path: shows only paths in bare structure" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    cd "$TEST_TMP_DIR/test-project/main"
    run "$IRIE_DIR/bin/irie" list --path
    [ "$status" -eq 0 ]
    [ "$output" = "$TEST_TMP_DIR/test-project/main" ]
}

# === Relative path tests (JetBrains IDE + WSL2 support) ===
# 相対パステスト（JetBrains IDE + WSL2対応）
# https://youtrack.jetbrains.com/issue/IJPL-72834
# Git 2.48.0+ では --relative-paths を自動付与、未満では省略

# worktreeの.gitファイルが相対パスで記録される（Git 2.48.0+）
@test "irie clone: worktree .git file uses relative path" {
    if ! git_supports_relative_paths; then
        skip "Git $(git --version) does not support --relative-paths (requires 2.48.0+)"
    fi

    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # .gitファイルが相対パスであることを確認
    local gitdir_content
    gitdir_content=$(cat "$TEST_TMP_DIR/test-project/main/.git")

    # 絶対パス（/で始まる）ではないことを確認
    [[ ! "$gitdir_content" =~ ^gitdir:\ / ]]

    # 相対パスであることを確認
    [[ "$gitdir_content" =~ ^gitdir:\ \.\. ]]
}

# convert後もworktreeの.gitファイルが相対パスで記録される（Git 2.48.0+）
@test "irie convert: worktree .git file uses relative path" {
    if ! git_supports_relative_paths; then
        skip "Git $(git --version) does not support --relative-paths (requires 2.48.0+)"
    fi

    # 通常のgitリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/normal-repo"
    cd "$TEST_TMP_DIR/normal-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # 変換
    "$IRIE_DIR/bin/irie" convert

    # .gitファイルが相対パスであることを確認
    local gitdir_content
    gitdir_content=$(cat "$TEST_TMP_DIR/normal-repo/main/.git")

    # 絶対パス（/で始まる）ではないことを確認
    [[ ! "$gitdir_content" =~ ^gitdir:\ / ]]

    # 相対パスであることを確認
    [[ "$gitdir_content" =~ ^gitdir:\ \.\. ]]
}

# .bare/worktrees/xxx/gitdirも相対パスで記録される（Git 2.48.0+）
@test "irie clone: .bare/worktrees/xxx/gitdir uses relative path" {
    if ! git_supports_relative_paths; then
        skip "Git $(git --version) does not support --relative-paths (requires 2.48.0+)"
    fi

    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # gitdirファイルが相対パスであることを確認
    local gitdir_content
    gitdir_content=$(cat "$TEST_TMP_DIR/test-project/.bare/worktrees/main/gitdir")

    # 絶対パス（/で始まる）ではないことを確認
    [[ ! "$gitdir_content" =~ ^/ ]]

    # 相対パスであることを確認
    [[ "$gitdir_content" =~ ^\.\. ]]
}

# === Old Git fallback tests (--relative-paths unavailable) ===
# 古いGit（2.48.0未満）では --relative-paths なしで動作し、絶対パスになる

# 古いGitを偽装するラッパーを作成するヘルパー
_create_old_git_wrapper() {
    local wrapper_dir="$TEST_TMP_DIR/fake-old-git"
    local real_git
    real_git=$(command -v git)
    mkdir -p "$wrapper_dir"
    cat > "$wrapper_dir/git" << WRAPPER
#!/bin/bash
if [ "\$1" = "--version" ]; then
    echo "git version 2.39.5"
    exit 0
fi
for arg in "\$@"; do
    if [ "\$arg" = "--relative-paths" ]; then
        echo "ERROR: --relative-paths should not be passed to old git" >&2
        exit 128
    fi
done
exec "$real_git" "\$@"
WRAPPER
    chmod +x "$wrapper_dir/git"
    echo "$wrapper_dir"
}

# 古いGitでirie cloneが成功し、絶対パスになる
@test "old git: irie clone uses absolute paths when git < 2.48.0" {
    local wrapper_dir
    wrapper_dir=$(_create_old_git_wrapper)

    # ソースリポジトリを作成（本物のgitで）
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # 偽装gitでクローン
    cd "$TEST_TMP_DIR"
    PATH="$wrapper_dir:$PATH" run "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project
    [ "$status" -eq 0 ]

    # .gitファイルが絶対パスであることを確認
    local gitdir_content
    gitdir_content=$(cat "$TEST_TMP_DIR/test-project/main/.git")
    [[ "$gitdir_content" =~ ^gitdir:\ / ]]
}

# 古いGitでirie addが成功し、絶対パスになる
@test "old git: irie add uses absolute paths when git < 2.48.0" {
    local wrapper_dir
    wrapper_dir=$(_create_old_git_wrapper)

    # ソースリポジトリを作成（本物のgitで）
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # 偽装gitでクローン＋add
    cd "$TEST_TMP_DIR"
    PATH="$wrapper_dir:$PATH" "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    cd "$TEST_TMP_DIR/test-project/main"
    PATH="$wrapper_dir:$PATH" run "$IRIE_DIR/bin/irie" add feat/test-feature
    [ "$status" -eq 0 ]

    # .gitファイルが絶対パスであることを確認
    local gitdir_content
    gitdir_content=$(cat "$TEST_TMP_DIR/test-project/test-feature/.git")
    [[ "$gitdir_content" =~ ^gitdir:\ / ]]
}

# 古いGitでirie convertが成功し、絶対パスになる
@test "old git: irie convert uses absolute paths when git < 2.48.0" {
    local wrapper_dir
    wrapper_dir=$(_create_old_git_wrapper)

    # 通常のgitリポジトリを作成（本物のgitで）
    mkdir -p "$TEST_TMP_DIR/normal-repo"
    cd "$TEST_TMP_DIR/normal-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # 偽装gitでconvert
    PATH="$wrapper_dir:$PATH" run "$IRIE_DIR/bin/irie" convert
    [ "$status" -eq 0 ]

    # .gitファイルが絶対パスであることを確認
    local gitdir_content
    gitdir_content=$(cat "$TEST_TMP_DIR/normal-repo/main/.git")
    [[ "$gitdir_content" =~ ^gitdir:\ / ]]
}

# === irie remove tests ===
# irie remove テスト

# 現在のworktreeを削除できる
@test "irie remove .: can remove current worktree" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # feature-1 worktreeを作成
    cd "$TEST_TMP_DIR/test-project/.bare"
    git_worktree_add ../feature-1 -b feature-1 main

    # feature-1に移動して削除
    cd "$TEST_TMP_DIR/test-project/feature-1"
    run "$IRIE_DIR/bin/irie" remove . --force     [ "$status" -eq 0 ]

    # 削除されたことを確認
    [ ! -d "$TEST_TMP_DIR/test-project/feature-1" ]
}

# mainは削除できない
@test "irie remove .: cannot remove main worktree" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # mainに移動して削除しようとする
    cd "$TEST_TMP_DIR/test-project/main"
    run "$IRIE_DIR/bin/irie" remove . --force
    [ "$status" -ne 0 ]
    echo "$output" | grep -qi "main.*削除できません"
}

# 削除したworktree内にいた場合、プロジェクトルートパスをstdoutに出力
@test "irie remove: outputs project root path when in deleted worktree" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # feature-1 worktreeを作成
    cd "$TEST_TMP_DIR/test-project/.bare"
    git_worktree_add ../feature-1 -b feature-1 main

    # feature-1に移動して削除
    cd "$TEST_TMP_DIR/test-project/feature-1"
    run "$IRIE_DIR/bin/irie" remove . --force
    [ "$status" -eq 0 ]

    # プロジェクトルートパスがstdoutに出力されることを確認
    echo "$output" | grep -q "test-project$"
}

# === Multiple worktree tests ===
# 複数worktreeテスト

# 複数のworktreeを管理できる
@test "bare structure: can manage multiple worktrees" {
    # ソースリポジトリを作成
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add .
    git commit -m "Initial"

    # クローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # 追加のworktreeを作成
    cd "$TEST_TMP_DIR/test-project"
    git --git-dir=.bare branch feature-1 main
    git --git-dir=.bare worktree add feature-1 feature-1

    git --git-dir=.bare branch feature-2 main
    git --git-dir=.bare worktree add feature-2 feature-2

    # worktree一覧を確認
    run "$IRIE_DIR/bin/irie" list --name
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "main"
    echo "$output" | grep -q "feature-1"
    echo "$output" | grep -q "feature-2"
}

# === irie add without Docker tests ===
# Dockerなしでのirie addテスト

# Dockerなしプロジェクトでworktreeを作成できる
@test "irie add: can create worktree in project without Docker" {
    # ソースリポジトリを作成（docker-compose.yamlなし）
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test content" > README.md
    git add .
    git commit -m "Initial commit"

    # Bare構成でクローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # worktreeを作成（Dockerなし）
    cd "$TEST_TMP_DIR/test-project/main"
    run "$IRIE_DIR/bin/irie" add feature-1
    [ "$status" -eq 0 ]

    # worktreeが作成されていることを確認
    [ -d "$TEST_TMP_DIR/test-project/feature-1" ]
    [ -f "$TEST_TMP_DIR/test-project/feature-1/README.md" ]

    # スキップメッセージが出力されていることを確認
    echo "$output" | grep -q "テンプレートなし"
    echo "$output" | grep -q "docker-compose.yamlなし"
}

# Dockerなしプロジェクトでworktreeを削除できる
@test "irie remove: can remove worktree in project without Docker" {
    # ソースリポジトリを作成（docker-compose.yamlなし）
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test content" > README.md
    git add .
    git commit -m "Initial commit"

    # Bare構成でクローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # worktreeを作成
    cd "$TEST_TMP_DIR/test-project/main"
    "$IRIE_DIR/bin/irie" add feature-1

    # worktreeを削除
    cd "$TEST_TMP_DIR/test-project/feature-1"
    run "$IRIE_DIR/bin/irie" remove . --force
    [ "$status" -eq 0 ]

    # worktreeが削除されていることを確認
    [ ! -d "$TEST_TMP_DIR/test-project/feature-1" ]

    # スキップメッセージが出力されていることを確認
    echo "$output" | grep -q "docker-compose.yamlが見つかりません"
}

# Dockerなしプロジェクトで情報を表示できる
@test "irie info: shows info in project without Docker" {
    # ソースリポジトリを作成（docker-compose.yamlなし）
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test content" > README.md
    git add .
    git commit -m "Initial commit"

    # Bare構成でクローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # mainで情報を表示
    cd "$TEST_TMP_DIR/test-project/main"
    run "$IRIE_DIR/bin/irie" info
    [ "$status" -eq 0 ]

    # 基本情報が表示されることを確認（カラーコードを除去して検索）
    echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "ディレクトリ: main"
    echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "ブランチ: main"
    # URL情報が表示されることを確認（Traefik方式固定）
    echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "URL:"
}

# Dockerなしプロジェクトでworktreeを開ける
@test "irie open: works in project without Docker" {
    # ソースリポジトリを作成（docker-compose.yamlなし）
    mkdir -p "$TEST_TMP_DIR/source-repo"
    cd "$TEST_TMP_DIR/source-repo"
    git init -b main
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test content" > README.md
    git add .
    git commit -m "Initial commit"

    # Bare構成でクローン
    cd "$TEST_TMP_DIR"
    "$IRIE_DIR/bin/irie" clone "$TEST_TMP_DIR/source-repo" test-project

    # エディタが見つからない場合のテスト（--dry-runがないので--helpで代用）
    cd "$TEST_TMP_DIR/test-project/main"
    run "$IRIE_DIR/bin/irie" open --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "irie open"
}
