#!/bin/bash

# プロジェクト固有の初期セットアップスクリプト
# irieのセットアップスクリプト（irie add）から呼び出される
#
# 利用可能な環境変数:
#   WORKTREE_DIR              - ディレクトリ名 (例: app1)
#   WORKTREE_BRANCH           - ブランチ名 (例: feat/new-feature)
#   WORKTREE_FQDN             - ホスト名 (例: app1.<project>.localhost)
#   WORKTREE_PREFIX           - サブドメイン接頭辞 (mainは空、worktreeは "app1.")
#   BASE_DOMAIN               - ベースドメイン (例: my-project.localhost)
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
    # echo "管理画面=http://${WORKTREE_PREFIX}${BASE_DOMAIN}/admin/login"
    echo "Vite=http://${WORKTREE_PREFIX}vite.${BASE_DOMAIN}/"
    echo "MinIO=http://${WORKTREE_PREFIX}minio.${BASE_DOMAIN}/"
    echo "Mailpit=http://${WORKTREE_PREFIX}mailpit.${BASE_DOMAIN}/"
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
# copy_if_exists "${WORKTREE_SOURCE_DIR}/packages/server/.env.testing" "./packages/server/.env.testing"

# === DB設定例（PostgreSQL） ===
# テストDB名は常にworktree専用名から生成（同一DBモードでも並行テスト実行のため分離必須）
# TESTING_DB_NAME="${WORKTREE_SEPARATE_DB_NAME}_testing"
# DB_CONTAINER="shared-postgres"
#
# echo -e "${BLUE}  → データベース起動待機中...${NC}"
# wait_for_postgres "$DB_CONTAINER"
#
# # .envのDB設定を更新
# echo -e "${BLUE}  → .envファイルのDB設定を更新中...${NC}"
# sed_inplace "s/^DB_HOST=.*/DB_HOST=${DB_CONTAINER}/" .env
# sed_inplace "s/^DB_DATABASE=.*/DB_DATABASE=${WORKTREE_DB_NAME}/" .env
#
# # DB初期化判定（should_init_db関数がSHOULD_INIT_DB変数を設定）
# # SHOULD_INIT_DB=true となる条件:
# #   1. main/masterブランチの場合
# #   2. --separate-db指定の場合（WORKTREE_USE_SEPARATE_DB=true）
# #   3. DBが存在しない場合
# postgres_db_exists "$DB_CONTAINER" "$WORKTREE_DB_NAME" && DB_EXISTS=true || DB_EXISTS=false
# should_init_db "$DB_EXISTS"
#
# if [ "$SHOULD_INIT_DB" = "true" ]; then
#     echo -e "${BLUE}  → メインデータベース ${WORKTREE_DB_NAME} を作成中...${NC}"
#     docker exec "$DB_CONTAINER" psql -U root -d postgres -c "CREATE DATABASE ${WORKTREE_DB_NAME};" 2>/dev/null || true
# fi
#
# # テストDB作成（worktree専用DB名・並行テスト実行のため分離必須）
# echo -e "${BLUE}  → テスト用データベース ${TESTING_DB_NAME} を作成中...${NC}"
# docker exec "$DB_CONTAINER" psql -U root -d postgres -c "CREATE DATABASE ${TESTING_DB_NAME};" 2>/dev/null || true
#
# # === マイグレーション・シーダー ===
# if [ "$SHOULD_INIT_DB" = "true" ]; then
#     echo -e "${BLUE}  → migrate:fresh --seed${NC}"
#     docker compose exec -T app php artisan migrate:fresh --seed
# fi
#
# # テストDBマイグレーション（常に実行・並行テスト実行のため分離必須）
# echo -e "${BLUE}  → migrate:fresh --env=testing${NC}"
# docker compose exec -T app php artisan migrate:fresh --env=testing

# === 依存関係について ===
# post-setup.shでcomposer install等は不要
# docker-compose.yamlでanonymous volumeを使用し、docker build時の依存関係を利用する
# 例: volumes: に /var/www/html/vendor を追加してDocker側のvendorを使用

echo -e "${GREEN}  → post-setup.sh 完了${NC}"
