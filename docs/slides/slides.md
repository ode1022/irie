---
theme: seriph
background: https://images.unsplash.com/photo-1758237866901-ada4f161783b?w=1920&q=80
title: irie - Git Worktree + Docker 並行開発ツール
info: irieはGit WorktreeとDockerを組み合わせた並行開発環境ツールです
class: text-center
colorSchema: dark
drawings:
  persist: false
selectable: true
transition: slide-left
mdc: true
---

# irie

Git Worktree + Docker 並行開発環境ツール

<div class="abs-br m-6 flex gap-2">
  <a href="https://github.com/ode1022/irie" target="_blank" class="text-xl slidev-icon-btn opacity-50 !border-none !hover:text-white">
    <carbon-logo-github />
  </a>
</div>

<div class="pt-12 flex items-center justify-center gap-3 text-gray-400 text-sm">
  <img src="https://github.com/ode1022.png" class="w-10 h-10 rounded-full" />
  <span>ode <a href="https://github.com/ode1022" target="_blank" class="text-gray-500 hover:text-white">@ode1022</a></span>
</div>

---
transition: fade-out
clicks: 3
---

# 現状の課題 - 割り込みタスクの悪夢

開発中にレビュー指摘や緊急対応が飛んでくる日常

<div class="grid grid-cols-1 gap-3 mt-4">

<!-- 作業A: 最初はアクティブ → 割り込みで stash → 最後に stash pop 混乱 -->
<div class="rounded-lg px-5 py-3 border-l-4 flex items-center gap-4 transition-all duration-500" :class="$clicks >= 1 ? 'bg-gray-800 bg-opacity-30 border-gray-500' : 'bg-blue-900 bg-opacity-30 border-blue-400'">
  <span class="font-bold text-lg min-w-20 transition-colors duration-500" :class="$clicks >= 1 ? 'text-gray-500' : 'text-blue-400'">作業A</span>
  <span class="text-xs text-gray-500">機能開発</span>
  <code v-if="$clicks === 0" class="bg-blue-900 text-blue-300 px-2 py-1 rounded text-xs">開発中...</code>
  <template v-if="$clicks >= 1 && $clicks < 3">
    <code class="bg-blue-900 text-blue-300 px-2 py-1 rounded text-xs line-through opacity-40">開発中...</code>
    <span class="text-red-400 font-bold text-sm">→ git stash</span>
  </template>
  <template v-if="$clicks >= 3">
    <code class="bg-gray-800 text-gray-500 px-2 py-1 rounded text-xs">git stash pop</code>
    <span class="text-red-400 font-bold text-sm animate-pulse">...?? どのstash？</span>
  </template>
</div>

<!-- 作業B: clicks>=1 で出現、アクティブ → clicks>=2 で stash -->
<div v-if="$clicks >= 1" class="rounded-lg px-5 py-3 border-l-4 flex items-center gap-4 transition-all duration-500" :class="$clicks >= 2 ? 'bg-gray-800 bg-opacity-30 border-gray-500' : 'bg-purple-900 bg-opacity-30 border-purple-400'">
  <span class="font-bold text-lg min-w-20 transition-colors duration-500" :class="$clicks >= 2 ? 'text-gray-500' : 'text-purple-400'">作業B</span>
  <span class="text-xs text-gray-500">レビュー指摘</span>
  <span class="text-purple-400 text-lg">⬇ 割り込み</span>
  <code v-if="$clicks === 1" class="bg-purple-900 text-purple-300 px-2 py-1 rounded text-xs">修正対応中...</code>
  <template v-if="$clicks >= 2">
    <code class="bg-purple-900 text-purple-300 px-2 py-1 rounded text-xs line-through opacity-40">修正対応中...</code>
    <span class="text-red-400 font-bold text-sm">→ git stash</span>
  </template>
</div>

<!-- 作業C: clicks>=2 で出現、常にアクティブ -->
<div v-if="$clicks >= 2" class="bg-amber-900 bg-opacity-30 rounded-lg px-5 py-3 border-l-4 border-amber-400 flex items-center gap-4">
  <span class="text-amber-400 font-bold text-lg min-w-20">作業C</span>
  <span class="text-xs text-gray-500">緊急バグ修正</span>
  <span class="text-amber-400 text-lg">⬇ さらに割り込み!</span>
  <code class="bg-amber-900 text-amber-300 px-2 py-1 rounded text-xs">緊急対応中...</code>
</div>

</div>

<!-- clicks>=3 で問題カード表示 -->
<div v-if="$clicks >= 3" class="grid grid-cols-3 gap-4 mt-6">
  <div class="bg-gray-800 rounded-lg p-4 border-l-4 border-red-500">
    <h4 class="text-red-400 font-bold mb-1">stash地獄</h4>
    <p class="text-xs text-gray-400 leading-relaxed">stashが溜まりどれがどれか不明。pop間違いでコンフリクト発生。</p>
  </div>
  <div class="bg-gray-800 rounded-lg p-4 border-l-4 border-red-500">
    <h4 class="text-red-400 font-bold mb-1">コンテキストの消失</h4>
    <p class="text-xs text-gray-400 leading-relaxed">「どこまでやったっけ？」stash前の作業状態を思い出せない。</p>
  </div>
  <div class="bg-gray-800 rounded-lg p-4 border-l-4 border-red-500">
    <h4 class="text-red-400 font-bold mb-1">やらかし事故</h4>
    <p class="text-xs text-gray-400 leading-relaxed">間違ったブランチでstash apply。作業Aの変更が作業Bに混入。</p>
  </div>
</div>

---
transition: slide-left
---

# Git Worktreeで解決？ ...しかしDockerとの壁

<div class="grid grid-cols-2 gap-8 mt-4">
<div class="bg-gray-800 rounded-xl p-6 border-t-4 border-green-500">

### <span class="text-green-400">Git Worktreeなら</span>

<v-clicks>

- 作業ごとに**独立したディレクトリ**
- ブランチ切り替え不要・**stash不要**
- 作業A / B / C が**常に並行して存在**
- コンテキスト切り替えは `cd` するだけ
- どの作業も**いつでもすぐ再開**できる

</v-clicks>

```
my-project/
  main/       ← 安定版
  feat-a/     ← 作業A
  fix-bug/    ← 作業B
  review-fix/ ← 作業C
```

</div>
<div class="bg-gray-800 rounded-xl p-6 border-t-4 border-red-500">

### <span class="text-red-400">...でもDockerと組み合わせると</span>

<v-clicks>

- <span class="text-red-400">✖</span> **ポート番号の衝突** <br><span class="text-xs text-gray-500">全worktreeが :80, :3000 を取り合う</span>
- <span class="text-red-400">✖</span> **DBコンテナの増殖** <br><span class="text-xs text-gray-500">worktreeごとにDBが起動し、メモリ圧迫</span>
- <span class="text-red-400">✖</span> **環境構築の繰り返し** <br><span class="text-xs text-gray-500">.env編集、override.yml作成、migration...</span>
- <span class="text-red-400">✖</span> **認証情報が使い回せない** <br><span class="text-xs text-gray-500">localhost:3000 と :3001 は別サイト扱い</span>

</v-clicks>

</div>
</div>

---
transition: slide-left
---

# irieが解決すること

<div class="grid grid-cols-2 gap-6 mt-6">
  <div class="bg-gray-800 rounded-xl p-6 border-l-4 border-green-500">
    <h3 class="text-green-400 font-bold mb-2">🌐 ホスト名ベースのルーティング</h3>
    <p class="text-sm text-gray-400 leading-relaxed">Traefikリバースプロキシにより、すべてポート80で統一。<br><code>feat-xxx.my-project.localhost</code> で自動ルーティング。</p>
  </div>
  <div class="bg-gray-800 rounded-xl p-6 border-l-4 border-green-500">
    <h3 class="text-green-400 font-bold mb-2">💾 共有DB + 柔軟な分離</h3>
    <p class="text-sm text-gray-400 leading-relaxed">DBコンテナを1つに集約。通常はmainのDBを共有、<br>スキーマ変更時は <code>--separate-db</code> で個別DB自動作成。</p>
  </div>
  <div class="bg-gray-800 rounded-xl p-6 border-l-4 border-green-500">
    <h3 class="text-green-400 font-bold mb-2">⚡ ワンコマンドで環境構築</h3>
    <p class="text-sm text-gray-400 leading-relaxed"><code>irie add</code> 1つで、worktree作成・Docker設定生成・<br>DB初期化・マイグレーションまで全自動。</p>
  </div>
  <div class="bg-gray-800 rounded-xl p-6 border-l-4 border-green-500">
    <h3 class="text-green-400 font-bold mb-2">🔑 認証情報の共有</h3>
    <p class="text-sm text-gray-400 leading-relaxed"><code>*.my-project.localhost</code> は同じルートドメイン。<br>パスワードマネージャーがworktree間で使い回し可能。</p>
  </div>
</div>

---
layout: center
---

# アーキテクチャ

<div class="flex flex-col items-center gap-2 mt-4">
  <div class="flex gap-4">
    <div class="bg-indigo-900 border-2 border-indigo-500 rounded-lg px-6 py-3 text-center">
      <div class="text-indigo-300 font-bold text-sm">🌐 ブラウザ</div>
      <code class="text-xs text-indigo-400">main.my-project.localhost</code>
    </div>
    <div class="bg-indigo-900 border-2 border-indigo-500 rounded-lg px-6 py-3 text-center">
      <div class="text-indigo-300 font-bold text-sm">🌐 ブラウザ</div>
      <code class="text-xs text-indigo-400">feat-a.my-project.localhost</code>
    </div>
    <div class="bg-indigo-900 border-2 border-indigo-500 rounded-lg px-6 py-3 text-center">
      <div class="text-indigo-300 font-bold text-sm">🌐 ブラウザ</div>
      <code class="text-xs text-indigo-400">feat-b.my-project.localhost</code>
    </div>
  </div>
  <div class="text-gray-500 text-2xl">⬇</div>
  <div class="bg-cyan-900 border-2 border-cyan-600 rounded-lg px-16 py-3 text-center w-full max-w-2xl">
    <div class="text-cyan-300 font-bold">🛠 Traefik (リバースプロキシ)</div>
    <div class="text-cyan-400 text-xs">ホスト名でルーティング / ポート80で統一</div>
  </div>
  <div class="text-gray-500 text-2xl">⬇</div>
  <div class="flex gap-4">
    <div class="bg-green-900 border-2 border-green-500 rounded-lg px-8 py-3 text-center">
      <div class="text-green-300 font-bold text-sm">📦 main</div>
      <div class="text-green-400 text-xs">docker compose</div>
    </div>
    <div class="bg-green-900 border-2 border-green-500 rounded-lg px-8 py-3 text-center">
      <div class="text-green-300 font-bold text-sm">📦 feat-a</div>
      <div class="text-green-400 text-xs">docker compose</div>
    </div>
    <div class="bg-green-900 border-2 border-green-500 rounded-lg px-8 py-3 text-center">
      <div class="text-green-300 font-bold text-sm">📦 feat-b</div>
      <div class="text-green-400 text-xs">docker compose</div>
    </div>
  </div>
  <div class="text-gray-500 text-2xl">⬇</div>
  <div class="bg-red-900 border-2 border-red-500 rounded-lg px-16 py-3 text-center w-full max-w-2xl">
    <div class="text-red-300 font-bold">🗄 共有 PostgreSQL / MySQL</div>
    <div class="text-red-400 text-xs">コンテナ1つ / DB名で分離</div>
  </div>
</div>

---
transition: slide-left
---

# 主要な機能

<div class="grid grid-cols-3 gap-5 mt-6">
  <div class="bg-gray-800 rounded-xl p-5 text-center border-t-4 border-indigo-500">
    <div class="text-3xl mb-3">📁</div>
    <h3 class="font-bold mb-2">Bare構造</h3>
    <p class="text-xs text-gray-400">親ディレクトリでの誤コミットを防止。すべてのworktreeが対等な関係。</p>
  </div>
  <div class="bg-gray-800 rounded-xl p-5 text-center border-t-4 border-indigo-500">
    <div class="text-3xl mb-3">🤖</div>
    <h3 class="font-bold mb-2">Claude Code連携</h3>
    <p class="text-xs text-gray-400"><code>irie init</code> でプロジェクトのDocker構成をAIが自動解析・テンプレート生成。</p>
  </div>
  <div class="bg-gray-800 rounded-xl p-5 text-center border-t-4 border-indigo-500">
    <div class="text-3xl mb-3">🎯</div>
    <h3 class="font-bold mb-2">start-task</h3>
    <p class="text-xs text-gray-400">チケットURLやタスク説明からworktree作成 + Claude Code起動を1コマンドで。</p>
  </div>
  <div class="bg-gray-800 rounded-xl p-5 text-center border-t-4 border-indigo-500">
    <div class="text-3xl mb-3">📝</div>
    <h3 class="font-bold mb-2">エディタ連携</h3>
    <p class="text-xs text-gray-400">VS Code, Cursor, JetBrains, Vim...<br><code>irie open</code> で好みのエディタで即座に。</p>
  </div>
  <div class="bg-gray-800 rounded-xl p-5 text-center border-t-4 border-indigo-500">
    <div class="text-3xl mb-3">🔄</div>
    <h3 class="font-bold mb-2">irie cd</h3>
    <p class="text-xs text-gray-400">Shell連携でworktree間を瞬時に移動。Tab補完・fzf連携もサポート。</p>
  </div>
  <div class="bg-gray-800 rounded-xl p-5 text-center border-t-4 border-indigo-500">
    <div class="text-3xl mb-3">🛡</div>
    <h3 class="font-bold mb-2">安全な削除</h3>
    <p class="text-xs text-gray-400"><code>irie remove</code> でworktree・Docker・DB・Traefik設定を確認付きで一括クリーンアップ。</p>
  </div>
</div>

---
transition: slide-left
---

# 基本ワークフロー

<div class="text-sm text-gray-400 mb-1 mt-1 border-b border-gray-700 pb-1">📦 初回セットアップ（リポジトリごとに1回）</div>

<div class="flex flex-col gap-1">
  <div class="bg-gray-800 rounded-lg px-5 py-2 flex items-center gap-5">
    <span class="text-indigo-400 font-mono font-bold text-xl min-w-10">01</span>
    <code class="bg-gray-900 text-blue-400 px-3 py-1 rounded font-mono text-sm">irie clone &lt;repo-url&gt;</code>
    <span class="text-gray-400 text-sm">Bare構造でリポジトリをクローン</span>
  </div>
  <div class="bg-gray-800 rounded-lg px-5 py-2">
    <div class="flex items-center gap-5">
      <span class="text-indigo-400 font-mono font-bold text-xl min-w-10">02</span>
      <code class="bg-gray-900 text-blue-400 px-3 py-1 rounded font-mono text-sm">irie init</code>
      <span class="text-gray-400 text-sm">Claude Codeが Docker設定テンプレートを自動生成</span>
    </div>
    <div class="ml-16 mt-1 text-xs text-gray-500 space-y-0.5">
      <div>生成ファイル: <code class="text-gray-400">docker-compose.override.traefik-example.yml</code> / <code class="text-gray-400">post-setup.sh</code> / <code class="text-gray-400">post-cleanup.sh</code></div>
      <div class="text-yellow-600">⚠ AIが生成するためプロジェクト固有の調整が必要な場合あり → <span class="text-gray-400">リポジトリにcommitすればチーム全員で共有。以後は不要</span></div>
    </div>
  </div>
</div>

<div class="text-sm text-gray-400 mb-1 mt-3 border-b border-gray-700 pb-1">🔄 日常の開発フロー</div>

<div class="flex flex-col gap-1">
  <div class="bg-gray-800 rounded-lg px-5 py-2 flex items-center gap-5">
    <span class="text-indigo-400 font-mono font-bold text-xl min-w-10">01</span>
    <code class="bg-gray-900 text-blue-400 px-3 py-1 rounded font-mono text-sm">irie add feat/new-feature</code>
    <span class="text-gray-400 text-sm">worktree作成 + Docker環境の自動セットアップ</span>
  </div>
  <div class="bg-gray-800 rounded-lg px-5 py-2 flex items-center gap-5 opacity-50">
    <span class="text-indigo-400 font-mono font-bold text-xl min-w-10">02</span>
    <code class="bg-gray-900 text-blue-400 px-3 py-1 rounded font-mono text-sm">irie cd feat/new-feature</code>
    <span class="text-gray-400 text-sm">worktreeに移動 <span class="text-gray-600">（シェル統合時は add で自動cd）</span></span>
  </div>
  <div class="bg-gray-800 rounded-lg px-5 py-2">
    <div class="flex items-center gap-5">
      <span class="text-indigo-400 font-mono font-bold text-xl min-w-10">03</span>
      <code class="bg-gray-900 text-blue-400 px-3 py-1 rounded font-mono text-sm">irie open</code>
      <span class="text-gray-400 text-sm">worktreeをエディタ / IDEで開く</span>
    </div>
    <div class="ml-16 mt-1 text-xs text-gray-500">VS Code, Cursor, JetBrains, Vim等に対応 <span class="text-gray-600">（WSL2環境でもWindows側のIDEを直接起動可能）</span></div>
  </div>
  <div class="bg-gray-800 rounded-lg px-5 py-2 flex items-center gap-5">
    <span class="text-indigo-400 font-mono font-bold text-xl min-w-10">04</span>
    <code class="bg-gray-900 text-blue-400 px-3 py-1 rounded font-mono text-sm">irie remove feat/new-feature</code>
    <span class="text-gray-400 text-sm">完了後、環境ごとクリーンアップ</span>
  </div>
</div>

---
transition: slide-left
---

# irie add の実行結果

セットアップ完了後、アクセスURLが表示される

<div class="grid grid-cols-[1fr_auto] gap-6 mt-4 items-start">

<div class="bg-gray-900 rounded-xl p-4 font-mono text-sm leading-relaxed border border-gray-700">
  <div class="text-green-400 mb-2">✔ セットアップ完了</div>
  <div class="text-gray-400 mb-1">アクセスURL:</div>
  <div class="text-blue-400 ml-2">http://new-feature.my-project.localhost/</div>
  <div class="text-gray-400 mt-2 mb-1">プロジェクト固有URL:</div>
  <div class="ml-2 text-gray-500">管理画面: <span class="text-blue-400">http://new-feature.my-project.localhost/admin</span></div>
  <div class="ml-2 text-gray-500">クライアント（Vite SPA）: <span class="text-blue-400">http://new-feature.client.my-project.localhost/</span></div>
  <div class="ml-2 text-gray-500">Mailpit: <span class="text-blue-400">http://new-feature.mailpit.my-project.localhost/</span></div>
  <div class="text-gray-400 mt-2 mb-1">Traefikダッシュボード:</div>
  <div class="text-blue-400 ml-2">http://traefik.localhost/</div>
</div>

<div class="flex flex-col gap-3">
  <div class="bg-gray-800 rounded-lg p-3 border-l-4 border-blue-500">
    <h4 class="text-blue-400 font-bold text-sm mb-0.5">ターミナルからアクセス</h4>
    <p class="text-xs text-gray-400">URLクリックでブラウザが開く</p>
  </div>
  <div class="bg-gray-800 rounded-lg p-3 border-l-4 border-green-500">
    <h4 class="text-green-400 font-bold text-sm mb-0.5">あとから確認</h4>
    <p class="text-xs text-gray-400"><code class="text-green-300">irie info</code> で再表示</p>
  </div>
  <div class="bg-gray-800 rounded-lg p-3 border-l-4 border-purple-500">
    <h4 class="text-purple-400 font-bold text-sm mb-0.5">プロジェクト固有URL</h4>
    <p class="text-xs text-gray-400"><code class="text-purple-300">post-setup.sh</code> の irie_info() で定義</p>
  </div>
</div>

</div>

---
transition: slide-left
---

# Before / After

<div class="grid grid-cols-[1fr_auto_1fr] gap-8 items-center mt-6">
  <div class="bg-gray-800 rounded-xl p-6 border-t-4 border-red-500">
    <h3 class="text-red-400 font-bold text-xl mb-4">Before (手動管理)</h3>
    <ul class="space-y-2 text-sm text-gray-300">
      <li>git worktree add で作成</li>
      <li>.env をコピーしてDB接続情報を書き換え</li>
      <li>docker-compose.override.yml を手書き<br><span class="text-xs text-gray-500">ポート変更・Compose name指定...</span></li>
      <li>DBを手動で作成</li>
      <li>マイグレーション実行</li>
      <li>ブラウザの認証情報を再入力</li>
    </ul>
  </div>

  <div class="text-4xl text-gray-600">➡</div>

  <div class="bg-gray-800 rounded-xl p-6 border-t-4 border-green-500">
    <h3 class="text-green-400 font-bold text-xl mb-4">After (irie)</h3>
    <div class="space-y-4">
      <code class="block bg-gray-900 text-blue-400 px-4 py-2 rounded font-mono text-lg font-bold">irie add feat/xxx</code>
      <p class="text-gray-500 text-sm">... 全自動 ...</p>
      <p class="text-sm">ブラウザで <code class="text-blue-400">feat-xxx.my-project.localhost</code> にアクセス</p>
      <p class="text-green-400 font-bold text-lg">完了！</p>
    </div>
  </div>
</div>

<div class="mt-4 bg-gray-800 bg-opacity-50 rounded-lg px-5 py-2 text-xs text-gray-500">
  💡 <span class="text-gray-400">Worktree + Docker共通の注意点:</span> <code class="text-gray-400">build:</code> のみのサービスは worktree ごとに毎回ビルドが走る → override で <code class="text-gray-400">image:</code> を指定してイメージを共有（<code class="text-gray-400">irie init</code> で設定）
</div>

---
transition: slide-left
---

# irie start-task - Claude Code連携

<div class="text-sm text-gray-400 mb-4">タスク説明を渡すだけで、ブランチ命名 → worktree作成 → Claude Code起動まで一発</div>

<div class="grid grid-cols-2 gap-6">

<div>
<div class="text-sm text-red-400 font-bold mb-2">従来のClaude Code開発フロー</div>
<div class="bg-gray-800 rounded-lg p-4 text-sm space-y-2">
  <div class="text-gray-400">
    <span class="text-red-400">①</span> ブランチ名を自分で考える<br>
    <span class="text-xs text-gray-600 ml-4">or Claudeに命名してもらう（タスク説明が必要）← おすすめ</span>
  </div>
  <div class="flex items-center gap-2 text-gray-400"><span class="text-red-400">②</span> <code class="text-xs">irie add feat/xxx</code> でworktree作成</div>
  <div class="flex items-center gap-2 text-gray-400"><span class="text-red-400">③</span> <code class="text-xs">cd</code> で移動</div>
  <div class="flex items-center gap-2 text-gray-400"><span class="text-red-400">④</span> <code class="text-xs">claude</code> を起動してタスクをまた伝える</div>
  <div class="text-xs text-gray-600 mt-2">手順が多い / タスク説明を二度入力</div>
</div>
</div>

<div>
<div class="text-sm text-green-400 font-bold mb-2">irie start-task なら</div>
<div class="bg-gray-900 rounded-lg p-4 font-mono border border-gray-700">
  <div class="text-gray-500 text-xs mb-2">$ irie start-task "フッターにirie demoという文言を記載"</div>
  <div class="text-cyan-400 text-xs mb-1">ブランチ名を決定中...</div>
  <div class="text-green-400 text-xs mb-1">→ feat/add-irie-demo-footer-text</div>
  <div class="text-cyan-400 text-xs mb-1">worktreeを作成中...</div>
  <div class="text-green-400 text-xs mb-1">✔ セットアップ完了</div>
  <div class="text-cyan-400 text-xs mb-1">Claude Codeを起動中...</div>
  <div class="text-gray-600 text-xs">（タスク情報付きでClaudeが作業開始）</div>
</div>
<div class="mt-3 space-y-1">
  <div class="text-xs text-gray-500">✔ Claudeがブランチ名を自動命名</div>
  <div class="text-xs text-gray-500">✔ worktree作成 + Docker環境構築</div>
  <div class="text-xs text-gray-500">✔ タスク情報を引き継いでClaude Code起動</div>
  <div class="text-xs text-gray-500">✔ チケットURLにも対応 — MCPでチケット内容を取得し命名・作業に反映</div>
</div>
</div>

</div>

---
transition: slide-left
---

# 他ツールとの比較 <span class="text-sm text-gray-500 font-normal">（2026年2月時点）</span>

<div class="mt-4">

| 機能 | **irie** | gtr | wtp | gwq | phantom |
|------|:--------:|:---:|:---:|:---:|:-------:|
| Docker + Traefik連携 | ✅ | - | - | - | - |
| 共有DB管理 | ✅ | - | - | - | - |
| Bare構造 clone/convert | ✅ | - | - | - | - |
| AI連携 (Claude Code) | ✅ | ✅ | - | ✅ | ✅(MCP) |
| fzf / peco対応 | ✅ | - | - | ✅ | ✅ |
| エディタ連携 | ✅ | ✅ | - | - | ✅ |
| post-setup フック | ✅ | ✅ | ✅ | - | - |
| GitHub Stars | 😇 | 1,351 | 365 | 349 | 195 |

</div>

---
layout: center
class: text-center
---

# Get Started

インストール & セットアップ

<div class="bg-gray-800 rounded-xl px-6 py-5 mt-6 inline-block border border-gray-700 text-left">
  <code class="text-blue-400 text-sm block">$ git clone git@github.com:ode1022/irie.git ~/.irie</code>
  <code class="text-gray-500 text-sm block mt-3"># .bashrc や .zshrc に追加</code>
  <code class="text-blue-400 text-sm block">export PATH="$HOME/.irie/bin:$PATH"</code>
  <code class="text-blue-400 text-sm block">eval "$(irie shell-init)"</code>
  <code class="text-gray-500 text-sm block mt-3"># 補完をインストール（オプション）</code>
  <code class="text-blue-400 text-sm block">irie completion install</code>
</div>

<div class="mt-6 text-gray-500">
  GitHub: github.com/ode1022/irie
</div>

<div class="mt-2 text-gray-600 text-sm">
  Demo: <a href="https://github.com/ode1022/irie-demo-laravel" class="text-gray-500 hover:text-white">github.com/ode1022/irie-demo-laravel</a> <span class="text-xs text-gray-600">（irie設定済みLaravelアプリ / すぐに試せます）</span>
</div>
