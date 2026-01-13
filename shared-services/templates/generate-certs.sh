#!/bin/bash
# TLS証明書生成スクリプト
# 自己署名証明書を生成します（証明書が存在しない場合のみ）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/traefik/certs"
DYNAMIC_DIR="${SCRIPT_DIR}/traefik/dynamic"

# ディレクトリ作成
mkdir -p "$CERTS_DIR"
mkdir -p "$DYNAMIC_DIR"

# 証明書が存在しない場合のみ生成
if [ ! -f "$CERTS_DIR/localhost.crt" ]; then
    echo "Generating self-signed certificates..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$CERTS_DIR/localhost.key" \
        -out "$CERTS_DIR/localhost.crt" \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,DNS:*.localhost"
    echo "✅ Certificates generated: $CERTS_DIR/"
fi

# TLS動的設定ファイルを作成
if [ ! -f "$DYNAMIC_DIR/tls.yml" ]; then
    cat > "$DYNAMIC_DIR/tls.yml" << 'EOF'
tls:
  certificates:
    - certFile: /etc/traefik/certs/localhost.crt
      keyFile: /etc/traefik/certs/localhost.key
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/localhost.crt
        keyFile: /etc/traefik/certs/localhost.key
EOF
    echo "✅ TLS config created: $DYNAMIC_DIR/tls.yml"
fi
