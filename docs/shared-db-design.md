# irie 共有DB設計方針

## 現状の方針: Docker統一

### 採用理由

1. **ネットワークのシンプルさ**
   - 同一Dockerネットワーク内で`DB_HOST=shared-postgres`のように名前で接続可能
   - ポート番号やIPアドレスの管理が不要

2. **複数バージョン対応**
   - `shared-postgres`, `shared-mysql`のようにコンテナ名で区別
   - 同一ポート（5432）で複数バージョン共存可能

3. **アプリとの親和性**
   - アプリがDockerで動く限り、DBもDockerが最もシンプル
   - 環境差異（OS、Docker環境）を吸収

### 比較検討した代替案

| 方式 | メリット | デメリット |
|------|---------|-----------|
| Docker | 名前で接続、環境統一 | 仮想化オーバーヘッド |
| Devbox | 軽量、Web版と相性良い | Dockerからの接続が複雑 |
| devenv | Nix全機能、自動起動 | 学習コスト高い |
| mise | シンプル | サービス自動起動なし |

Devbox/devenvは魅力的だが、Dockerコンテナからホストへの接続（`host.docker.internal`）が必要で、複数バージョンはポートで区別することになり複雑化する。

## 実装済みの構成

### ディレクトリ構成

```
irie/
├── shared-services/
│   ├── docker-compose.yml       # 共有サービス定義（PostgreSQL, MySQL, Traefik）
│   └── templates/
│       └── traefik/             # Traefik設定テンプレート

プロジェクト側/docker-compose-worktree/
├── post-setup.sh                # プロジェクト固有の初期化処理（migrate等）
├── docker-compose.override.traefik-example.yml
├── docker-compose.override.loopback-example.yml
└── docker-compose.override.loopback-shared-db-example.yml
```

### irieが渡す環境変数

詳細は[README.md](../README.md)の「post-setup.sh / post-cleanup.sh」セクションを参照。

### 処理フロー

**セットアップ:**
```
irie setup traefik/loopback <branch>
  ↓
1. git worktree作成
  ↓
2. docker-compose.override.yml生成（テンプレートから）
  ↓
3. hostsファイル更新（Loopback方式のみ）
  ↓
4. worktreeのdocker-compose up
  ↓
5. post-setup.sh があれば実行（環境変数を渡す）
   - DB作成、migrate、.envコピー等はここで実行
```

**クリーンアップ:**
```
irie cleanup <dir>
  ↓
1. worktreeのdocker-compose down
  ↓
2. post-cleanup.sh があれば実行（環境変数を渡す）
   - DB削除等はここで実行
  ↓
3. git worktree削除
  ↓
4. ブランチ削除（--force時のみ）
  ↓
5. hostsエントリ削除（Loopback方式のみ）
```

## 将来の検討事項

### Claude Code Web版対応

Claude Code Web版ではDockerが使いにくい（Docker-in-Docker）。
将来的にWeb版を主に使う場合、Devbox対応を検討。

```
.claude/settings.json
  ↓
SessionStartフック
  ↓
Devboxインストール & devbox services up
```

### Devbox/devenv移行の判断基準

- アプリ自体をDockerから脱却する場合
- Claude Code Web版を主に使う場合
- チーム全体でNix/Devboxに習熟した場合

現時点ではDockerベースを維持し、必要に応じて検討。

## 参考リンク

- [Devbox](https://github.com/jetify-com/devbox)
- [devenv](https://devenv.sh/)
- [devenv Claude Code integration](https://devenv.sh/integrations/claude-code/)
- [Claude Code Hooks](https://docs.claude.com/en/docs/claude-code/hooks)
