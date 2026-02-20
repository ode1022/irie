# 競合ツール調査

Git worktree管理ツールの調査結果。新機能検討時の参考資料。

## 調査日

2026年2月（最終更新）

## ツール一覧（star数順）

| ツール | Stars | 言語 | フォルダ構成 | 特徴 |
|--------|-------|------|-------------|------|
| [gtr](https://github.com/coderabbitai/git-worktree-runner) | 1,351 | Shell | `../project-worktrees/feature/` | AI/エディタ連携、hooks |
| [git-worktree.nvim](https://github.com/ThePrimeagen/git-worktree.nvim) | 848 | Lua | Bare推奨 | Neovimプラグイン（更新停滞） |
| [wtp](https://github.com/satococoa/wtp) | 365 | Go | `../worktrees/branch/` | .wtp.yml hooks、exec |
| [gwq](https://github.com/d-kuro/gwq) | 349 | Go | `~/worktrees/` | fzf内蔵、グローバル管理 |
| [wt](https://github.com/yankeexe/git-worktree-switcher) | 252 | Shell | 任意 | シンプル、軽量 |
| [phantom](https://github.com/aku11i/phantom) | 195 | TypeScript | `.git/phantom/worktrees/` | fzf内蔵、MCP連携 |
| [worktree](https://github.com/agenttools/worktree) | 12 | TypeScript | - | Claude Code + GitHub Issues連携 |

## 機能比較

| 機能 | irie | gtr | gwq | wtp | phantom |
|------|------|-----|-----|-----|---------|
| worktree作成 | ✅ | ✅ | ✅ | ✅ | ✅ |
| worktree削除 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 一覧表示 | ✅ | ✅ | ✅ | ✅ | ✅ |
| worktree内から一覧表示 | ✅ | ⚠️ 自分のみ | ? | ✅ | ? |
| 状態表示 | ✅(listに統合) | ✅ | ✅(watch対応) | ✅(managed/unmanaged) | ✅ |
| ディレクトリ移動 | ✅ | ✅ | ✅ | ✅ | ✅ |
| エディタ起動 | ✅ | ✅ | ❌ | ❌ | ✅ |
| fzf/peco連携 | ✅ | ❌ | ✅(内蔵) | ❌ | ✅(内蔵) |
| 宣言的設定ファイル | ❌ | ✅(.gtrconfig) | ✅(.gwq.toml) | ✅(.wtp.yml) | ✅(phantom.config.json) |
| post-setupフック | ✅(post-setup.sh) | ✅ | ✅(repository_settings) | ✅ | ✅(postCreate) |
| symlinkフック | ❌ | ❌ | ❌ | ✅ | ❌ |
| base_dir変更 | ❌ | ❌ | ❌ | ✅ | ✅(worktreesDirectory) |
| AI連携 | ✅(init, start-task) | ✅(9種対応) | ❌(削除済) | ❌ | ✅(ai, MCP) |
| MCP連携 | ❌ | ❌ | ❌ | ❌ | ✅ |
| Docker連携 | ✅ | ❌ | ❌ | ❌ | ❌ |
| 共有DB管理 | ✅ | ❌ | ❌ | ❌ | ❌ |
| Traefik連携 | ✅ | ❌ | ❌ | ❌ | ❌ |
| 新規clone | ✅ | ❌ | ❌ | ❌ | ❌ |
| 既存移行 | ✅ | ❌ | ❌ | ❌ | ❌ |
| exec(worktree内実行) | ❌ | ✅ | ✅ | ✅ | ✅ |
| mv/rename | ❌ | ✅ | ❌ | ❌ | ❌ |
| TTL/有効期限 | ❌ | ❌ | ✅ | ❌ | ❌ |
| clean --merged | ❌ | ✅(GitHub/GitLab) | ❌ | ❌ | ❌ |
| GitHub PR/Issue連携 | ❌ | ❌ | ❌ | ❌ | ✅ |
| tmux連携 | ❌ | ❌ | ✅ | ❌ | ✅ |
| CoWクローニング | ❌ | ✅ | ❌ | ❌ | ❌ |
| Shell補完 | ✅(Bash/Zsh) | ✅(Bash/Zsh/Fish) | ✅(Bash/Zsh/Fish/PS) | ✅(Bash/Zsh/Fish) | ✅(Bash/Zsh/Fish) |

## エディタ起動コマンド比較

worktreeをエディタで開く機能の比較（2026年2月更新）。

| ツール | Stars | コマンド | コマンド名 |
|--------|-------|----------|-----------|
| **gtr** | 1,351 | `git gtr editor <branch>` | `editor` |
| **git-worktree.nvim** | 848 | `switch_worktree(path)` | `switch`（※1） |
| **wtp** | 365 | なし | - |
| **gwq** | 349 | なし | - |
| **wt** | 252 | なし | - |
| **phantom** | 195 | `phantom edit <worktree>` | `edit` |
| **irie** | - | `irie open [worktree]` | `open` |

※1 git-worktree.nvimはNeovimプラグインのため、Neovim自体がエディタ。「switch」でworktreeを切り替えると自動的にNeovim内で開かれる。

**コマンド名の分布:**
- `editor`: gtr（最多スター）
- `edit`: phantom
- `open`: irie
- `switch`: git-worktree.nvim（Neovim内蔵のため）

**結論**: エディタ起動機能を持つCLIツールは少数派（3ツール）。コマンド名は`editor`/`edit`/`open`と分かれており、どれも直感的。`open`はmacOSの`open`コマンドと同様の「開く」という意味で一般的。

## フォルダ構成パターン

各ツールがworktreeをどこに配置するかの比較。

### パターン1: 兄弟フォルダ（irie現状）

```
parent/
├── main/                # メインリポジトリ（.git/あり）
├── feature-a/           # worktree
└── feature-b/           # worktree
```

**採用ツール**: irie（現状）
**メリット**: シンプル、従来のgit worktreeと同じ
**デメリット**: 親ディレクトリからworktree認識しにくい

### パターン2: -worktreesサフィックスフォルダ（gtr）

```
parent/
├── my-project/              # メインリポジトリ（.git/あり）
└── my-project-worktrees/    # -worktreesサフィックスフォルダ
    ├── feature-auth/        # worktree
    └── bugfix-login/        # worktree
```

**採用ツール**: gtr
**メリット**: worktreeがまとまって整理される、メインリポジトリと明確に分離
**デメリット**: mainが特別扱い

### パターン3: worktreesサブフォルダ（wtp）

```
parent/
├── my-project/          # メインリポジトリ
└── worktrees/
    ├── feature/auth/    # worktree
    └── bugfix/login/    # worktree
```

**採用ツール**: wtp
**メリット**: worktreeが整理される
**デメリット**: mainが特別扱い

### パターン4: グローバルディレクトリ（gwq）

```
~/worktrees/
├── myapp-feature-auth/       # worktree
├── myapp-bugfix-login/       # worktree
└── other-project-feature/    # 別プロジェクトも同じ場所
```

**採用ツール**: gwq
**メリット**: 全プロジェクトのworktreeを一元管理、どこからでもアクセス可能
**デメリット**: プロジェクトと離れた場所に配置される

### パターン5: .git内部（phantom）

```
my-project/
├── .git/
│   └── phantom/
│       └── worktrees/
│           ├── feature-auth/    # worktree
│           └── bugfix-login/    # worktree
├── src/
└── ...
```

**採用ツール**: phantom
**メリット**: リポジトリ内で完結、クリーン
**デメリット**: .git内なので見えにくい

### パターン6: Bareリポジトリ

```
my-project/
├── .bare/               # Bareリポジトリ（作業ファイルなし）
├── main/                # worktree（対等）
├── feature-auth/        # worktree（対等）
└── bugfix-login/        # worktree（対等）
```

**採用ツール**: git-worktree.nvim（推奨）、複数のブログ記事で紹介
**メリット**: 全worktreeが対等、親ディレクトリで管理しやすい
**デメリット**: 既存プロジェクトからの移行が必要

**`.bare` フォルダ名について:**
- 公式標準ではなく、コミュニティの慣習
- git標準は `repo.git/` サフィックスだが、1フォルダ完結構成には不向き
- 複数のブログ記事で `.bare` が採用されている

**参考:**
- [How to use git worktree and in a clean way](https://morgan.cugerone.com/blog/how-to-use-git-worktree-and-in-a-clean-way/)
- [Git-worktree workflow - PurplSite](https://purplg.dev/posts/git-worktree-workflow/)

**親フォルダからの操作:**
```bash
# 親フォルダで git status は動かない（安全）
cd my-project/
git status  # → fatal: not a git repository

# --git-dir オプションで worktree 操作は可能
git --git-dir=.bare worktree list
git --git-dir=.bare worktree add feature-new
```

## 実機検証結果（gtr, wtp）

2024年12月に実際にインストールして検証した結果。

### コマンド実行場所による動作比較

| 実行場所 | gtr | wtp |
|----------|-----|-----|
| メインリポジトリ | ✅ 全worktree表示 | ✅ 全worktree表示 |
| worktree内 | ⚠️ 自分のみ表示（バグ？） | ✅ 全worktree表示 |
| worktreesフォルダ（.gitなし） | ❌ エラー | ❌ エラー |

**wtpの優位点:**
- worktree内からでも全worktreeを正しく認識
- `managed` / `unmanaged` のステータス表示（wtp作成 vs 他ツール作成）
- `@` でメインworktreeを示す
- `*` で現在いるworktreeを示す

**gtrの問題:**
- worktree内から実行すると、そのworktreeを「main repo」と誤認識
- 他のworktreeが見えなくなる

### 複数プロジェクト環境での比較

```
# gtr: プロジェクト名が含まれるので区別しやすい
parent/
├── project-a/
├── project-a-worktrees/
│   └── feature-x/
├── project-b/
└── project-b-worktrees/
    └── feature-y/

# wtp: 固定名なので親フォルダで分離が必要
projects/
├── project-a/
│   ├── my-project/
│   └── worktrees/
│       └── feature-x/
└── project-b/
    ├── my-project/
    └── worktrees/
        └── feature-y/
```

### clone・移行サポート

| 機能 | gtr | wtp |
|------|-----|-----|
| 新規clone | ❌ なし | ❌ なし |
| 既存worktree移行 | ❌ なし | ❌ なし |
| base_dir変更 | ❌ 固定 | ✅ `.wtp.yml`で設定可 |

両ツールとも：
- 新規cloneは普通に `git clone` してから使う想定
- 既存リポジトリからの移行は手動でフォルダ移動が必要

### wtp設定ファイルでのbase_dir変更

```yaml
# .wtp.yml
version: "1.0"
defaults:
  base_dir: "../worktrees"  # ここを変更可能
```

## 各ツールの詳細

### gtr (git-worktree-runner) - CodeRabbitAI

**GitHub**: https://github.com/coderabbitai/git-worktree-runner
**Stars**: 1,351
**最新バージョン**: v2.3.1 (2026-02-17)

**概要**: AI/エディタ連携を重視したworktree管理ツール。CodeRabbitAI製。最も活発に開発されている。

**主要コマンド**:
```bash
git gtr new my-feature        # worktree作成
git gtr editor my-feature     # エディタで開く（Cursor, VS Code等）
git gtr ai my-feature         # AIツール起動（Claude Code, Aider等）
git gtr run my-feature npm test  # worktreeでコマンド実行
git gtr list                  # 一覧表示
git gtr rm my-feature         # 削除
git gtr mv old-name new-name  # リネーム（ディレクトリ+ブランチ）
git gtr clean --merged        # マージ済みworktree一括削除
```

**特徴**:
- `git gtr` としてgitサブコマンドとして動作
- エディタ連携（Antigravity, Cursor, VS Code, Zed, IntelliJ, PyCharm, WebStorm, Vim, Neovim, Emacs等）
- AIツール連携（Claude Code, Aider, Codex, Copilot, Cursor, Continue, Gemini, Auggie, OpenCode）計9種
- `.gtrconfig` 宣言的設定ファイル（チーム共有用）
- `gtr.copy.include` / `.worktreeinclude` でファイル自動コピー（CoWクローニング対応）
- hooks: `postCreate`, `postRemove`, `preRemove`, `postCd`
- `clean --merged` でマージ済みPR/MRのworktreeを一括削除（GitHub/GitLab対応）
- `mv` / `rename` でworktreeリネーム
- shell統合: `eval "$(git gtr init bash)"` でgtr cd対応
- Shell補完（Bash, Zsh, Fish）

**フォルダ構成**: `../my-project-worktrees/feature/`（-worktreesサフィックスフォルダ、`--folder`でカスタム可）

**2025年12月以降の主な変更**:
- v2.3.1 (2026-02-17): Antigravity(Google)エディタ対応、CoWクローニング
- v2.2.0 (2026-02-11): `--folder`、`mv`/`rename`、`postCd`フック、GitLab対応`clean --merged`
- v2.1.0 (2026-01-14): `.gtrconfig`宣言的設定、`copy`コマンド、Gemini/Copilotアダプター

### gwq - d-kuro

**GitHub**: https://github.com/d-kuro/gwq
**Stars**: 349
**最新バージョン**: v0.0.13 (2026-02-12)

**概要**: fzf内蔵のworktree管理ツール。グローバルディレクトリで一元管理。

**主要コマンド**:
```bash
gwq add -b feature/new-ui     # worktree作成
gwq list                      # 一覧表示
gwq get                       # fzfで選択してパス取得
gwq cd feature                # ディレクトリ移動（新シェル起動）
gwq status                    # 状態表示
gwq status --watch            # リアルタイム監視
gwq exec feature -- npm test  # worktreeでコマンド実行
gwq remove feature/old-ui     # 削除
gwq add --expires 7d feature  # 有効期限付きworktree
gwq prune --expired           # 期限切れworktree削除
```

**特徴**:
- **fzf内蔵**（外部依存なし）
- `~/worktrees/` にグローバル管理
- 全リポジトリのworktreeをどこからでもアクセス可能
- `.gwq.toml` でプロジェクトごとの設定（`repository_settings`でファイルコピー+セットアップコマンド）
- **TTL/有効期限機能**（`--expires 7d`、`prune --expired`で自動クリーンアップ）
- tmuxセッション管理
- status dashboardのwatch/フィルター/JSON・CSV出力
- AI連携: 以前あった`task`コマンド（Claude Code連携）はv0.0.6で削除。コアのworktree管理に集中する方針
- Shell補完（Bash, Zsh, Fish, PowerShell）

**フォルダ構成**: `~/worktrees/myapp-feature/`（グローバル）

**2025年12月以降の主な変更**:
- v0.0.13 (2026-02-12): `ls`エイリアス追加
- v0.0.12 (2026-02-02): TTL/有効期限機能
- v0.0.10 (2026-01-16): `.gwq.toml`ローカル設定ファイル
- v0.0.9 (2026-01-15): `cd`コマンド追加
- v0.0.6 (2026-01-12): `repository_settings`（hooks相当）追加、`task`コマンド削除

### wtp (Worktree Plus) - satococoa

**GitHub**: https://github.com/satococoa/wtp
**Stars**: 365
**最新バージョン**: v2.8.0 (2026-02-11)

**概要**: .wtp.yml設定ファイルによる自動セットアップを重視。hooks設定が最も宣言的で整理されている。

**主要コマンド**:
```bash
wtp add feature/auth          # worktree作成（パス自動生成）
wtp add --exec "npm ci" feature/auth  # 作成後にコマンド実行
wtp remove --with-branch feature/done  # worktree+ブランチ削除
wtp cd feature/auth           # ディレクトリ移動
wtp cd @                      # メインworktreeに戻る
wtp list                      # 一覧表示
wtp exec feature/auth -- npm test  # worktreeでコマンド実行（インタラクティブ対応）
```

**特徴**:
- ブランチ名からパスを自動生成
- `.wtp.yml` でhooks設定（`copy`, `symlink`, `command`の3タイプ）
- `symlink`フックでnode_modules等の共有ディレクトリをリンク可能
- `exec`コマンドでworktree内コマンド実行（インタラクティブ対応）
- `--with-branch` でworktreeとブランチを同時削除
- Homebrew対応
- Shell補完（Bash, Zsh, Fish）

**設定ファイル例** (`.wtp.yml`):
```yaml
hooks:
  post_create:
    - type: copy
      from: ".env"
      to: ".env"
    - type: symlink
      from: "node_modules"
      to: "node_modules"
    - type: command
      command: "npm ci"
```

**フォルダ構成**: `../worktrees/feature/auth/`

**2025年12月以降の主な変更**:
- v2.8.0 (2026-02-11): `exec`コマンド追加、`add --exec`フラグ
- v2.6.0 (2026-01-15): `symlink`フック追加
- v2.5.0 (2025-12-16): `cd`引数なしでメインworktreeに移動

### phantom - aku11i

**GitHub**: https://github.com/aku11i/phantom
**Stars**: 195
**最新バージョン**: v5.0.0 (2026-01-12)

**概要**: .git内部にworktreeを格納。MCP連携でAIが自律的にworktree管理。

**主要コマンド**:
```bash
phantom create feature-awesome --shell  # worktree作成してシェル起動
phantom list                            # 一覧表示
phantom exec feature npm test           # worktreeでコマンド実行
phantom edit feature                    # エディタで開く
phantom ai feature                      # AIツール起動
phantom delete feature                  # 削除
phantom github checkout 123             # PR/Issueからworktree作成
phantom mcp serve                       # MCPサーバー起動
```

**特徴**:
- **fzf内蔵**（`--fzf`フラグ）
- `.git/phantom/worktrees/` に格納（リポジトリ内で完結、`worktreesDirectory`でカスタマイズ可）
- `phantom.config.json` でhooks設定（`postCreate.copyFiles`, `postCreate.commands`, `preDelete.commands`）
- MCP連携（AIが自律的にworktree管理）
- `phantom ai` コマンド + `phantom preferences` でAIツール設定
- GitHub PR/Issue連携（`phantom github checkout`）
- tmux連携（`--tmux`, `--tmux-vertical`, `--tmux-horizontal`）
- Shell補完（Bash, Zsh, Fish）

**フォルダ構成**: `.git/phantom/worktrees/feature/`

**2025年12月以降の主な変更**:
- v5.0.0 (2026-01-12): Fork PRチェックアウト時のworktree名が`{owner}/{branch}`形式に
- v4.0.0 (2026-01-11): `list`がデフォルトworktreeも表示するように
- v3.3.0 (2025-12-12): `worktreesDirectory` preferences対応、複数worktree一括削除
- v3.2.0 (2025-12-01): `edit`コマンド、`ai`コマンド、preferences管理

### wt (git-worktree-switcher) - yankeexe

**GitHub**: https://github.com/yankeexe/git-worktree-switcher
**Stars**: 252

**概要**: シンプルで軽量なworktree切り替えツール。

**主要コマンド**:
```bash
wt <worktree-name>    # worktreeに切り替え
wt -i                 # インタラクティブ選択
wt -                  # ルートworktreeに戻る
wt list               # 一覧表示
```

**特徴**:
- 非常にシンプル
- fzf不要（独自のインタラクティブ選択）
- 軽量

### git-worktree.nvim - ThePrimeagen

**GitHub**: https://github.com/ThePrimeagen/git-worktree.nvim
**Stars**: 848（2024年8月以降更新なし）

**概要**: NeovimからBareリポジトリでworktreeを管理。

**特徴**:
- **Bareリポジトリを明示的に推奨**
- Neovim + Telescope連携
- hooks対応

**Bareリポジトリのセットアップ**:
```bash
git clone --bare <upstream> repo.git
cd repo.git
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
```

## irieの現状と課題

### 現状のフォルダ構成

```
project/
├── main/                    # docker-compose-worktree/がある
│   └── .git/                # 実体
├── feature-a/               # worktree
│   └── .git                 # ファイル（main/.gitを参照）
└── feature-b/               # worktree
```

### 課題

1. **親ディレクトリからworktree認識できない**
   - `irie cd`, `irie list` が親ディレクトリで動作しない
   - mainに`.git/`があるため、mainが特別扱いになる

2. **解決策の選択肢**

| 方式 | 実装 | 参考 |
|------|------|------|
| Bareリポジトリ | `irie clone` で新規セットアップ | git-worktree.nvim |
| .git内部 | `.git/irie/worktrees/` に格納 | phantom |
| グローバル | `~/worktrees/` に一元管理 | gwq |

## 今後の機能候補

### 実装済み

| 機能 | 説明 | 参考 |
|------|------|------|
| ~~`irie list`~~ | ✅ 全worktree一覧表示（git状態含む） | wtp, gwq, gtr |
| ~~fzf/peco連携~~ | ✅ `irie cd`でfzf/peco選択 | gwq, phantom |
| ~~`irie clone`~~ | ✅ Bareリポジトリでセットアップ | git-worktree.nvim |
| ~~`irie convert`~~ | ✅ 既存リポジトリをBare構成に変換 | - |

### 検討中

（現在なし）

### 優先度: 低

| 機能 | 説明 | 参考 |
|------|------|------|
| グローバル管理 | `~/worktrees/` で一元管理 | gwq |
| MCP連携 | AIが自律的にworktree管理 | phantom |

## トレンド（2025年12月〜2026年2月）

1. **宣言的設定ファイルの普及**: gtr(`.gtrconfig`)、gwq(`.gwq.toml`)、wtp(`.wtp.yml`)、phantom(`phantom.config.json`)と全ツールが宣言的設定に対応済み。irieは`post-setup.sh`/`post-cleanup.sh`のシェルスクリプト方式で、自由度の高さがメリット。

2. **execコマンドの共通化**: gtr、gwq、wtp、phantom全てがworktree内でのコマンド実行（`exec`）に対応。標準機能化している。

3. **AI連携の二極化**: gtrはAIアダプターを9種類に拡大。phantomはMCPで差別化。一方gwqは`task`コマンドを削除しAI連携から撤退。

4. **Star数の成長**: gtr (+444, +49%)が最も成長。wtp (+187, +105%)が倍増。gwq (+140, +67%)。phantom (+18, +10%)は落ち着き。

5. **gwqのユニーク機能**: TTL/有効期限（`--expires 7d`）は他ツールにない独自機能。一時的なworktreeの自動クリーンアップに実用的。

## 参考リンク

- [fzf](https://github.com/junegunn/fzf) - コマンドラインファジーファインダー
- [peco](https://github.com/peco/peco) - 別のファジーファインダー
- [Bare Repository Worktree Pattern](https://morgan.cugerone.com/blog/workarounds-to-git-worktree-using-bare-repository-and-cannot-fetch-remote-branches/) - Bareリポジトリの解説記事
