# irie - Git Worktree + Docker 並行開発ツール

Docker環境でのWebアプリ開発に特化した、git worktree並行開発ツールです。
Laravel、Rails、FastAPI等のフレームワークと相性が良く、複数ブランチを同時に動かしながら開発できます。

## 特色

- **Git Worktree + Docker環境を自動構築** - `irie add feat/xxx` だけでworktree作成、docker-compose.override.yml生成、コンテナ起動、DB作成、マイグレーションまで一括実行
- **ポート管理不要** - 通常の並行開発では手動でポート番号を管理する必要がありますが、irieならブランチ名ベースのURL（`feat-xxx.project.localhost`）でアクセス可能。ポート競合を気にせず何個でもworktreeを並行稼働
- **hosts設定不要** - Traefik方式なら`*.localhost`はブラウザが自動解決、面倒なhosts編集は一切不要
- **パスワード共有が簡単** - サブドメイン間でChromeの保存パスワードを共有。ルートドメインで一度ログインすれば、全worktreeで自動入力
- **共有DB** - 複数worktreeで1つのPostgreSQLを共有、DataGrip等の設定も1回だけ
- **WSL2完全対応** - WSL2 + Windows環境での開発を想定した設計。JetBrains IDE連携も対応
- **Bare構成で安全** - 親フォルダで誤って`git commit`できない設計
- **Claude Code連携** - `irie init`でdocker-compose.ymlを解析してテンプレートを自動生成

> **Note:** Dockerを使わないプロジェクトでも、`irie clone/convert/add/remove/list/cd/open`はworktree管理ツールとして使用できます（`irie init/override`以外）。

## インストール

```bash
git clone git@github.com:ode1022/irie.git ~/.irie

# .bashrcや.zshrcに追加
export PATH="$HOME/.irie/bin:$PATH"
eval "$(irie shell-init)"   # シェル統合（自動移動）

# 補完をインストール（オプション）
irie completion install
```

## クイックスタート

### 既存プロジェクトで使う（irie対応済み）

```bash
# プロジェクトをBare構成でクローン
irie clone git@github.com:user/my-project.git
cd my-project/main

# .envセットアップ + 共有DBセットアップ + コンテナ起動（Claude Code連携）
irie init
# → 共有DBが未起動なら自動セットアップ
# → .envのコピー・設定
# → irie override traefik --setup を実行

# または手動セットアップ（Claude Codeがない場合）
# → 「共有サービス」セクションと「手動で作成する場合」セクションを参照

# 新しいworktreeを作成（自動で移動）
irie add feat/new-feature --base origin/main

# 開発...

# worktree間を移動
irie cd main

# 不要になったら削除（自動でプロジェクトルートに移動）
irie remove .
```

### 新規プロジェクトをirie対応にする

```bash
cd your-project

# テンプレートを自動生成（Claude Code連携）
irie init

# または手動セットアップ（Claude Codeがない場合）
# → 「共有サービス」セクション: 共有DBの起動
# → 「手動で作成する場合」セクション: テンプレートファイルの作成
```

### 既存リポジトリをBare構成に変換

```bash
cd existing-project
irie convert
# → .bare/ と main/ に再構成される
```

## 基本コマンド

| コマンド | 説明 |
|---------|------|
| `irie add <branch>` | worktreeを作成（mainと同じDB・デフォルト） |
| `irie add <branch> --separate-db` | worktreeを作成（専用DB・マイグレーション実行） |
| `irie remove <name>` | worktreeを削除 |
| `irie remove .` | 現在のworktreeを削除 |
| `irie cd <name>` | worktreeに移動 |
| `irie list` | worktree一覧（git状態含む） |
| `irie info` | 現在のworktree情報（URL、DB名など） |
| `irie open` | エディタで開く |
| `irie clone <url>` | Bare構成でクローン |
| `irie convert` | 既存リポジトリをBare構成に変換 |
| `irie init` | テンプレートを自動生成（Claude Code連携） |
| `irie override <mode>` | テンプレートからdocker-compose.override.ymlを生成 |
| `irie update` | irie自体を更新 |

---

# 詳細リファレンス

## ポート管理不要の仕組み

irieでは、通常のDocker並行開発で必要なポート番号の手動管理が不要です。

**Traefik方式**
- リバースプロキシ（Traefik）がホスト名でルーティングを振り分け
- `feat-xxx.project.localhost` のようなURLでアクセス
- hosts設定不要（`*.localhost`はブラウザが自動解決）
- 共有DBを使用（DBツールの設定が1回で済む、リソース効率が良い）

### DB名の命名規則

DB名は `<プロジェクト名>_<worktree名>` の形式で自動生成されます。

**プロジェクト名の取得方法（優先順位）：**
1. gitリポジトリ名（`git config --get remote.origin.url` から取得）
2. カレントディレクトリ名（フォールバック）

これにより、複数プロジェクトで共有PostgreSQLを使用しても、DB名が衝突しません。

## Traefik方式

### 基本的な使い方

```bash
# ブランチ名を指定（mainと同じDBを使用・デフォルト）
irie add feat/new-feature

# 専用DBを使用（マイグレーション・シーダー実行）
irie add feat/db-change --separate-db

# ディレクトリ名を直接指定
irie add app7

# ルートドメイン（<project>.localhost）で作成
irie add main --root

# mainブランチから派生して作成（開発時推奨）
irie add feat/new-feature --base origin/main
```

### DBモード: --separate-db

デフォルトでは、worktreeはmainと**同じDB名を共有**します。これにより：
- マイグレーション・シーダーの実行が不要
- worktree作成が高速
- DBスキーマに変更がない作業に最適

**DBスキーマを変更する作業**では `--separate-db` を指定：

```bash
irie add feat/db-migration --separate-db
```

これにより：
- 専用のDB名が割り当てられる
- マイグレーション・シーダーが実行される
- mainのDBに影響を与えない

**注意**: 同じDBを共有している場合、複数worktreeで同時にDB操作すると競合の可能性があります。

**テストDBについて（推奨）:**

テストDBは`--separate-db`の指定に関わらず、**常にworktree専用**にすることを推奨します。

理由：
- テストの並行実行（`php artisan test --parallel`等）で競合を防ぐ
- 各worktreeで独立してテストを実行可能
- テスト用マイグレーションは常に実行

post-setup.shでの実装例：
```bash
# メインDBのマイグレーション（DBモードで分岐）
if [ "$WORKTREE_USE_SEPARATE_DB" = "true" ]; then
    docker compose exec -T app php artisan migrate:fresh --seed
else
    echo "mainと同じDBを使用（マイグレーションをスキップ）"
fi

# テストDBのマイグレーション（常に実行）
docker compose exec -T app php artisan migrate:fresh --env=testing
```

### --baseオプション

指定したブランチから新しいブランチを派生させます。

```bash
# origin/mainから派生（最新のmainを取得してから派生）
irie add feat/new-feature --base origin/main

# ローカルのmainから派生
irie add feat/new-feature --base main

# 別のfeatureブランチから派生
irie add feat/another-feature --base feat/new-feature
```

**注意**: `--base`を指定しない場合は、現在のブランチから派生します。通常の開発では `--base origin/main` の使用を推奨します。

### --rootオプションとパスワード共有

ブラウザはドメインごとにパスワードを保存します。サブドメイン間でパスワードを共有するには、**ルートドメインでパスワードを保存しておく**のがおすすめです。

```bash
# ルートドメイン（<プロジェクト名>.localhost）でmainを作成
irie add main --root
```

**メリット:**
- ルートドメイン（例: `my-project.localhost`）で保存したパスワードが、サブドメイン（例: `feature-a.my-project.localhost`）でも自動入力される
- 各featureブランチで毎回ログイン情報を入力する手間が省ける

**推奨ワークフロー:**
1. `main --root`でルートドメイン環境を作成
2. ルートドメインでログインし、パスワードを保存
3. 各featureブランチはサブドメインで開発（パスワードが自動入力される）

### 名前変換ルール

| 入力 | ディレクトリ名 | ホスト名 | DB名 |
|------|--------------|---------|------|
| `feat/new-feature` | `new-feature` | `new-feature.<project>.localhost` | `<project>_new_feature` |
| `feat/PROJ-123-new-feature` | `PROJ-123-new-feature` | `123-new-feature.<project>.localhost` | `<project>_123_new_feature` |
| `app7` | `app7` | `app7.<project>.localhost` | `<project>_app7` |
| `main --root` | `main` | `<project>.localhost` | `<project>_main` |

**変換ルール:**
- ディレクトリ名: `feat/`プレフィックス削除、残りの`/`は`-`に変換
- ホスト名（サブドメイン）: 小文字化、`_`は`-`に変換
- DB名: `<プロジェクト名>_<worktree名>`（小文字化、`/`と`-`は`_`に変換）

**チケットキー省略（Backlog/Jira/Linear対応）:**

ブランチ名がチケットシステムのプロジェクトキー形式（`PROJ-123-xxx`等）で始まる場合、サブドメイン・TRAEFIK_ID・DB名からプロジェクトキー部分を自動削除します。

**理由:**
- PostgreSQLのDB名は63バイト制限があり、長いプロジェクト名+ブランチ名でエラーになる
- Laravelの並列テストでは`_testing_test_1`〜`_testing_test_16`のサフィックスが追加されるため、さらに制限が厳しい

**長さ制限:**
- サブドメイン: 63文字（DNSラベル制限）
- DB名: 44文字（63文字 - `_testing`(8文字) - `_test_16`(8文字) - 余裕(3文字)）
- 超過時は単純に切り詰め

### アクセスURL

```
アプリ:    http://<subdomain>.<project>.localhost/
Traefikダッシュボード: http://traefik.localhost/
```

プロジェクト固有のサービス（Vite、MinIO、Mailpit等）を追加する場合の例：
```
Vite:      http://vite-<subdomain>.<project>.localhost/
MinIO:     http://minio-<subdomain>.<project>.localhost/
Mailpit:   http://mailpit-<subdomain>.<project>.localhost/
```

### 前提条件

- Traefikコンテナ（自動起動、irie側のshared-servicesで管理）
- 共有DB（自動起動、irie側のshared-servicesで管理）
- `*.localhost`ドメインはhosts設定不要（ブラウザが自動解決）

## irie clone

リポジトリをBare構成でクローンします。

```bash
# 基本
irie clone git@github.com:user/repo.git

# ディレクトリ名を指定
irie clone git@github.com:user/repo.git my-project

# ブランチを指定
irie clone git@github.com:user/repo.git -b develop

# mainワークツリーを作成しない（.bareのみ）
irie clone git@github.com:user/repo.git --no-main
```

## irie convert

既存の通常リポジトリをBare構成に変換します。

```bash
cd existing-project
irie convert

# 変換内容を確認（実行しない）
irie convert --dry-run
```

**変換前後の構成:**
```
# 変換前
existing-project/
├── .git/           # 通常のgitディレクトリ
└── src/

# 変換後
existing-project/
├── .bare/          # Bareリポジトリ
└── main/           # 元の作業ディレクトリがworktreeに
    └── src/
```

## irie list

```bash
# 一覧表示（git状態含む、現在のworktreeに*マーク）
irie list

# シンプル表示（git状態なし）
irie list --simple

# 詳細表示（変更ファイル一覧）
irie list --verbose

# 名前のみ表示（スクリプト連携用）
irie list --name

# パスのみ表示
irie list --path
```

**出力例:**
```
* main              clean
  feature-a         dirty (3 files), ahead 2
  feature-b         clean, behind 1
```

## irie info

作成済みworktreeの情報（URL、DB名など）を確認できます。

```bash
# カレントディレクトリの情報
irie info

# 別のworktreeの情報
irie info ../app1
```

**出力例:**
```
=== Worktree情報 ===
ディレクトリ: 123-new-feature
ブランチ: feat/PROJ-123-new-feature
パス: /path/to/project/123-new-feature

方式: traefik
URL: https://123-new-feature.my-project.localhost/
TRAEFIK_ID: my-project-123-new-feature
DB名: my_project_123_new_feature
```

### プロジェクト固有情報の追加

`post-setup.sh`に`irie_info`関数を定義すると、`irie info`実行時にプロジェクト固有のURLも表示されます。

```bash
# post-setup.sh の先頭に追加
irie_info() {
    echo "管理画面=http://${WORKTREE_FQDN}/admin/login"
    if [ -n "$WORKTREE_TRAEFIK_ID" ]; then
        echo "Vite=http://vite-${WORKTREE_FQDN}/"
    else
        echo "Vite=http://${WORKTREE_FQDN}:5173/"
    fi
}

# IRIE_INFO_ONLY=true の場合は関数定義のみで終了
if [ "${IRIE_INFO_ONLY:-}" = "true" ]; then
    return 0 2>/dev/null || exit 0
fi

# 以下、実際のセットアップ処理...
```

**重要**: `irie_info`関数と`IRIE_INFO_ONLY`ガードは`set -e`より前（ファイル先頭）に配置してください。

## irie cd

```bash
# fzf/pecoで対話的に選択
irie cd

# 直接指定
irie cd main
```

**前提条件:**
- シェル統合が有効化されていること（`eval "$(irie shell-init)"`）
- 現在のディレクトリと同じ親ディレクトリにworktreeがあること

### シェル統合による自動移動

シェル統合を有効にすると、以下のコマンドで自動的にディレクトリ移動が行われます：

| コマンド | 移動先 |
|---------|--------|
| `irie add <branch>` | 作成したworktreeディレクトリ |
| `irie remove .` | プロジェクトルート（削除したworktree内にいた場合） |

### fzf/peco連携

fzfまたはpecoがインストールされている場合、`irie cd`を引数なしで実行すると対話的に選択できます。

```bash
# fzfのインストール（Ubuntu/Debian）
sudo apt install fzf

# または pecoのインストール
sudo apt install peco
```

## irie open

worktreeをエディタで開きます。WSL、Linux、macOSに対応しています。

```bash
irie open              # 現在のworktree
irie open feature-a    # 指定したworktree
irie open --setup      # エディタを再設定
```

### 初回実行時のエディタ設定

初回実行時にインストール済みエディタを自動検出し、一覧から選択できます：

```
インストール済みエディタを検出中...

  1) PhpStorm
     /mnt/c/Program Files/JetBrains/PhpStorm 2025.2.1/bin/phpstorm64.exe

  2) Cursor
     /mnt/c/Users/user/AppData/Local/Programs/cursor/Cursor.exe

  3) その他（パスを入力）

使用するエディタを選択してください [1-3]:
```

選択したエディタは `~/.config/irie/config` に保存されます。

### 対応エディタ

JetBrains IDEはインストールされているものを動的に検出します（最新バージョン優先）。

**JetBrains IDE（動的検出）:**
- PhpStorm, WebStorm, IntelliJ IDEA, PyCharm, RubyMine
- GoLand, CLion, DataGrip, Rider, Fleet
- Android Studio, Aqua, RustRover, Writerside

**その他のエディタ:**
| エディタ | WSL | Linux | macOS |
|---------|-----|-------|-------|
| VS Code | ✅ | ✅ | ✅ |
| Cursor | ✅ | ✅ | ✅ |
| Zed | ✅ | ✅ | ✅ |
| Sublime Text | - | ✅ | ✅ |
| Neovim | - | ✅ | ✅ |
| Vim | - | ✅ | ✅ |
| Emacs | - | ✅ | ✅ |

### エディタ検出の仕組み

| プラットフォーム | 検出方法 |
|-----------------|---------|
| **WSL** | `/mnt/c/Program Files/JetBrains/` を動的スキャン、`/mnt/c/Users/*/AppData/` 等を探索 |
| **macOS** | `/Applications/*.app` の存在確認 |
| **Linux** | `command -v`、snap/flatpakパス、JetBrains Toolboxパスを順に探索 |

### 設定の変更

```bash
# 現在の設定を確認
irie config --list

# エディタを直接指定
irie config editor "/path/to/editor"

# エディタ設定を削除（次回実行時に再選択）
irie config --unset editor

# 対話的に再設定
irie open --setup
```

## irie override

テンプレートからdocker-compose.override.ymlを生成します。`irie init`後にmainで環境を構築する際に使用します。

```bash
cd my-project/main

# docker-compose.override.ymlのみ生成
irie override traefik

# 生成 + コンテナ起動 + post-setup.sh実行（初回セットアップ用）
irie override traefik --setup
```

**モード:**
| モード | 説明 |
|--------|------|
| `traefik` | Traefik方式（共有DB） |

**--setupオプション:**
初回のmainセットアップ時に使用。以下を一括実行：
1. docker-compose.override.ymlの生成
2. `docker compose up -d`でコンテナ起動
3. `post-setup.sh`の実行（.envコピー、DB作成、マイグレーション等）

## irie remove

```bash
# 確認ありで削除
irie remove new-feature

# 現在のworktreeを削除
irie remove .

# fzfで対話的に選択
irie remove

# 確認なしで削除
irie remove new-feature --force
```

**シェル統合時の自動移動:**
シェル統合を設定している場合、削除したworktree内にいると自動的にプロジェクトルートへ移動します。

**削除対象:**
| 対象 | 説明 |
|------|------|
| Dockerコンテナ | `docker compose down -v`でコンテナとボリュームを削除 |
| 共有DB | `<project>_<worktree>` と `<project>_<worktree>_testing` を削除 |
| Git worktree | worktreeディレクトリを削除 |
| ブランチ | マージ済みは自動削除、未マージは`--force`時のみ削除 |

## リポジトリ構成（Bare構成）

irieは**Bareリポジトリ構成**を推奨しています。

```
my-project/
├── .bare/               # Bareリポジトリ（git実体）
├── main/                # worktree
├── feature-a/           # worktree
└── feature-b/           # worktree
```

**メリット:**
- 全worktreeが対等（mainが特別扱いされない）
- 親フォルダで誤って `git add/commit` できない（安全）
- 親フォルダから `irie` コマンドで全worktreeを操作可能（`irie add` は `main` を基準に実行）
- どのworktreeからも `git worktree list` で同じ結果

**親フォルダからの操作:**
```bash
cd my-project/

# git status は動かない（安全）
git status  # → fatal: not a git repository

# irie コマンドは動く（.bare を自動検出）
irie list              # 全worktree一覧（git状態含む）
irie add feature-new   # mainを基準にworktree作成
irie cd feature-a      # feature-aに移動

# 以下はworktree名の指定が必要（親フォルダはworktreeではないため）
irie info main         # mainの情報を表示
irie open feature-a    # feature-aをエディタで開く
```

## 共有サービス

TraefikやDBなどの共有サービスは、irie側の`shared-services/`で管理されます。

### 自動 vs 手動セットアップ

| サービス | セットアップ |
|----------|-------------|
| Traefik | 自動（`irie add`時に未起動なら自動起動） |
| PostgreSQL/MySQL | 手動（初回のみ起動が必要） |

### 共有DBの起動（初回のみ）

```bash
cd ~/.irie/shared-services

# PostgreSQLの場合
cp templates/postgres.yml .
docker compose -f postgres.yml up -d

# MySQLの場合
cp templates/mysql.yml .
docker compose -f mysql.yml up -d
```

**注意**: postgres.ymlとmysql.ymlは同じ`shared-db`ネットワークを使用するため、どちらか一方のみを起動してください。その他DBやミドルウェア（MongoDB、Redis等）も同様のymlファイルを作成して共有サービスとして運用できます。

### DB接続情報

共有DBは`127.0.0.1`にバインドされます。

**PostgreSQL:**
| 項目 | 値 |
|------|-----|
| Host | `127.0.0.1` |
| Port | `5432`（バージョン別: 5433, 5434, ...） |
| User | `root` |
| Password | `root` |
| Database | `postgres` |

**MySQL:**
| 項目 | 値 |
|------|-----|
| Host | `127.0.0.1` |
| Port | `3306`（バージョン別: 3307, 3308, ...） |
| User | `root` |
| Password | `root` |

**注意**: PostgreSQLは接続時にデータベース名の指定が必須です。`postgres`データベースに接続すると、データベースエクスプローラーから他のDB（`<project>_<branch>`形式）にアクセスできます。

### 複数バージョンの共存

異なるプロジェクトで異なるDBバージョンが必要な場合、別ポートで起動できます：

```bash
cd ~/.irie/shared-services

# PostgreSQL 16を追加する例
cp templates/postgres.yml postgres16.yml
# postgres16.ymlを編集:
#   - image: postgres:16
#   - container_name: shared-postgres-16
#   - ports: "127.0.0.1:5433:5432"
#   - volumes: postgres16-data:/var/lib/postgresql/data
docker compose -f postgres16.yml up -d
```

プロジェクトのoverride.ymlで`DB_HOST`と`DB_PORT`を適切に設定してください。

### テンプレートの仕組み

```
irie/shared-services/
├── templates/              # テンプレート（gitコミット）
│   ├── traefik.yml
│   ├── generate-certs.sh
│   ├── postgres.yml
│   └── mysql.yml
├── traefik.yml             # 実際に使用する定義（gitignore、irie add時に自動コピー）
├── postgres.yml            # 実際に使用する定義（gitignore、手動でコピー）
└── traefik/                # Traefik設定・証明書（gitignore、自動生成）
```

- Traefikは`irie add`時にテンプレートから自動コピー・起動
- DB（postgres.yml/mysql.yml）は手動でコピー・起動（上記「共有DBの起動」参照）
- コピー後は自由にカスタマイズ可能（バージョン変更、別DBの追加など）

### プロジェクト固有のDB設定

プロジェクトがPostGISなどのDB拡張機能を使用している場合、`shared-services/postgres.yml`のイメージを変更してください：

```yaml
services:
  postgres:
    image: postgis/postgis:15-3.5  # postgres:15 から変更
```

> **Note:** テンプレートからコピーされたファイル（`postgres.yml`等）のイメージバージョンは、プロジェクトの要件に合わせて適宜更新してください。

### HTTPSポートについて

デフォルトではHTTPSポートは`8443`を使用しています（`https://xxx.localhost:8443/`）。

これはホスト側でVPNソフトなどが443ポートを使用している場合があるためです。443ポートが空いている環境では、`shared-services/traefik.yml`で変更できます：

```yaml
ports:
  - "127.0.0.1:80:80"
  - "127.0.0.1:443:443"    # 8443 → 443 に変更
  - "127.0.0.1:8080:8080"
```

## プロジェクトへの導入

### irie側とプロジェクト側の役割分担

| 担当 | 処理内容 |
|------|---------|
| **irie側** | git worktree作成、docker-compose.override.yml生成、hosts設定、コンテナ起動/停止、共有サービス管理 |
| **プロジェクト側** | .envコピー、DB作成/削除、マイグレーション、依存関係インストール等 |

irieは汎用ツールのため、プロジェクト固有の処理（DBスキーマ、フレームワーク固有コマンド等）は`post-setup.sh`/`post-cleanup.sh`で実装します。

### Claude Code連携（推奨）

```bash
cd your-project
irie init
# → Claude Codeがdocker-compose.ymlを解析してテンプレートを自動生成
```

- プロンプトはirie側で管理（常に最新版が使用される）
- Claude Codeがない環境ではエラーになる

サンプルテンプレートは`~/.irie/project-templates/examples/`にあります。

### 初回ビルドについて

worktree間でDockerイメージを共有するため、元のdocker-compose.ymlで`build:`を使用しているサービスには、override側で`image:`を指定する必要があります。

mainブランチで初回起動時にイメージがビルドされ、以降のworktreeではそのイメージを共有します。

**イメージ名の規則:**
`<プロジェクト名>-<サービス名>:latest`（例: `my-project-app:latest`）

### 手動で作成する場合

以下のファイルを用意してください：

```
your-project/
├── docker-compose.override.traefik-example.yml     # Traefik用テンプレート
├── post-setup.sh                                   # 初期化処理（オプション）
└── post-cleanup.sh                                 # クリーンアップ処理（オプション）
```

mainで使用する場合は、テンプレート作成後に`irie override`でdocker-compose.override.ymlを生成：

```bash
irie override traefik
```

### post-setup.sh / post-cleanup.sh

セットアップ・クリーンアップ時にプロジェクト固有の処理を実行できます。

**post-setup.sh** - worktree作成後に実行（.envコピー、DB作成、migrate等）
**post-cleanup.sh** - worktree削除時に実行（共有DB削除等）

#### 利用可能な環境変数

**post-setup.sh向け:**
| 変数 | 説明 | 例 |
|------|------|-----|
| `WORKTREE_DIR` | ディレクトリ名 | `new-feature` |
| `WORKTREE_BRANCH` | ブランチ名 | `feat/new-feature` |
| `WORKTREE_FQDN` | ホスト名 | `new-feature.project.localhost` |
| `WORKTREE_DB_NAME` | DB名 | `project_new_feature` |
| `WORKTREE_SEPARATE_DB_NAME` | worktree専用DB名 | `project_new_feature` |
| `WORKTREE_USE_SEPARATE_DB` | 専用DBフラグ | `false`（`--separate-db`時は`true`） |
| `WORKTREE_SOURCE_DIR` | 元worktreeパス | `/path/to/main` |
| `WORKTREE_TRAEFIK_ID` | Traefikルーター識別子 | `project-app1` |
| `IRIE_LIB_DIR` | ヘルパー関数パス | `/path/to/irie/lib` |

**post-cleanup.sh向け:**
| 変数 | 説明 |
|------|------|
| `WORKTREE_DIR` | ディレクトリ名 |
| `WORKTREE_PATH` | worktreeのフルパス |
| `WORKTREE_SOURCE_DIR` | 元worktreeパス |
| `WORKTREE_FORCE` | 強制削除フラグ |
| `WORKTREE_USE_SEPARATE_DB` | 専用DBフラグ |
| `WORKTREE_SEPARATE_DB_NAME` | worktree専用DB名 |
| `WORKTREE_DB_NAME` | DB名 |
| `IRIE_LIB_DIR` | ヘルパー関数パス |

#### ヘルパー関数（lib/helpers.sh）

```bash
source "${IRIE_LIB_DIR}/helpers.sh"

# 利用可能な関数:
sed_inplace "s/old/new/" file             # sed -i のOS差異を吸収
wait_for_postgres "container"             # PostgreSQL起動待機（最大30秒）
wait_for_mysql "container"                # MySQL起動待機（最大30秒）
copy_if_exists "src" "dest"               # ファイルが存在すればコピー
strip_ticket_project_key "dir_name"       # チケットキー削除（PROJ-123-xxx → 123-xxx）
generate_safe_db_name "project" "dir"     # 安全なDB名生成（44文字制限）

# カラー出力用変数: $BLUE, $GREEN, $YELLOW, $NC
```

#### 依存関係の管理（推奨）

worktree追加時の時間を短縮するため、依存関係はdocker build時にインストールし、post-setup.shでは実行しないことを推奨します。

**ベストプラクティス**: プロジェクトディレクトリにライブラリフォルダが作成される言語（PHP: `vendor/`、Node.js: `node_modules/`など）では、docker-compose.yamlでanonymous volumeを使用し、ホスト側のフォルダをマウントしないようにします。

```yaml
# docker-compose.yaml
services:
  app:
    build: ./docker
    volumes:
      - ./src:/var/www/html              # ソースコードをマウント
      - /var/www/html/vendor             # anonymous volume: Docker側のvendorを使用
```

これにより:
- docker build時にインストールした依存関係がそのまま使用される
- worktree追加時に`composer install`等が不要になり高速化
- ホスト側に空の`vendor/`があっても上書きされない

**entrypointでの自動同期（オプション）**: lockファイル変更時に自動でパッケージマネージャーを実行するentrypointを設定すると、git pull後の手動実行が不要になります。

```bash
#!/bin/bash
# entrypoint-local.sh（開発環境専用）

LOCK_HASH=$(md5sum composer.lock 2>/dev/null | cut -d' ' -f1)
STORED_HASH=""
if [ -f vendor/.composer.lock.hash ]; then
    STORED_HASH=$(cat vendor/.composer.lock.hash)
fi

if [ -n "$LOCK_HASH" ] && [ "$LOCK_HASH" != "$STORED_HASH" ]; then
    echo "composer.lock changed, running composer install..."
    composer install --no-interaction
    echo "$LOCK_HASH" > vendor/.composer.lock.hash
fi

exec "$@"
```

```dockerfile
# Dockerfile（localステージのみ）
FROM base AS build-main-local
COPY --chmod=755 docker/entrypoint-local.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

Node.jsの場合は`package-lock.json`と`npm install`に置き換えてください。

**定期的なdocker compose build**: entrypointでの自動同期を使用する場合、イメージ内の依存関係が古くなっていきます。パッケージの差分が大きくなるとinstall時間が増えるため、定期的に`docker compose build`でイメージを更新することを推奨します。

#### サンプル: post-setup.sh（Laravel）

```bash
#!/bin/bash

# === irie info 用の情報出力関数（先頭に配置） ===
irie_info() {
    echo "管理画面=http://${WORKTREE_FQDN}/admin/login"
    echo "Mailpit=http://mailpit-${WORKTREE_FQDN}/"
}

if [ "${IRIE_INFO_ONLY:-}" = "true" ]; then
    return 0 2>/dev/null || exit 0
fi

set -e
source "${IRIE_LIB_DIR}/helpers.sh"

# .envファイルのコピー
copy_if_exists "${WORKTREE_SOURCE_DIR}/.env" "./.env"
copy_if_exists "${WORKTREE_SOURCE_DIR}/.env.testing" "./.env.testing"

# DB設定（共有DBを使用）
DB_CONTAINER="shared-postgres"
wait_for_postgres "$DB_CONTAINER"
sed_inplace "s/^DB_HOST=.*/DB_HOST=${DB_CONTAINER}/" .env
sed_inplace "s/^DB_DATABASE=.*/DB_DATABASE=${WORKTREE_DB_NAME}/" .env

# 専用DBモード（--separate-db）の場合のみDB作成
if [ "$WORKTREE_USE_SEPARATE_DB" = "true" ]; then
    docker exec "$DB_CONTAINER" psql -U root -d postgres \
      -c "CREATE DATABASE ${WORKTREE_DB_NAME};" 2>/dev/null || true
fi

# 依存関係インストールは不要（Docker側で管理）
# docker-compose.yamlでanonymous volumeを使用し、docker build時の依存関係を利用

# マイグレーション・シーダー実行（専用DBモードの場合のみ）
if [ "$WORKTREE_USE_SEPARATE_DB" = "true" ]; then
    echo -e "${BLUE}専用DBを使用（マイグレーション・シーダーを実行）${NC}"
    docker compose exec -T app php artisan migrate:fresh --seed
else
    echo -e "${BLUE}mainと同じDBを使用（マイグレーション・シーダーをスキップ）${NC}"
fi
```

#### サンプル: post-cleanup.sh

```bash
#!/bin/bash
set -e
source "${IRIE_LIB_DIR}/helpers.sh"

# 専用DBモード（--separate-db）の場合のみメインDB削除
if [ "$WORKTREE_USE_SEPARATE_DB" = "true" ]; then
    echo -e "${BLUE}  → 専用DBを削除中...${NC}"
    docker exec shared-postgres psql -U root -d postgres \
      -c "DROP DATABASE IF EXISTS ${WORKTREE_DB_NAME};" 2>/dev/null || true
else
    echo -e "${BLUE}  → mainと同じDBを使用: メインDB削除をスキップ${NC}"
fi

# テストDBは常に削除（worktree専用）
docker exec shared-postgres psql -U root -d postgres \
  -c "DROP DATABASE IF EXISTS ${WORKTREE_SEPARATE_DB_NAME}_testing;" 2>/dev/null || true
```

#### よくある処理パターン

| 処理 | 実装例 |
|------|--------|
| Node.js依存関係 | `docker compose exec -T nodejs npm install` |
| キャッシュクリア | `docker compose exec -T app php artisan cache:clear` |
| ストレージリンク | `docker compose exec -T app php artisan storage:link` |
| キー生成 | `docker compose exec -T app php artisan key:generate` |
| Rails DB準備 | `docker compose exec -T app rails db:create db:migrate db:seed` |
| Django マイグレーション | `docker compose exec -T app python manage.py migrate` |
| MySQL DB作成 | `docker exec "$DB_CONTAINER" mysql -uroot -proot -e "CREATE DATABASE ${WORKTREE_DB_NAME};"` |

## 対応環境

| 環境 | 対応状況 |
|------|----------|
| WSL2 + Windows | ✅ 推奨（主要な開発環境として想定） |
| Linux | ✅ 対応 |
| macOS | ✅ 対応（制限事項あり、下記参照） |

### macOSでの制限事項

**PostGISイメージ（Apple Siliconのみ）**

公式の`postgis/postgis`イメージはARM64に未対応のため（[docker-postgis#216](https://github.com/postgis/docker-postgis/issues/216)）、macOS Apple Siliconでは代替イメージ`ghcr.io/baosystems/postgis`を使用してください。

公式イメージがARM64対応した時点で、公式に戻す予定です。

## 必要な依存ソフト

| ソフト | 必須 | 最小バージョン | 確認済みバージョン | 備考 |
|--------|------|---------------|-------------------|------|
| Git | ✅ | 2.48.0 | 2.52.0 | `--relative-paths`オプションに必要 |
| Docker | ✅ | - | 28.1.1 | |
| Docker Compose | ✅ | - | 2.35.1 | V2形式（`docker compose`コマンド） |
| Bash | ✅ | 4.0 | 5.1.16 | |
| fzf | ⭐ | - | 0.67.0 | 任意だが強く推奨 |
| Claude Code | ⭐ | - | - | `irie init`で使用（任意） |

※ Docker/Docker Composeの最小バージョンは未検証です。上記は動作確認済みのバージョンです。

### fzfについて

fzfは任意ですが、インストールすると以下のコマンドで対話的な選択が可能になります：

- `irie cd` - worktree一覧から選択して移動
- `irie remove` - 削除するworktreeを選択
- `irie open` - 開くworktreeを選択

```bash
# インストール（Ubuntu/Debian）
sudo apt install fzf

# インストール（macOS）
brew install fzf
```

## トラブルシューティング

### 502 Bad Gateway
```bash
docker compose restart nginx
```

### Viteが読み込めない（白い画面）
1. `VITE_DEV_SERVER_URL`環境変数の確認
2. nodejsコンテナ再起動：`docker compose up -d --force-recreate nodejs`

### DBに接続できない
```bash
docker ps | grep shared-postgres  # 起動確認
```

### Traefikがルーティングしない
```bash
docker ps | grep traefik          # 起動確認
curl http://localhost:8080/api/http/routers | jq  # ルーター確認
```

### 419 CSRF Token Mismatch エラー
`SANCTUM_STATEFUL_DOMAINS`にホスト名が追加されているか確認。

## ファイル構成

```
irie/
├── irie                   # メインコマンド
├── irie-add-traefik       # Traefik方式
├── irie-clone             # Bare構成でクローン
├── irie-convert           # Bare構成に変換
├── irie-init              # Claude Codeでテンプレート生成
├── irie-remove            # 削除
├── irie-list              # Worktree一覧
├── irie-info              # Worktree情報
├── irie-cd                # 移動
├── irie-open              # エディタで開く
├── irie-config            # 設定管理
├── irie-update            # 自己更新
├── irie-shell-init        # シェル統合
├── irie-completion        # 補完スクリプト
├── lib/                   # 共通ライブラリ
│   ├── git-helpers.sh
│   ├── helpers.sh
│   ├── config.sh
│   └── editors.sh
├── shared-services/       # 共有サービス定義
│   └── templates/
├── project-templates/     # プロジェクト用サンプル
│   ├── examples/
│   └── prompts/
└── tests/                 # テスト
```

### データディレクトリ

irieは`~/.irie/`にランタイムデータを保存します：

```
~/.irie/
├── bin/                   # irieコマンド本体
├── lib/                   # 共通ライブラリ
├── shared-services/       # 共有サービス定義・データ
└── worktrees/             # worktree情報（DBモード等）
    └── <project>/
        └── <worktree>.vars
```

**worktrees/**について：
- `irie add`時にworktreeごとの設定を`.vars`ファイルとして保存
- `irie info`でDBモード（same-db/separate-db）の表示に使用
- `irie remove`でpost-cleanup.shへの環境変数渡しと削除に使用
- 手動でworktreeを削除した場合、孤立した`.vars`ファイルが残る可能性あり（将来的にクリーンアップコマンドで対応予定）

## 開発者向け

### テスト実行

```bash
# batsのインストール（Ubuntu/Debian）
sudo apt install bats

# batsのインストール（macOS）
brew install bats-core

# テスト実行
bats tests/
```

## ライセンス

MIT
