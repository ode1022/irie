#!/bin/bash

# プロジェクト固有の初期セットアップスクリプト
# irieのセットアップスクリプト（irie add）から呼び出される
#
# 利用可能な環境変数:
#   WORKTREE_DIR              - ディレクトリ名 (例: app1)
#   WORKTREE_BRANCH           - ブランチ名 (例: feat/new-feature)
#   WORKTREE_FQDN             - ホスト名 (例: app1.<project>.localhost)
#   WORKTREE_DB_NAME          - 現在のモードに応じたDB名
#   WORKTREE_SEPARATE_DB_NAME - worktree専用のDB名 (例: <project>_app1)
#   WORKTREE_USE_SEPARATE_DB  - 専用DBフラグ (true=専用DB名, false=mainと同じDB名)
#   WORKTREE_SOURCE_DIR       - 元のworktreeのパス (例: /path/to/project/main)
#   WORKTREE_TRAEFIK_ID       - Traefikルーター識別子 (例: project-app1)
#   IRIE_LIB_DIR              - irieヘルパー関数のパス

# === irie info 用の情報出力関数 ===
# irie info コマンドおよびセットアップ完了時に呼び出される
# プロジェクト固有のURLを key=value 形式で出力する
# プロジェクトに合わせて編集してください
irie_info() {
    # echo "管理画面=http://${WORKTREE_FQDN}/admin/login"
    # Traefik方式: <service>-<subdomain>.<project>.localhost 形式
    echo "Vite=http://vite-${WORKTREE_FQDN}/"
    echo "MinIO=http://minio-${WORKTREE_FQDN}/"
    echo "Mailpit=http://mailpit-${WORKTREE_FQDN}/"
}

# IRIE_INFO_ONLY=true の場合は関数定義のみで終了（irie info用）
if [ "${IRIE_INFO_ONLY:-}" = "true" ]; then
    return 0 2>/dev/null || exit 0
fi

set -e

# irieヘルパー関数を読み込み（sed_inplace, wait_for_postgres, copy_if_exists等）
source "${IRIE_LIB_DIR}/helpers.sh"

# === .envファイルのコピー ===
echo -e "${BLUE}  → .envファイルをコピー中...${NC}"
# プロジェクトに合わせてコピー対象を編集してください
copy_if_exists "${WORKTREE_SOURCE_DIR}/.env" "./.env"
# copy_if_exists "${WORKTREE_SOURCE_DIR}/packages/server/.env" "./packages/server/.env"

# === DB設定例（PostgreSQL） ===
# テストDB名は常にworktree専用名から生成（同一DBモードでも並行テスト実行のため分離必須）
# TESTING_DB_NAME="${WORKTREE_SEPARATE_DB_NAME}_testing"
# DB_CONTAINER="shared-postgres"
#
# wait_for_postgres "$DB_CONTAINER"
#
# # .envのDB設定を更新
# sed_inplace "s/^DB_HOST=.*/DB_HOST=${DB_CONTAINER}/" .env
# sed_inplace "s/^DB_DATABASE=.*/DB_DATABASE=${WORKTREE_DB_NAME}/" .env
#
# # 専用DBモード（--separate-db）の場合のみメインDB作成
# # デフォルトではmainと同じDB名を使うため作成不要
# if [ "$WORKTREE_USE_SEPARATE_DB" = "true" ]; then
#     docker exec "$DB_CONTAINER" psql -U root -d postgres -c "CREATE DATABASE ${WORKTREE_DB_NAME};" 2>/dev/null || true
# fi
#
# # テストDB作成（常に専用DB名）
# docker exec "$DB_CONTAINER" psql -U root -d postgres -c "CREATE DATABASE ${TESTING_DB_NAME};" 2>/dev/null || true
#
# # メインDBマイグレーション・シーダー（DBモードで分岐）
# if [ "$WORKTREE_USE_SEPARATE_DB" = "true" ]; then
#     docker-compose exec -T app php artisan migrate:fresh --seed
# else
#     echo "mainと同じDBを使用（マイグレーションをスキップ）"
# fi
#
# # テストDBマイグレーション（常に実行・並行テスト実行のため分離必須）
# docker-compose exec -T app php artisan migrate:fresh --env=testing

# === 依存関係について ===
# post-setup.shでcomposer install等は不要
# docker-compose.yamlでanonymous volumeを使用し、docker build時の依存関係を利用する
# 例: volumes: に /var/www/html/vendor を追加してDocker側のvendorを使用

echo -e "${GREEN}  → post-setup.sh 完了${NC}"
