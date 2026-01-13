#!/usr/bin/env bats

# 名前変換ロジックのテスト
# 実行: bats tests/test_name_conversion.bats

# === Directory name conversion tests ===
# ディレクトリ名変換のテスト

# feat/new-feature → new-feature
@test "directory name: feat/new-feature becomes new-feature" {
    BRANCH_NAME="feat/new-feature"
    TEMP_NAME=${BRANCH_NAME#feat/}
    DIR_NAME=${TEMP_NAME//\//-}
    [ "$DIR_NAME" = "new-feature" ]
}

# feature/nested/path → feature-nested-path
@test "directory name: feature/nested/path becomes feature-nested-path" {
    BRANCH_NAME="feature/nested/path"
    TEMP_NAME=${BRANCH_NAME#feat/}
    DIR_NAME=${TEMP_NAME//\//-}
    [ "$DIR_NAME" = "feature-nested-path" ]
}

# app7（スラッシュなし）→ app7
@test "directory name: app7 (no slash) stays app7" {
    BRANCH_NAME="app7"
    TEMP_NAME=${BRANCH_NAME#feat/}
    DIR_NAME=${TEMP_NAME//\//-}
    [ "$DIR_NAME" = "app7" ]
}

# main → main
@test "directory name: main stays main" {
    BRANCH_NAME="main"
    TEMP_NAME=${BRANCH_NAME#feat/}
    DIR_NAME=${TEMP_NAME//\//-}
    [ "$DIR_NAME" = "main" ]
}

# === Subdomain conversion tests (Traefik mode) ===
# サブドメイン変換のテスト（Traefik方式）

# New_Feature → new-feature（小文字化、_を-に）
@test "subdomain: New_Feature becomes new-feature (lowercase, _ to -)" {
    DIR_NAME="New_Feature"
    SUBDOMAIN=$(echo "$DIR_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    [ "$SUBDOMAIN" = "new-feature" ]
}

# APP7 → app7（小文字化）
@test "subdomain: APP7 becomes app7 (lowercase)" {
    DIR_NAME="APP7"
    SUBDOMAIN=$(echo "$DIR_NAME" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    [ "$SUBDOMAIN" = "app7" ]
}

# === DB name conversion tests ===
# DB名変換のテスト

# new-feature → myproject_new_feature
@test "db name: new-feature becomes myproject_new_feature" {
    PROJECT_NAME="myproject"
    DB_PREFIX=$(echo "$PROJECT_NAME" | tr '-' '_')
    DIR_NAME="new-feature"
    DB_NAME_TEMP=$(echo "$DIR_NAME" | tr '/-' '__' | tr '[:upper:]' '[:lower:]')
    DB_NAME="${DB_PREFIX}_${DB_NAME_TEMP}"
    [ "$DB_NAME" = "myproject_new_feature" ]
}

# my-project + main → my_project_main
@test "db name: my-project + main becomes my_project_main" {
    PROJECT_NAME="my-project"
    DB_PREFIX=$(echo "$PROJECT_NAME" | tr '-' '_')
    DIR_NAME="main"
    DB_NAME_TEMP=$(echo "$DIR_NAME" | tr '/-' '__' | tr '[:upper:]' '[:lower:]')
    DB_NAME="${DB_PREFIX}_${DB_NAME_TEMP}"
    [ "$DB_NAME" = "my_project_main" ]
}

# app7 → myproject_app7
@test "db name: app7 becomes myproject_app7" {
    PROJECT_NAME="myproject"
    DB_PREFIX=$(echo "$PROJECT_NAME" | tr '-' '_')
    DIR_NAME="app7"
    DB_NAME_TEMP=$(echo "$DIR_NAME" | tr '/-' '__' | tr '[:upper:]' '[:lower:]')
    DB_NAME="${DB_PREFIX}_${DB_NAME_TEMP}"
    [ "$DB_NAME" = "myproject_app7" ]
}

# === FQDN generation tests ===
# FQDN生成のテスト（Traefik方式: *.localhost）

# サブドメイン → subdomain.myproject.localhost
@test "FQDN (traefik): subdomain becomes subdomain.myproject.localhost" {
    BASE_DOMAIN="myproject.localhost"
    SUBDOMAIN="new-feature"
    USE_ROOT_DOMAIN=false

    if [ "$USE_ROOT_DOMAIN" = true ]; then
        FQDN="${BASE_DOMAIN}"
    else
        FQDN="${SUBDOMAIN}.${BASE_DOMAIN}"
    fi

    [ "$FQDN" = "new-feature.myproject.localhost" ]
}

# --root → myproject.localhost
@test "FQDN (traefik): --root gives myproject.localhost" {
    BASE_DOMAIN="myproject.localhost"
    SUBDOMAIN="main"
    USE_ROOT_DOMAIN=true

    if [ "$USE_ROOT_DOMAIN" = true ]; then
        FQDN="${BASE_DOMAIN}"
    else
        FQDN="${SUBDOMAIN}.${BASE_DOMAIN}"
    fi

    [ "$FQDN" = "myproject.localhost" ]
}

# === TRAEFIK_ID generation tests ===
# TRAEFIK_ID生成のテスト

# サブドメイン → myproject-subdomain
@test "TRAEFIK_ID: subdomain becomes myproject-subdomain" {
    PROJECT_NAME="myproject"
    SUBDOMAIN="new-feature"
    USE_ROOT_DOMAIN=false

    if [ "$USE_ROOT_DOMAIN" = true ]; then
        TRAEFIK_ID="${PROJECT_NAME}"
    else
        TRAEFIK_ID="${PROJECT_NAME}-${SUBDOMAIN}"
    fi

    [ "$TRAEFIK_ID" = "myproject-new-feature" ]
}

# --root → myproject
@test "TRAEFIK_ID: --root gives myproject" {
    PROJECT_NAME="myproject"
    SUBDOMAIN="main"
    USE_ROOT_DOMAIN=true

    if [ "$USE_ROOT_DOMAIN" = true ]; then
        TRAEFIK_ID="${PROJECT_NAME}"
    else
        TRAEFIK_ID="${PROJECT_NAME}-${SUBDOMAIN}"
    fi

    [ "$TRAEFIK_ID" = "myproject" ]
}

# === Ticket project key removal tests ===
# チケットプロジェクトキー削除のテスト

# helpers.shをsource
setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    source "$SCRIPT_DIR/../lib/helpers.sh"
}

# PROJ_NAME-123-new-feature → 123-new-feature
@test "strip_ticket_project_key: PROJ_NAME-123-new-feature becomes 123-new-feature" {
    result=$(strip_ticket_project_key "PROJ_NAME-123-new-feature")
    [ "$result" = "123-new-feature" ]
}

# PROJ-123-fix-bug → 123-fix-bug
@test "strip_ticket_project_key: PROJ-123-fix-bug becomes 123-fix-bug" {
    result=$(strip_ticket_project_key "PROJ-123-fix-bug")
    [ "$result" = "123-fix-bug" ]
}

# PROJ-123（説明なし）→ 123
@test "strip_ticket_project_key: PROJ-123 (no description) becomes 123" {
    result=$(strip_ticket_project_key "PROJ-123")
    [ "$result" = "123" ]
}

# ENG-1-x（短いチケット番号）→ 1-x
@test "strip_ticket_project_key: ENG-1-x (short ticket number) becomes 1-x" {
    result=$(strip_ticket_project_key "ENG-1-x")
    [ "$result" = "1-x" ]
}

# fix-coupon-bug（パターン非マッチ）→ そのまま
@test "strip_ticket_project_key: fix-coupon-bug (no match) stays unchanged" {
    result=$(strip_ticket_project_key "fix-coupon-bug")
    [ "$result" = "fix-coupon-bug" ]
}

# v2-update（小文字開始）→ そのまま
@test "strip_ticket_project_key: v2-update (lowercase start) stays unchanged" {
    result=$(strip_ticket_project_key "v2-update")
    [ "$result" = "v2-update" ]
}

# PRODUCT_2013-789-test（数字入りキー）→ 789-test
@test "strip_ticket_project_key: PRODUCT_2013-789-test becomes 789-test" {
    result=$(strip_ticket_project_key "PRODUCT_2013-789-test")
    [ "$result" = "789-test" ]
}

# main（シンプル名）→ そのまま
@test "strip_ticket_project_key: main (simple name) stays unchanged" {
    result=$(strip_ticket_project_key "main")
    [ "$result" = "main" ]
}

# === generate_safe_db_name tests ===
# generate_safe_db_name のテスト

# チケットキー削除
@test "generate_safe_db_name: removes ticket key" {
    result=$(generate_safe_db_name "my-project" "PROJ_NAME-123-new-feature")
    [ "$result" = "my_project_123_new_feature" ]
}

# パターン非マッチはそのまま
@test "generate_safe_db_name: keeps non-matching pattern as is" {
    result=$(generate_safe_db_name "my-project" "fix-coupon-bug")
    [ "$result" = "my_project_fix_coupon_bug" ]
}

# 44文字ちょうど（切り詰めなし）
@test "generate_safe_db_name: exactly 44 chars (no truncation)" {
    # 44文字ちょうどのDB名を生成
    # proj_ (5文字) + 39文字 = 44文字
    result=$(generate_safe_db_name "proj" "123456789012345678901234567890123456789")
    [ ${#result} -eq 44 ]
    [ "$result" = "proj_123456789012345678901234567890123456789" ]
}

# 45文字以上は44文字に切り詰め
@test "generate_safe_db_name: truncates to 44 chars when over 45" {
    # 45文字以上になるDB名
    # proj_ (5文字) + 40文字 = 45文字 → 44文字に切り詰め
    result=$(generate_safe_db_name "proj" "1234567890123456789012345678901234567890")
    [ ${#result} -eq 44 ]
}

# 長いプロジェクト名+ブランチ名の切り詰め
@test "generate_safe_db_name: truncates long project name + branch name" {
    result=$(generate_safe_db_name "long-project-name" "very-long-branch-name-that-exceeds-the-maximum-limit")
    [ ${#result} -le 44 ]
}

