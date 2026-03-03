#!/bin/bash
# irie 共有サービス管理用ヘルパー関数
# Traefik等の共有サービスの起動・管理を行う内部用ライブラリ

# カラー出力用（未定義の場合のみ設定）
BLUE=${BLUE:-$'\033[0;34m'}
GREEN=${GREEN:-$'\033[0;32m'}
RED=${RED:-$'\033[0;31m'}
NC=${NC:-$'\033[0m'}

# Traefikが起動していなければ自動起動
# 引数: $1=shared-servicesディレクトリのパス
ensure_traefik_running() {
    local shared_services_dir="$1"
    local traefik_container="shared-traefik"

    if docker ps --format '{{.Names}}' | grep -q "${traefik_container}"; then
        echo -e "${GREEN}  ✓ Traefikは起動中${NC}"
        return 0
    fi

    echo -e "${BLUE}  → Traefikを起動中...${NC}"

    # traefik.ymlをテンプレートからコピー（存在しない場合）
    if [ ! -f "${shared_services_dir}/traefik.yml" ]; then
        if [ -f "${shared_services_dir}/templates/traefik.yml" ]; then
            echo -e "${BLUE}  → traefik.yml をテンプレートからコピー${NC}"
            cp "${shared_services_dir}/templates/traefik.yml" "${shared_services_dir}/traefik.yml"
        else
            echo -e "${RED}エラー: テンプレート ${shared_services_dir}/templates/traefik.yml が見つかりません${NC}"
            return 1
        fi
    fi

    # generate-certs.shをテンプレートからコピー（存在しない場合）
    if [ ! -f "${shared_services_dir}/generate-certs.sh" ]; then
        cp "${shared_services_dir}/templates/generate-certs.sh" "${shared_services_dir}/generate-certs.sh"
        chmod +x "${shared_services_dir}/generate-certs.sh"
    fi

    # 証明書を生成（存在しない場合のみ）
    local orig_dir
    orig_dir="$(pwd)"
    cd "$shared_services_dir"
    bash "./generate-certs.sh"

    # Traefikを起動
    docker compose -f traefik.yml up -d
    cd "$orig_dir"

    echo -e "${GREEN}  ✓ Traefikは起動中${NC}"
}
