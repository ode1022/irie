# Changelog

## [2.0.1](https://github.com/ode1022/irie/compare/irie-v2.0.0...irie-v2.0.1) (2026-02-05)


### Bug Fixes

* start-taskのClaude起動プロンプトにブランチ作成済み情報を追加 ([cd6615b](https://github.com/ode1022/irie/commit/cd6615b32a2d9cbce83852ce9dcd9e5ccbb270b1))

## [2.0.0](https://github.com/ode1022/irie/compare/irie-v1.2.0...irie-v2.0.0) (2026-02-05)


### ⚠ BREAKING CHANGES

* start-ticketをstart-taskにリネームし、自由テキスト入力・--baseオプションに対応

### Features

* start-ticketをstart-taskにリネームし、自由テキスト入力・--baseオプションに対応 ([3351a2a](https://github.com/ode1022/irie/commit/3351a2ac10bca8f28ca5f8d7d22404ff41f2061f))

## [1.2.0](https://github.com/ode1022/irie/compare/irie-v1.1.13...irie-v1.2.0) (2026-02-05)


### Features

* DB存在チェック関数を追加、DB初期化判定を改善 ([2585d22](https://github.com/ode1022/irie/commit/2585d223b2a12f6fbd80e6e9485830c391270399))
* HTTPSポートを8443から標準の443に変更 ([4743aae](https://github.com/ode1022/irie/commit/4743aae84bff976cfaf2ee1daae29ebd090519fe))
* irie addで既存ブランチの自動判定とチェックアウトに対応 ([1ed8392](https://github.com/ode1022/irie/commit/1ed8392978aec972e5193bdb6c7bbd50d97e7766))
* irie infoにTraefikダッシュボードURLを追加 ([532a80b](https://github.com/ode1022/irie/commit/532a80bd8bce2be5f419f8d3bf55578212475088))
* post-cleanup.shに並列テストDB削除を追加 ([281497c](https://github.com/ode1022/irie/commit/281497c6122c44561c0a58800f252b3ddc1e262a))
* should_init_db関数を追加してDB初期化判定をシンプル化 ([798ed2b](https://github.com/ode1022/irie/commit/798ed2b2ef375f0dfb23c6d4a89d0bfac115fc01))
* start-ticketコマンドを追加 ([e30a546](https://github.com/ode1022/irie/commit/e30a54656adc92f28d356db81218ca76042aefef))
* start-ticketをURL対応に変更 ([6422371](https://github.com/ode1022/irie/commit/64223719d73da723d17df1b9a04cd3fa75f15ec5))
* start-ticketを複数チケットシステムに対応 ([b91bc89](https://github.com/ode1022/irie/commit/b91bc899e08fa1d8cf3447dcba6aff787ff9f4c4))
* WORKTREE_PREFIXとBASE_DOMAIN環境変数を追加 ([30c5178](https://github.com/ode1022/irie/commit/30c517876e34329847bca7dc8bbb178c1efeaed4))


### Bug Fixes

* irie addでWORKTREE_PREFIXとBASE_DOMAINの置換を追加 ([6349267](https://github.com/ode1022/irie/commit/63492672560ab58006c98dbcf431209b2f8a5c62))
* irie infoでWORKTREE_PREFIXとBASE_DOMAINを渡すように修正 ([1173900](https://github.com/ode1022/irie/commit/1173900cc4b13c5a473a2af48e168e04ea571825))
* macOSでirie openのエディタ検出が失敗する問題を修正 ([8437b01](https://github.com/ode1022/irie/commit/8437b01021a4af4d323818108b24a8c033bd0ea4))
* MCP/CLIを優先、WebFetchは認証で動かないため除外 ([bc77c3a](https://github.com/ode1022/irie/commit/bc77c3af4d5e09b10a8ca5ce3a083e55de52228c))
* start-ticketのブランチ名からバッククォートを除去 ([d90c5b4](https://github.com/ode1022/irie/commit/d90c5b43bd0a7db610e2eaafbfc6e06cd4828e22))
* start-ticketプロンプトでプレーンテキスト出力を明示 ([03b43d4](https://github.com/ode1022/irie/commit/03b43d43e7e7987aeff24a64b146a5e63409d4cf))
* start-ticketをコマンド補完に追加 ([317aa20](https://github.com/ode1022/irie/commit/317aa20ce3eaeaf942f3953794ef12e813dd8305))
* ブランチ名を小文字に統一（Docker対応） ([7c5a1bb](https://github.com/ode1022/irie/commit/7c5a1bb207c5aa2dc5884eb9cbea4d08acc85ee6))
* 削除済みのstatusコマンドへの参照を削除 ([cf6345b](https://github.com/ode1022/irie/commit/cf6345bd1d3d9ea77490a4a8f7f54ed910103a26))


### Reverts

* ブランチ名小文字化を元に戻す ([402c100](https://github.com/ode1022/irie/commit/402c10053057842e8233c2c55ba1c4b0604e284a))

## [1.1.13](https://github.com/ode1022/irie/compare/irie-v1.1.12...irie-v1.1.13) (2026-01-16)


### Bug Fixes

* irie remove時のworktree削除を改善 ([25ef1a8](https://github.com/ode1022/irie/commit/25ef1a81e392cdb6bef0fcea2b76507321891b91))

## [1.1.12](https://github.com/ode1022/irie/compare/irie-v1.1.11...irie-v1.1.12) (2026-01-16)


### Bug Fixes

* irie remove時のworktree/ブランチクリーンアップを改善 ([c31d6bd](https://github.com/ode1022/irie/commit/c31d6bdc2538960c6fe57a9d3dda2d9270a7ae45))

## [1.1.11](https://github.com/ode1022/irie/compare/irie-v1.1.10...irie-v1.1.11) (2026-01-14)


### Bug Fixes

* 出力順序を確実に修正（exec 1&gt;&2でstderrに統一） ([fb96dd8](https://github.com/ode1022/irie/commit/fb96dd86d1e28f2fc267e67a66cc7586a0d5646c))

## [1.1.10](https://github.com/ode1022/irie/compare/irie-v1.1.9...irie-v1.1.10) (2026-01-14)


### Bug Fixes

* 出力順序を修正（stdoutフラッシュ用の遅延を追加） ([d412865](https://github.com/ode1022/irie/commit/d412865a41a2c76918e9652bf828d1a7b9d38ec3))

## [1.1.9](https://github.com/ode1022/irie/compare/irie-v1.1.8...irie-v1.1.9) (2026-01-14)


### Bug Fixes

* パイプを使わずファイル経由でcdパスを渡す ([9372134](https://github.com/ode1022/irie/commit/9372134fd91aedbadfd1279c91dff509d67bc31e))

## [1.1.8](https://github.com/ode1022/irie/compare/irie-v1.1.7...irie-v1.1.8) (2026-01-14)


### Bug Fixes

* shell関数の出力バッファリング問題を修正 ([4634dab](https://github.com/ode1022/irie/commit/4634dab4a094261680fd8fa299227203f3e7d318))

## [1.1.7](https://github.com/ode1022/irie/compare/irie-v1.1.6...irie-v1.1.7) (2026-01-14)


### Bug Fixes

* stdbufをirie本体から適用するように変更 ([abb788d](https://github.com/ode1022/irie/commit/abb788d825ec692d9f89632d8caba131e5ad708e))

## [1.1.6](https://github.com/ode1022/irie/compare/irie-v1.1.5...irie-v1.1.6) (2026-01-14)


### Bug Fixes

* stderr出力を削除してstdbufのみに統一 ([c3c7fc3](https://github.com/ode1022/irie/commit/c3c7fc3047227e4def085d90230a0190ac401b41))

## [1.1.5](https://github.com/ode1022/irie/compare/irie-v1.1.4...irie-v1.1.5) (2026-01-14)


### Bug Fixes

* stdbufを使用して出力を即座にフラッシュ ([75a25c2](https://github.com/ode1022/irie/commit/75a25c2233233554c7959409a521ea8e4e571b69))

## [1.1.4](https://github.com/ode1022/irie/compare/irie-v1.1.3...irie-v1.1.4) (2026-01-14)


### Bug Fixes

* ヘッダー出力をstderrに変更して即座に表示 ([f7f8254](https://github.com/ode1022/irie/commit/f7f8254291a1d3aadb7815beb172bc5fbdbd281d))

## [1.1.3](https://github.com/ode1022/irie/compare/irie-v1.1.2...irie-v1.1.3) (2026-01-14)


### Performance Improvements

* MySQLに開発環境向けチューニングを追加 ([a9a91b8](https://github.com/ode1022/irie/commit/a9a91b8cd7c1c6b62fdcae7f06abe9575a79ca25))

## [1.1.2](https://github.com/ode1022/irie/compare/irie-v1.1.1...irie-v1.1.2) (2026-01-14)


### Bug Fixes

* restore Japanese comments in test_completion.bats ([7d8ee13](https://github.com/ode1022/irie/commit/7d8ee138fb8f7729bb7e4f075f1f83b8c38ec6f2))

## [1.1.1](https://github.com/ode1022/irie/compare/irie-v1.1.0...irie-v1.1.1) (2026-01-14)


### Bug Fixes

* replace Japanese test names with English for macOS CI compatibility ([38aad6c](https://github.com/ode1022/irie/commit/38aad6cd096d06d09bcc14591f8f009dda7dd780))

## [1.1.0](https://github.com/ode1022/irie/compare/irie-v1.0.0...irie-v1.1.0) (2026-01-14)


### Features

* --baseオプションのデフォルト動作改善とブランチ補完追加 ([748a278](https://github.com/ode1022/irie/commit/748a27883811f4cbce9b89fef150f4a3ccf7787e))

## Changelog
