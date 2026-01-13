#!/bin/bash

# プロジェクト固有のクリーンアップスクリプト
# irieのcleanupスクリプト（irie remove）から呼び出される
#
# 利用可能な環境変数:
#   WORKTREE_DIR              - ディレクトリ名 (例: app1)
#   WORKTREE_PATH             - worktreeのフルパス
#   WORKTREE_SOURCE_DIR       - 元のworktreeのパス (例: /path/to/project/main)
#   WORKTREE_FORCE            - 強制削除フラグ (true/false)
#   WORKTREE_USE_SEPARATE_DB  - 専用DBフラグ (true=専用DB名, false=mainと同じDB名)
#   WORKTREE_DB_NAME          - 現在のモードに応じたDB名
#   WORKTREE_SEPARATE_DB_NAME - worktree専用のDB名 (例: <project>_app1)
#   IRIE_LIB_DIR              - irieヘルパー関数のパス

set -e

# irieヘルパー関数を読み込み
source "${IRIE_LIB_DIR}/helpers.sh"

# === DB削除例 ===
# # 専用DBモード（--separate-db）の場合のみメインDBを削除
# if [ "$WORKTREE_USE_SEPARATE_DB" = "true" ]; then
#     echo -e "${BLUE}  → 専用DBを削除中...${NC}"
#     docker exec shared-postgres psql -U root -d postgres \
#         -c "DROP DATABASE IF EXISTS ${WORKTREE_DB_NAME};" 2>/dev/null || true
#     echo -e "${GREEN}    ✓ ${WORKTREE_DB_NAME} を削除${NC}"
# else
#     echo -e "${BLUE}  → mainと同じDBを使用: メインDB削除をスキップ${NC}"
# fi
#
# # テストDBは常に削除（worktree専用名なので安全）
# echo -e "${BLUE}  → テストDBを削除中...${NC}"
# docker exec shared-postgres psql -U root -d postgres \
#     -c "DROP DATABASE IF EXISTS ${WORKTREE_SEPARATE_DB_NAME}_testing;" 2>/dev/null || true
# echo -e "${GREEN}    ✓ ${WORKTREE_SEPARATE_DB_NAME}_testing を削除${NC}"

echo -e "${GREEN}  → post-cleanup.sh 完了${NC}"
