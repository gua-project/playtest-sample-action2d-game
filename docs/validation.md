# 検証記録（履歴）

この文書は各実行時点の結果・失敗・証拠所在を保持する履歴です。現行の期待値は [test-matrix.md](test-matrix.md)、実行層と判定契約は [test-ownership.md](test-ownership.md) を参照してください。過去の成功は現在のHEADやPlaytest E2Eの合格を保証しません。

提出・承認調整の経緯は [PR #2 の保存コメント](https://github.com/gua-project/playtest-sample-action2d-game/pull/2#issuecomment-6487384380) に移しています。

## 2026-10-29 責務分担変更

ゲームコード・Godot4.7・Gua1.1.2は変更せず、旧JS外部EXE runnerを退役。正式Gua.Testing/Gua.Testing.Godotのsource scene回帰、内部モデル回帰、起動だけの配布smokeへ整理した。以下は記録時点の結果である。下記のEXE操作結果とCIは移行前の履歴であり、Playtest E2Eの成功ではない。Playtest側の統合は未実行。GUI承認未完了も維持する。独立レビュー既存1回は移行前のもので、その後ユーザー依頼で今回の移行差分を別枠の独立レビュー1回にかけ、MR01–03を修正した。既知指摘の修正確認のみ同じレビュー内で行い、記録はmigration-review.mdを参照。

- 正式 NuGet 1.1.2 を locked restore、.NET 10でコンパイル。source scene回帰13件成功・失敗0・skip0。TRX: `output/source-regression-results/20261029T115921371/source-regression.trx`。各ケースに公式Observe/World/Diagnostics JSONと明示保存fixtureを添付。
- import（既存拡張cacheも一時分離）、内部モデル32assert、source起動smoke成功。移行前のGDScript直接UI統合10assertは正式C#へ移したため現在の件数に加算しない。
- 正式guarded UI/入力の完了をpollし、clockはSDKの `RunClockForAsync` を利用。観測待機は正式操作完了後のUI/Worldを基準とし、さらにObserve documentのuiFrame/worldFrameと全項目availableを揃える。起動時も同じreadinessを待つ。連続移動は各固定ステップで同じSDK所有入力を更新する。更新なしで短い時計要求を反復する初期試行ではSDKのhost completion timeoutが発生したため、この更新なしの長時間保持契約は未検証として残す。独自wireへのフォールバック、SDK/addon改変はしていない。
- B01はsoftlockにより荷物も復帰しないため、cargo位置の復元は正常版だけへ要求する。B02はcargo_lost、B03は同tickの死亡と配送の増加を個別期待値として判定。
- 既存配布EXEの起動・読込・正常終了だけのsmoke成功（`output/distribution-smoke/20261029T113233342/`）。新CI初回はgua-testerの通常Windows engine EXEをPowerShellが待たず、import exit code未取得で失敗（run40807039810）。PowerShellのimport/exportだけ同じ公式archive内のconsole EXEへ変更し、source hostの通常EXEは維持した。同HEAD eb8dcbb のPR run40807308595は全step成功したが、push run40807303665はロード時のstale_guardで失敗した。後者も成功扱いせず、要求前に拒否されたstale_guardだけ、同epochでLocatorと最新UIを再検証する上限2回の再観測に修正。enqueue済み・不確実・timeoutの操作は再送しない。続くHEAD567b49bもPR run40807898303は成功、push run40807890447は開始/Load/replayの古いObserveと起動時unavailableで4件失敗した。操作前のフレーム進行を完了後の公開と誤認していた待機を上記へ修正し、SetUp失敗後に前ケースのdisposed hostを参照するTeardownも修正。最終結果はPR checksと本文を参照。配布EXEの操作/探索/再起動/Trace/ReplayはこのCIの対象外、Playtest E2Eは未実行。
- .NET CLI初回実行で開発証明書の作成を示すメッセージが出た。信頼操作は実行していない。以降のscript/CIは `DOTNET_GENERATE_ASPNET_CERTIFICATE=false` を指定した。証明書storeの変更有無は未判定で、追加のstore操作は行っていない。

## 移行前の検証履歴

2026-10-28。作業ブランチ `feat/delivery-factory`。ゲームとテストの検証対象commitは `b7e2e2ee05c7ff9ba4ec8636f62c21d552b05245`。後続はCI import引数と証拠文書の変更。

## 確認済み

- 仕様: issue #1 本文と全コメントを取得、コメント0件。
- 既存 Godot `4.7.stable.official.5b4e0cb0f` と Windows release export templates を発見。共有インストール・共有設定変更なし。
- 正式 Gua 1.1.2 ZIP のSHA256 `19f89058ca60e48c74a7327da31c0e011b4c053acfda8e5b8e2e2b1fc90ae8c4` を検証し checkout 内へ展開。
- `scripts/verify.ps1`: import・32モデルassert・10 UI/保存統合assert・起動smoke成功。`output/model-tests.log`, `output/ui-tests.log`, `output/smoke.log`。日英タイトル/ポーズ/結果の基準viewport内の収まり、実ファイル復元、不正JSONの未適用、設定永続化も判定。
- 外部 source Godot → Gua WebSocket で3配送・死亡0・再プレイ成功。固定時計のWorld位置同期遅れを実行で発見して修正。
- **Windows release EXE → 正式 Gua1.1.2 の実通信**: 21受入assert、3配送・死亡0・再プレイ、保存後に状態を変更してから位置/tick/言語を復元、別プロセス再起動復元に成功。
- 外部EXEの通常入力のみで、正常版とB01/B02の落下復帰・荷物消失比較、B03の同tickゴール/死亡比較に成功。設置後落下→復帰→再回収の目的探索に成功。テレポート・専用クリア操作なし。
- 実時間のEXE（virtual clock未導入）をGuaで操作し、約28秒で3配送・死亡0に成功。固定ステップの結果とは別JSONに記録。
- 独立read-onlyレビュー1回実施。保存がno-opでも通る旧テストを状態変更/再起動比較へ修正、Guaバージョンと入力ID/typeをassert、ロード設定の永続化、run別証拠保存に対応。
- 実EXEの強化した保存試験がJSON数値型のロード拒否を検出し修正。UI統合試験で終了時の解放済みボタン参照を検出し、ゲーム側の同じボタンを再利用して正式addonは変更せず対応。

## 2026-10-28–29 旧runnerのローカルEXE証拠

この旧EXE試行のSHA256: `379fe8cdc69180e684cdea1fb10f7ada34bb0455dd11973eecc7bda2c7853263`。

- [固定ステップ21項目・正常版/B01/B02](evidence/windows-fixed.json): passed。
- [設置/落下/再回収とB03正常比較](evidence/windows-exploration.json): 3項目passed。
- [別プロセス再起動復元](evidence/windows-restart.json): passed。
- [実時間の3配送](evidence/windows-realtime.json): 28,121ms、死亡0、passed。
- [2026-10-29追加の足場端/死亡ポーズ](evidence/windows-boundaries.json): 実EXEの通常入力で2tick/8tickのジャンプ境界と、死亡直後のポーズ→一回復帰の3ケースpassed。既存の成功試験はローカル再実行せず、不足していたケースだけを追加。ゲーム本体とEXEは変更なし、独立レビュー回数も1回を維持。
- raw wire: `output/runs/20261028T144658930-exe/`。run途中の失敗も別timestampディレクトリに保持。位置・状態の取得には異なるtree frameがあり、固定時計完了はUI/Worldの両フレームで待つ。

## 未完了・ブロッカー

- メニュー寿命修正後の最終EXEも上記の固定・実時間全試験に成功。
- GUI対象 `Delivery Robot Factory` のウィンドウ発見・起動まで実施。画面取得のアプリ承認が `Computer Use app approval timed out`。GUI入力は実行されず、対象PIDとパスを照合して終了、枠解放済み。画像／人間のキー入力・操作感・各実サイズの実表示は未検証。承認を迂回していない。音は未実装。
- 外部Guaの同tickプレス境界、設置後落下、足場端の2/8tick入力、死亡直後ポーズと再開を確認済み。足場端や着地直前の広範なタイミング探索は未実施（モデルに着地直前の代表ケースあり）。
- Windows hosted CI のeditor終了時に `-1073741819` (0xC0000005) を検出。既存サンプル同様にimport中だけ拡張の自動ロードを分離し、exportには公式recovery modeを使用。実行前には必ず正式Guaを有効に戻し、生成EXEのバージョンと実通信をassertする。終了コードを無視せず、Windows runtime試験を省略していない。
- **CI成功**: [run 40640580981](https://github.com/gua-project/playtest-sample-action2d-game/actions/runs/40640580981)、対象commit `9fb77fef69431d0e4775a1237414c7469308bc85`。公式依存取得、import、42項目、Windows export、実EXEの固定/実時間・3個別バグ比較・探索・再起動復元を通過。配布ZIPとraw wire/JSONは同runの `windows-evidence-<commit>` artifactに保存。

初期の `output/exe-fixed/` は試行で上書きされたため、全初期失敗のraw保持は主張しない。以後は `output/runs/<timestamp>-exe` と `-source` に分離し、EXE SHA256・source hash・実行時commitを対応付ける。実プロセス接続の初期失敗は、自分の初期ホストとのポート競合を解消した後に復旧。未検証・エラーを成功に数えない。

## 移行修正の対象とCI

対象HEAD `0f904d4c512bdd0e10e338a3837925f0e1447383`、2026-10-29の正式source回帰13件・内部32assert・export・限定起動smoke: [PR CI](https://github.com/gua-project/playtest-sample-action2d-game/actions/runs/40809704503)、[push CI](https://github.com/gua-project/playtest-sample-action2d-game/actions/runs/40809698542) は成功。ローカル試行の個別結果・テスト/fixture SHAは [source-regression-summary.json](evidence/source-regression-summary.json)。独立移行レビューとMR01–03の修正確認は [migration-review.md](migration-review.md) に保持する。配布EXEの操作・探索・Playtest E2Eはこの成功の対象ではない。

CI artifactは各runのArtifacts欄から取得する。PR runはmerge checkout、push runはbranch HEADであり、artifactのSHAとbranch HEADを混同しない。rawログとTRXのローカル相対パスは記録者のcheckout内の所在で、Gitへ収録したファイルではない。CI artifactは保存期限があるため長期可用性を保証しない。

## 旧ケースの移行対応（履歴）

旧版 `a40816fe2bd3f4574df557793f92d7d984a82694` から正式source回帰への対応。旧ファイル名はgit履歴上の名称であり、現行の実行コマンドではない。旧期待値と実行JSONは `evidence/windows-*.json`、旧raw wireはローカル `output/runs/` と旧CI artifactに保存した。現行契約はtest-matrix.md/test-ownership.mdを参照する。

| 旧ファイル・ID | 維持する目的/期待値 | 現在の所有先 |
|---|---|---|
| model_tests.gd T01–T13 | seed再現、ジャンプ/運搬、移動床/コンベア、着地先行入力、内部復元、競合、モデル内通常ルート | 同ファイルを高速な内部単体回帰として維持。直接状態準備を使う。Gua UIやEXE/Playtestの証拠ではない |
| ui_tests.gd U01–U04 | 日英の論理境界、保存復元/設定永続化、不正JSON未適用 | C# `LanguageMenusFitTheLogicalViewport` / `MenuPauseSaveLoadAndSourceRestart` / `InvalidSaveDoesNotChangeTheLiveState`。旧GDScript直接UI操作は削除 |
| exe-acceptance.mjs E01/E02 | Gua1.1.2、Observe、標準入力map | C# SourceSceneが正式SDKへ接続しversion/Observeとguarded入力を使用。sourceでの確認。EXE版互換性全体は将来Playtest |
| 同 E03/E04/E05 | 開始、pauseで停止、保存後に変更→復元、言語/サイズ保持 | C# `MenuPauseSaveLoadAndSourceRestart`。サイズは設定値/論理UIであり実サイズの画像保証ではない |
| 同 E06 / realtime.mjs R01 | 通常開始から3配送、死亡0。実時間/固定ステップを区別 | 将来Playtest E2E PT-A2D-DELIVERY / PT-A2D-REALTIME。現在のC#へ探索/走破policyを移植しない。過去成功は履歴のみ |
| 同 E07 | 結果→再プレイで進行初期化 | C# `ResultScreenReplayResetsProgress`。明示保存fixtureから最後の配送だけを通常入力する短いsource回帰。3区間走破ではない |
| 同 E08 | 正常落下復帰、B01停止、B02荷物消失 | C# `CargoFallDetectsOnlyTheSelectedKnownBug`。seed112、タイトルの個別フラグ、通常取得/落下で比較 |
| restart-check.mjs E09 | 保存状態を別プロセスで復元 | sourceの再起動はC# MenuケースとNonDefaultProgressケース。配布EXEの再起動/所有権は将来Playtest PT-A2D-RESTORE |
| exploration.mjs X01 | 設置→落下→復帰→回収を目的に探索 | 将来Playtest PT-A2D-RECOVER。探索driverはサンプルから削除。内部の荷物復元期待値はT07とsourceのCargoFallに保持 |
| 同 E10 | ゴール/死亡同tick、正常死亡優先、B03だけ二重結果 | C# `PreparedDockContactGivesDeathPriorityUnlessBugEnabled`。明示saveをUIロードし通常move1tickで接触。Playtestの通常経路/探索とは別 |
| boundaries.mjs X02 | 足場を離れて2/8tick後の入力 | C# `EdgeJumpRespectsCoyoteBoundary`。通常移動で端へ進み、2tickは上昇・8tickは落下 |
| 同 X03 | 死亡直後pause→60tick→resumeで一回復帰 | C# `DeathThenPauseDefersExactlyOneRespawn`。普通の移動で落下、UIpause/resumeで検証 |
| gua-client.mjs | UI/入力要求、poll、Observe/World、時計、独自wire記録 | 削除。正式Gua.Testing APIで相関/所有者を扱う。独自wireやTrace形式は追加しない |
| run-acceptance.ps1 | EXE起動・探索/境界/再起動/実時間を一括実行 | 削除。`run-exe-smoke.ps1` はリソース読込・起動・正常終了のみ。以外のEXE統合はPlaytest |
| V01/V02 | 画像/実サイズ、人間のネイティブ入力、操作感 | 正規GUI承認未完了のため未検証を維持。今回再要求なし |
