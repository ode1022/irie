#!/bin/bash

# irie config - 設定ファイル管理ライブラリ
# 設定ファイル: ~/.config/irie/config

# 設定ファイルのパス
IRIE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/irie"
IRIE_CONFIG_FILE="${IRIE_CONFIG_DIR}/config"

# 設定ディレクトリを作成
ensure_config_dir() {
    if [ ! -d "$IRIE_CONFIG_DIR" ]; then
        mkdir -p "$IRIE_CONFIG_DIR"
    fi
}

# 設定値を取得
# 引数: key [default_value]
get_config() {
    local key="$1"
    local default="${2:-}"

    if [ ! -f "$IRIE_CONFIG_FILE" ]; then
        echo "$default"
        return
    fi

    local value
    value=$(grep "^${key}=" "$IRIE_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)

    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# 設定値を保存
# 引数: key value
set_config() {
    local key="$1"
    local value="$2"

    ensure_config_dir

    # 既存の設定があれば削除
    if [ -f "$IRIE_CONFIG_FILE" ]; then
        # macOS/Linux両対応のsed
        if sed --version 2>/dev/null | grep -q GNU; then
            sed -i "/^${key}=/d" "$IRIE_CONFIG_FILE"
        else
            sed -i '' "/^${key}=/d" "$IRIE_CONFIG_FILE"
        fi
    fi

    # 新しい値を追加
    echo "${key}=${value}" >> "$IRIE_CONFIG_FILE"
}

# 設定値を削除
# 引数: key
unset_config() {
    local key="$1"

    if [ -f "$IRIE_CONFIG_FILE" ]; then
        if sed --version 2>/dev/null | grep -q GNU; then
            sed -i "/^${key}=/d" "$IRIE_CONFIG_FILE"
        else
            sed -i '' "/^${key}=/d" "$IRIE_CONFIG_FILE"
        fi
    fi
}

# 全設定を表示
list_config() {
    if [ -f "$IRIE_CONFIG_FILE" ]; then
        cat "$IRIE_CONFIG_FILE"
    fi
}

# 設定ファイルのパスを表示
config_path() {
    echo "$IRIE_CONFIG_FILE"
}
