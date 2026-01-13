# macOS CI 対応コンテキスト

## 現状（2025-12-22）

### 達成できたこと
- `macos-15-intel` + `douglascamata/setup-docker-macos-action@v1` でDockerが動作
- PostgreSQL/Traefikの共有サービス起動成功

### 未解決の問題
macOSのBATSが日本語テスト名を認識できない：
```
bats: unknown test name `$'test_irie_clone-3a_ロー...'`
# bats warning: Executed 5 instead of expected 129 tests
```

`LC_ALL=en_US.UTF-8` 設定でも解決せず。

## 技術的な背景

### ARM64 (M1/M2) ランナーでDockerが動かない理由
- Docker/colimaはLinux VMを起動する必要がある
- ARM64ランナーはネスト仮想化をサポートしていない（Apple Virtualization Frameworkの制限）
- M3チップはハードウェア的にはネスト仮想化対応だが、GitHub Actionsは未対応

### 解決策: Intel CPU ランナー
```yaml
runs-on: macos-15-intel  # Intel CPUでネスト仮想化可能
```

## 対応オプション

### A. テスト関数名をASCIIに変更
- 全テストファイルの日本語関数名を英語に変更
- 影響: 大規模な変更、可読性低下の可能性

### B. macOS CIを削除
- LinuxのみでCI実行
- 影響: macOS固有の問題を検出できない

### C. macOSではDocker不要テストのみ実行
- シェルスクリプトのユニットテストのみ
- 影響: 部分的なカバレッジ

## 参考リンク
- [setup-docker-macos-action](https://github.com/douglascamata/setup-docker-macos-action)
- [colima M1 issue](https://github.com/abiosoft/colima/issues/971)
- [GitHub Actions ARM64 nested virtualization](https://github.com/orgs/community/discussions/69211)

## 次のステップ
1. MacBookでローカル検証
2. 日本語テスト名の問題を解決するか、ASCIIに変更するか判断
3. CI設定を確定

## 現在のCI設定
```yaml
test-macos:
  runs-on: macos-15-intel
  steps:
    - uses: actions/checkout@v4
    - uses: douglascamata/setup-docker-macos-action@v1
    - name: Install BATS
      run: brew install bats-core
    - name: Start shared services
      run: |
        cd shared-services
        cp templates/postgres.yml .
        cp templates/traefik.yml .
        docker compose -f postgres.yml -f traefik.yml up -d
        until docker exec shared-postgres pg_isready -U root; do sleep 1; done
    - name: Run all tests
      env:
        LC_ALL: en_US.UTF-8
        LANG: en_US.UTF-8
      run: bats tests/
```

## コスト情報
- macOSランナー: $0.08/分（Linuxの10倍）
- 無料枠2,000分のうち、macOSは実質200分相当
- 今回の調査で約$6.47消費（約40%の無料枠）
