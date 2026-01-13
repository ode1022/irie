# {{PROJECT_NAME}} Worktree環境

このディレクトリは{{PROJECT_NAME}}プロジェクト用のworktree環境設定です。

## 初期設定（初回のみ）

### irieのインストール

```bash
git clone git@github.com:ode1022/irie.git ~/.irie

# .bashrcや.zshrcに追加
export PATH="$HOME/.irie/bin:$PATH"
eval "$(irie shell-init)"   # シェル統合（自動移動機能）
```

※ 共有PostgreSQLやTraefikはスクリプト実行時に自動起動されます（irie側の`shared-services/`で管理）。

## Worktree作成

### Traefik方式（推奨・デフォルト）

```bash
# ルートドメインで作成（パスワード共有用、最初に作成推奨）
irie add main --root

# origin/mainから派生してサブドメインでworktreeを作成
irie add feat/new-feature --base origin/main
```

### Loopback方式

```bash
# ルートドメインで作成（パスワード共有用、共有DB推奨）
irie add main --loopback --root --shared-db

# origin/mainから派生してサブドメインでworktreeを作成（共有DB）
irie add feat/new-feature --loopback --shared-db --base origin/main

# IPアドレス指定
irie add feat/new-feature --loopback 127.0.0.5 --shared-db

# 独立DBを使用
irie add feat/new-feature --loopback --base origin/main
```

## アクセスURL

**Traefik方式:**
```
アプリ:    http://<subdomain>.{{PROJECT_NAME}}.localhost/
Vite:      http://vite-<subdomain>.{{PROJECT_NAME}}.localhost/
MinIO:     http://minio-<subdomain>.{{PROJECT_NAME}}.localhost/
Mailpit:   http://mailpit-<subdomain>.{{PROJECT_NAME}}.localhost/
Traefikダッシュボード: http://traefik.localhost/
```

**Loopback方式:**
```
アプリ:    http://<name>.{{PROJECT_NAME}}.test/
Vite:      http://<name>.{{PROJECT_NAME}}.test:5173/
MinIO:     http://<name>.{{PROJECT_NAME}}.test:9090/
Mailpit:   http://<name>.{{PROJECT_NAME}}.test:8025/
```

## 削除

```bash
# 指定したworktreeを削除
irie remove <worktree-name>

# 現在のworktreeを削除（シェル統合時は自動でプロジェクトルートに移動）
irie remove .

# 確認なしで削除
irie remove <worktree-name> --force
```

## ファイル構成

```
docker-compose-worktree/
├── WORKTREE.md                                  # このファイル
├── docker-compose.override.traefik-example.yml  # Traefik用テンプレート
├── docker-compose.override.loopback-example.yml           # Loopback用テンプレート
├── docker-compose.override.loopback-shared-db-example.yml # Loopback共有DB用テンプレート
├── post-setup.sh                                # worktree作成後の初期化処理
└── post-cleanup.sh                              # worktree削除時のクリーンアップ処理
```

※ Traefik、共有DBの定義はirie側の`shared-services/`で管理されています。

## 詳細ドキュメント

irieツールの詳細な使い方は [irie README](https://github.com/ode1022/irie) を参照してください。
