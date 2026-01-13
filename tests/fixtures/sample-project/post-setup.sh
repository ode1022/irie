#!/bin/bash
# テスト用 post-setup.sh
# 最小構成のため、.envコピーやDBマイグレーションは不要
# テスト用に環境変数をファイルに書き出す

set -e

# テスト用: 渡された環境変数をファイルに書き出し（検証用）
ENV_OUTPUT_FILE=".irie-env-vars"
cat > "$ENV_OUTPUT_FILE" << EOF
WORKTREE_DIR=${WORKTREE_DIR:-}
WORKTREE_BRANCH=${WORKTREE_BRANCH:-}
WORKTREE_FQDN=${WORKTREE_FQDN:-}
WORKTREE_DB_NAME=${WORKTREE_DB_NAME:-}
WORKTREE_SEPARATE_DB_NAME=${WORKTREE_SEPARATE_DB_NAME:-}
WORKTREE_USE_SEPARATE_DB=${WORKTREE_USE_SEPARATE_DB:-}
EOF

echo "post-setup.sh: テスト用プロジェクトのセットアップ完了"
echo "post-setup.sh: 環境変数を ${ENV_OUTPUT_FILE} に書き出しました"
