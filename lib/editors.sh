#!/bin/bash

# irie editors - エディタ検出・起動ライブラリ
# 対応プラットフォーム: WSL, Linux, macOS

# プラットフォーム検出
detect_platform() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [ "$(uname)" = "Darwin" ]; then
        echo "macos"
    else
        echo "linux"
    fi
}

# === JetBrains IDE 定義 ===
# bash 3.2互換のため通常の配列を使用（macOSの/bin/bashは3.2）
# 形式: "フォルダ名パターン|実行ファイル名|表示名"
JETBRAINS_IDES=(
    "PhpStorm|phpstorm64.exe|PhpStorm"
    "WebStorm|webstorm64.exe|WebStorm"
    "IntelliJ IDEA|idea64.exe|IntelliJ IDEA"
    "PyCharm|pycharm64.exe|PyCharm"
    "RubyMine|rubymine64.exe|RubyMine"
    "GoLand|goland64.exe|GoLand"
    "CLion|clion64.exe|CLion"
    "DataGrip|datagrip64.exe|DataGrip"
    "Rider|rider64.exe|Rider"
    "Fleet|fleet64.exe|Fleet"
    "Android Studio|studio64.exe|Android Studio"
    "Aqua|aqua64.exe|Aqua"
    "RustRover|rustrover64.exe|RustRover"
    "Writerside|writerside64.exe|Writerside"
)

# macOS用のJetBrains IDE app名
# 形式: "IDE名|app名"
JETBRAINS_MACOS_APPS=(
    "PhpStorm|PhpStorm.app"
    "WebStorm|WebStorm.app"
    "IntelliJ IDEA|IntelliJ IDEA.app"
    "IntelliJ IDEA CE|IntelliJ IDEA CE.app"
    "PyCharm|PyCharm.app"
    "PyCharm CE|PyCharm CE.app"
    "RubyMine|RubyMine.app"
    "GoLand|GoLand.app"
    "CLion|CLion.app"
    "DataGrip|DataGrip.app"
    "Rider|Rider.app"
    "Fleet|Fleet.app"
    "Android Studio|Android Studio.app"
    "AppCode|AppCode.app"
    "Aqua|Aqua.app"
    "RustRover|RustRover.app"
)

# Linux用のJetBrains IDE
# 形式: "コマンド名|Toolboxアプリ名"
JETBRAINS_LINUX_CMDS=(
    "phpstorm|PhpStorm"
    "webstorm|WebStorm"
    "idea|IDEA-U"
    "pycharm|PyCharm-P"
    "rubymine|RubyMine"
    "goland|GoLand"
    "clion|CLion"
    "datagrip|DataGrip"
    "rider|Rider"
    "fleet|Fleet"
    "studio|AndroidStudio"
)

# === WSL用: JetBrains IDE動的検出 ===
detect_wsl_jetbrains() {
    local jetbrains_dir="/mnt/c/Program Files/JetBrains"
    [ ! -d "$jetbrains_dir" ] && return

    local entry
    for entry in "${JETBRAINS_IDES[@]}"; do
        local ide_pattern="${entry%%|*}"
        local rest="${entry#*|}"
        local exe_name="${rest%%|*}"
        local display_name="${rest#*|}"

        # 最新バージョンのフォルダを取得
        local latest
        latest=$(ls -d "$jetbrains_dir/$ide_pattern"* 2>/dev/null | sort -V | tail -1)

        if [ -n "$latest" ] && [ -f "$latest/bin/$exe_name" ]; then
            local id
            id=$(echo "$display_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
            echo "${id}:${display_name}:${latest}/bin/${exe_name}"
        fi
    done
}

# === macOS用: JetBrains IDE動的検出 ===
detect_macos_jetbrains() {
    local entry
    for entry in "${JETBRAINS_MACOS_APPS[@]}"; do
        local ide_name="${entry%%|*}"
        local app_name="${entry#*|}"
        local app_path="/Applications/$app_name"

        if [ -d "$app_path" ]; then
            local id
            id=$(echo "$ide_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
            echo "${id}:${ide_name}:${app_path}"
        fi
    done
}

# === Linux用: JetBrains IDE動的検出 ===
detect_linux_jetbrains() {
    local entry
    for entry in "${JETBRAINS_LINUX_CMDS[@]}"; do
        local cmd="${entry%%|*}"
        local toolbox_name="${entry#*|}"
        local path=""

        # 1. コマンドとして検出
        if command -v "$cmd" &>/dev/null; then
            path=$(command -v "$cmd")
        # 2. snapパッケージ
        elif [ -x "/snap/bin/$cmd" ]; then
            path="/snap/bin/$cmd"
        # 3. JetBrains Toolbox
        else
            local toolbox_path
            toolbox_path=$(ls -d "$HOME/.local/share/JetBrains/Toolbox/apps/$toolbox_name/ch-0"/*/bin/*.sh 2>/dev/null | sort -V | tail -1)
            if [ -n "$toolbox_path" ] && [ -x "$toolbox_path" ]; then
                path="$toolbox_path"
            fi
        fi

        if [ -n "$path" ]; then
            local display_name="$cmd"
            case "$cmd" in
                phpstorm) display_name="PhpStorm" ;;
                webstorm) display_name="WebStorm" ;;
                idea) display_name="IntelliJ IDEA" ;;
                pycharm) display_name="PyCharm" ;;
                rubymine) display_name="RubyMine" ;;
                goland) display_name="GoLand" ;;
                clion) display_name="CLion" ;;
                datagrip) display_name="DataGrip" ;;
                rider) display_name="Rider" ;;
                fleet) display_name="Fleet" ;;
                studio) display_name="Android Studio" ;;
            esac
            echo "${cmd}:${display_name}:${path}"
        fi
    done
}

# === その他のエディタ検出 ===

# VS Code (WSL)
detect_wsl_vscode() {
    local found
    found=$(compgen -G "/mnt/c/Users/*/AppData/Local/Programs/Microsoft VS Code/Code.exe" 2>/dev/null | head -1)
    if [ -n "$found" ] && [ -f "$found" ]; then
        echo "vscode:Visual Studio Code:$found"
        return
    fi
    if [ -f "/mnt/c/Program Files/Microsoft VS Code/Code.exe" ]; then
        echo "vscode:Visual Studio Code:/mnt/c/Program Files/Microsoft VS Code/Code.exe"
    fi
}

# VS Code (macOS)
detect_macos_vscode() {
    if [ -d "/Applications/Visual Studio Code.app" ]; then
        echo "vscode:Visual Studio Code:/Applications/Visual Studio Code.app"
    fi
}

# VS Code (Linux)
detect_linux_vscode() {
    if command -v code &>/dev/null; then
        echo "vscode:Visual Studio Code:$(command -v code)"
    elif [ -x "/snap/bin/code" ]; then
        echo "vscode:Visual Studio Code:/snap/bin/code"
    elif [ -x "/usr/bin/code" ]; then
        echo "vscode:Visual Studio Code:/usr/bin/code"
    fi
}

# Cursor (WSL)
detect_wsl_cursor() {
    local found
    found=$(compgen -G "/mnt/c/Users/*/AppData/Local/Programs/cursor/Cursor.exe" 2>/dev/null | head -1)
    if [ -n "$found" ] && [ -f "$found" ]; then
        echo "cursor:Cursor:$found"
        return
    fi
    if [ -f "/mnt/c/Program Files/Cursor/Cursor.exe" ]; then
        echo "cursor:Cursor:/mnt/c/Program Files/Cursor/Cursor.exe"
    fi
}

# Cursor (macOS)
detect_macos_cursor() {
    if [ -d "/Applications/Cursor.app" ]; then
        echo "cursor:Cursor:/Applications/Cursor.app"
    fi
}

# Cursor (Linux)
detect_linux_cursor() {
    if command -v cursor &>/dev/null; then
        echo "cursor:Cursor:$(command -v cursor)"
    elif [ -x "$HOME/.local/bin/cursor" ]; then
        echo "cursor:Cursor:$HOME/.local/bin/cursor"
    fi
}

# Zed (WSL)
detect_wsl_zed() {
    local found
    found=$(compgen -G "/mnt/c/Users/*/AppData/Local/Programs/Zed/Zed.exe" 2>/dev/null | head -1)
    if [ -n "$found" ] && [ -f "$found" ]; then
        echo "zed:Zed:$found"
        return
    fi
    if [ -f "/mnt/c/Program Files/Zed/Zed.exe" ]; then
        echo "zed:Zed:/mnt/c/Program Files/Zed/Zed.exe"
    fi
}

# Zed (macOS)
detect_macos_zed() {
    if [ -d "/Applications/Zed.app" ]; then
        echo "zed:Zed:/Applications/Zed.app"
    fi
}

# Zed (Linux)
detect_linux_zed() {
    if command -v zed &>/dev/null; then
        echo "zed:Zed:$(command -v zed)"
    elif [ -x "$HOME/.local/bin/zed" ]; then
        echo "zed:Zed:$HOME/.local/bin/zed"
    fi
}

# Sublime Text (macOS)
detect_macos_sublime() {
    if [ -d "/Applications/Sublime Text.app" ]; then
        echo "sublime:Sublime Text:/Applications/Sublime Text.app"
    fi
}

# Sublime Text (Linux)
detect_linux_sublime() {
    if command -v subl &>/dev/null; then
        echo "sublime:Sublime Text:$(command -v subl)"
    elif [ -x "/snap/bin/subl" ]; then
        echo "sublime:Sublime Text:/snap/bin/subl"
    fi
}

# Neovim (Linux/macOS)
detect_linux_neovim() {
    if command -v nvim &>/dev/null; then
        echo "neovim:Neovim:$(command -v nvim)"
    fi
}

detect_macos_neovim() {
    if command -v nvim &>/dev/null; then
        echo "neovim:Neovim:$(command -v nvim)"
    fi
}

# Vim (Linux/macOS)
detect_linux_vim() {
    if command -v vim &>/dev/null; then
        echo "vim:Vim:$(command -v vim)"
    fi
}

detect_macos_vim() {
    if command -v vim &>/dev/null; then
        echo "vim:Vim:$(command -v vim)"
    fi
}

# Emacs (Linux/macOS)
detect_linux_emacs() {
    if command -v emacs &>/dev/null; then
        echo "emacs:Emacs:$(command -v emacs)"
    fi
}

detect_macos_emacs() {
    if command -v emacs &>/dev/null; then
        echo "emacs:Emacs:$(command -v emacs)"
    elif [ -d "/Applications/Emacs.app" ]; then
        echo "emacs:Emacs:/Applications/Emacs.app"
    fi
}

# === メイン検出関数 ===

# インストール済みエディタを検出して一覧を返す
# 形式: ID:NAME:PATH
detect_installed_editors() {
    local platform
    platform=$(detect_platform)

    case "$platform" in
        wsl)
            # JetBrains IDE（動的検出）
            detect_wsl_jetbrains
            # その他のエディタ
            detect_wsl_vscode
            detect_wsl_cursor
            detect_wsl_zed
            ;;
        macos)
            detect_macos_jetbrains
            detect_macos_vscode
            detect_macos_cursor
            detect_macos_zed
            detect_macos_sublime
            detect_macos_neovim
            detect_macos_vim
            detect_macos_emacs
            ;;
        linux)
            detect_linux_jetbrains
            detect_linux_vscode
            detect_linux_cursor
            detect_linux_zed
            detect_linux_sublime
            detect_linux_neovim
            detect_linux_vim
            detect_linux_emacs
            ;;
    esac
}

# エディタでディレクトリを開く
# 引数: editor_path target_path
open_with_editor() {
    local editor_path="$1"
    local target_path="$2"
    local platform
    platform=$(detect_platform)

    case "$platform" in
        wsl)
            # WSLパスをWindowsパスに変換
            local windows_path
            if command -v wslpath &>/dev/null; then
                windows_path=$(wslpath -w "$target_path")
            else
                windows_path=$(echo "$target_path" | sed 's|^/mnt/\([a-z]\)/|\U\1:/|' | sed 's|/|\\|g')
            fi
            "$editor_path" "$windows_path" &>/dev/null &
            ;;
        macos)
            # macOSの場合は open -a でアプリを起動
            if [[ "$editor_path" == *.app ]]; then
                open -a "$editor_path" "$target_path"
            else
                "$editor_path" "$target_path" &>/dev/null &
            fi
            ;;
        linux)
            "$editor_path" "$target_path" &>/dev/null &
            ;;
    esac
}

# エディタIDからパスを取得
# 引数: editor_id
# 戻り値: パスを出力（見つからない場合は空）
get_editor_path_by_id() {
    local editor_id="$1"
    local line

    while IFS= read -r line; do
        local id="${line%%:*}"
        if [ "$id" = "$editor_id" ]; then
            # ID:NAME:PATH の形式から PATH を取得
            local rest="${line#*:}"  # NAME:PATH
            local path="${rest#*:}"  # PATH
            echo "$path"
            return 0
        fi
    done < <(detect_installed_editors)

    return 1
}

# エディタIDから表示名を取得
# 引数: editor_id
# 戻り値: 表示名を出力（見つからない場合はIDをそのまま返す）
get_editor_name_by_id() {
    local editor_id="$1"
    local line

    while IFS= read -r line; do
        local id="${line%%:*}"
        if [ "$id" = "$editor_id" ]; then
            # ID:NAME:PATH の形式から NAME を取得
            local rest="${line#*:}"  # NAME:PATH
            local name="${rest%%:*}"  # NAME
            echo "$name"
            return 0
        fi
    done < <(detect_installed_editors)

    # 見つからない場合はIDをそのまま返す
    echo "$editor_id"
}
