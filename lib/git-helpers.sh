#!/bin/bash
# irie Git ヘルパー関数
# Bareリポジトリ検出、git-dir取得などの共通処理

# カラー出力用（未定義の場合のみ設定）
BLUE=${BLUE:-$'\033[0;34m'}
GREEN=${GREEN:-$'\033[0;32m'}
YELLOW=${YELLOW:-$'\033[1;33m'}
RED=${RED:-$'\033[0;31m'}
NC=${NC:-$'\033[0m'}

# .bare ディレクトリを探す
# カレントディレクトリから親方向に探索
# 戻り値: .bare のフルパス、見つからない場合は空
find_bare_dir() {
    local dir="${1:-$(pwd)}"

    # 絶対パスに変換
    dir=$(cd "$dir" 2>/dev/null && pwd)

    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.bare" ]; then
            echo "$dir/.bare"
            return 0
        fi
        dir=$(dirname "$dir")
    done

    return 1
}

# プロジェクトルートを取得（.bareの親ディレクトリ）
# 戻り値: プロジェクトルートのフルパス
find_project_root() {
    local bare_dir
    bare_dir=$(find_bare_dir "$1")

    if [ -n "$bare_dir" ]; then
        dirname "$bare_dir"
    else
        return 1
    fi
}

# git-dir を取得
# .bare があればそれを使用、なければ通常の .git を探す
# 戻り値: git-dir のパス
get_git_dir() {
    local dir="${1:-$(pwd)}"

    # .bare を探す
    local bare_dir
    bare_dir=$(find_bare_dir "$dir")

    if [ -n "$bare_dir" ]; then
        echo "$bare_dir"
        return 0
    fi

    # 通常の git リポジトリを探す
    local git_dir
    git_dir=$(cd "$dir" 2>/dev/null && git rev-parse --git-dir 2>/dev/null)

    if [ -n "$git_dir" ]; then
        # 相対パスの場合は絶対パスに変換
        if [[ "$git_dir" != /* ]]; then
            git_dir="$(cd "$dir" && cd "$git_dir" && pwd)"
        fi
        echo "$git_dir"
        return 0
    fi

    return 1
}

# Bareリポジトリ構成かどうかを判定
# 戻り値: 0=Bare構成, 1=通常構成またはgitリポジトリでない
is_bare_structure() {
    local bare_dir
    bare_dir=$(find_bare_dir "$1")
    [ -n "$bare_dir" ]
}

# git コマンドを適切な git-dir で実行
# Bare構成の場合は --git-dir を自動付与
git_cmd() {
    local git_dir
    git_dir=$(get_git_dir)

    if [ -z "$git_dir" ]; then
        echo -e "${RED}エラー: gitリポジトリが見つかりません${NC}" >&2
        return 1
    fi

    # .bare の場合は --git-dir を付与
    if [[ "$git_dir" == */.bare ]]; then
        git --git-dir="$git_dir" "$@"
    else
        git "$@"
    fi
}

# worktree 一覧を取得
# 出力: パス\tブランチ 形式
list_worktrees() {
    local git_dir
    git_dir=$(get_git_dir "$1")

    if [ -z "$git_dir" ]; then
        return 1
    fi

    local porcelain_output
    if [[ "$git_dir" == */.bare ]]; then
        porcelain_output=$(git --git-dir="$git_dir" worktree list --porcelain)
    else
        porcelain_output=$(git worktree list --porcelain)
    fi

    echo "$porcelain_output" | awk '
        /^worktree / {
            if (path != "" && !printed) {
                print path "\t(detached)"
            }
            path = $2
            printed = 0
            is_bare = 0
        }
        /^bare$/ {
            is_bare = 1
            printed = 1
        }
        /^branch / {
            gsub(/refs\/heads\//, "", $2)
            print path "\t" $2
            printed = 1
        }
        END {
            if (path != "" && !printed && !is_bare) {
                print path "\t(detached)"
            }
        }
    '
}

# worktree のパス一覧を取得（.bare自体は除外）
list_worktree_paths() {
    local git_dir
    git_dir=$(get_git_dir "$1")

    if [ -z "$git_dir" ]; then
        return 1
    fi

    if [[ "$git_dir" == */.bare ]]; then
        git --git-dir="$git_dir" worktree list --porcelain | \
            grep '^worktree ' | awk '{print $2}' | grep -v '\.bare$'
    else
        git worktree list --porcelain | \
            grep '^worktree ' | awk '{print $2}'
    fi
}

# worktree の名前一覧を取得（ディレクトリ名のみ）
list_worktree_names() {
    list_worktree_paths "$1" | while read -r path; do
        basename "$path"
    done
}

# 現在のディレクトリがworktree内かどうか判定
is_in_worktree() {
    local current_dir="${1:-$(pwd)}"
    local git_dir
    git_dir=$(get_git_dir "$current_dir")

    if [ -z "$git_dir" ]; then
        return 1
    fi

    # .bare 構成の場合
    if [[ "$git_dir" == */.bare ]]; then
        # 現在のディレクトリが .bare と同階層のworktreeか確認
        local project_root
        project_root=$(dirname "$git_dir")

        # 現在ディレクトリがプロジェクトルート直下のworktreeかチェック
        for wt_path in $(list_worktree_paths "$current_dir"); do
            if [[ "$current_dir" == "$wt_path"* ]]; then
                return 0
            fi
        done
        return 1
    else
        # 通常構成: .git があればworktree内
        return 0
    fi
}

# gitが --relative-paths オプションをサポートしているか判定（2.48.0以降）
git_supports_relative_paths() {
    local git_version
    git_version=$(git --version | sed 's/git version //')
    local major minor
    major=$(echo "$git_version" | cut -d. -f1)
    minor=$(echo "$git_version" | cut -d. -f2)
    # --relative-paths was added in git 2.48.0
    [ "$major" -gt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -ge 48 ]; }
}

# git worktree add のラッパー
# Git 2.48.0+ では --relative-paths を自動付与（JetBrains IDE互換性のため）
git_worktree_add() {
    if git_supports_relative_paths; then
        git worktree add --relative-paths "$@"
    else
        git worktree add "$@"
    fi
}

# 現在のworktree名を取得
get_current_worktree_name() {
    local current_dir="${1:-$(pwd)}"

    if is_bare_structure "$current_dir"; then
        local project_root
        project_root=$(find_project_root "$current_dir")

        # 現在ディレクトリからプロジェクトルートを引いた部分がworktree名
        local relative_path="${current_dir#$project_root/}"
        # 最初のディレクトリ名を取得
        echo "$relative_path" | cut -d'/' -f1
    else
        # 通常構成: 現在のディレクトリ名
        basename "$(pwd)"
    fi
}
