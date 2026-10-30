# テスト責務と判定契約

## 実行層

| 層 | 実行対象・方法 | 判定する範囲 | 判定しない範囲 |
|---|---|---|---|
| 内部モデル回帰 | `scripts/verify.ps1` → `tests/model_tests.gd` | seed再現、物理、境界、保存モデル、既知バグの正常/注入比較。内部状態を準備するfixtureを使う | Gua UI・配布EXE・Playtest E2E |
| 正式Gua source回帰 | `scripts/run-source-tests.ps1 -Restore` → `tests/dotnet/FactoryRegressionTests.cs` | GodotSceneTestHostで`res://main.tscn`を起動し、正式UI/Game Input・Observe・Worldで固定ケースを検証 | 配布EXEの受入、探索policy、通常3区間走破、画像・実サイズ・人間の操作感 |
| 配布起動smoke | `scripts/run-exe-smoke.ps1` | EXEのリソース/DLL読込、起動マーカー、エラーログなしの正常終了 | 外部接続・操作・探索・Goal判定・Trace/Recording/Replay |
| Playtest E2E | [接続情報と独立期待値](playtest-handoff.md) | 配布EXEのlaunch/attach、Scenario/Environment、探索、予算・中断・cleanup、Run/Result、Trace/Recording/Replay | サンプルrepoに代替runnerを置かない。統合は未実行 |

Godot4.7、正式Gua.Testing/Gua.Testing.Godot 1.1.2、seed112、bugs=[]が既定。既知バグ比較だけ対応IDを一つ有効化する。ケースの初期条件・手順・期待結果は [test-matrix.md](test-matrix.md)、実行コマンドと依存は [README](../README.md#開発ビルド) を参照する。

## 実行方法

Windows x64、PowerShell 7、.NET 10 SDK、既存Godot4.7と同版export templateを使う。正式addonの取得・importはREADMEの準備手順を行い、repo rootで実行する。

```powershell
./scripts/verify.ps1                    # 内部モデルとsource起動smoke
./scripts/run-source-tests.ps1 -Restore # locked restoreと正式source回帰
./scripts/build-windows.ps1             # 配布物を更新
./scripts/run-exe-smoke.ps1             # 配布起動だけを確認
```

source回帰はport18241、配布smokeは18244を使う。scriptは使用中portを検出したら失敗し、無関係なプロセスを終了しない。保存・APPDATA・出力はcheckout内で分離し、保存復元ケースだけ同じテストのsaveをsource再起動へ引き継ぐ。配布EXEの再起動E2Eとは区別する。[CI](../.github/workflows/windows.yml)も同じ層を別stepで実行する。

## 正式APIと同期

source回帰はゲームのSemantic UIと標準Game Inputを使う。モデルのclear/die/setterは呼ばない。正式Locatorで対象がvisible/enabledであることを確認し、guarded dispatchの相関済み完了を待つ。要求前の`stale_guard`拒否だけを、同epochの再観測・Locator再検証後に最大2回再要求する。enqueue後の拒否、不確実、timeoutは再要求せず失敗にする。

時計はSDKの`RunClockForAsync`を使用する。完了後のUI/Worldフレームより新しいObserve documentのuiFrame/worldFrameと、登録値のavailable状態を揃えてから判定する。起動時にも同じreadinessを待つ。C# TimeSpanの精度に合わせた時計stepは16.6667msであり、ゲーム側の固定60Hz以外の物理schedulerは持たない。連続移動の固定回帰では同じSDK所有入力を各stepで更新する。更新なしの長時間保持入力契約は未検証。

source起動時にはcore/runtime/Godot plugin各versionが1.1.2、標準入力mapがちょうど3件（move:axis1d、jump:button、interact:button）であることを確認する。Observeの利用不能や環境エラーを既知バグ検出や成功に読み替えない。

正本: [source host](https://github.com/gua-project/gua/blob/gua-v1.1.2/bindings/dotnet/src/Gua.Testing.Godot/GodotSceneTestHost.cs)、[共通SDK](https://github.com/gua-project/gua/blob/gua-v1.1.2/bindings/dotnet/src/Gua.Testing/GuaWebSocketContext.cs)、[guarded dispatch](https://github.com/gua-project/gua/blob/gua-v1.1.2/bindings/dotnet/src/Gua.Testing/GuaRemoteGuardedDispatch.cs)。

## 保存fixtureと独立期待値

[tests/fixtures/dock-save.json](../tests/fixtures/dock-save.json) はsource回帰の明示的な初期条件。stage=2（第3区間）、deliveries=2、carrying/checkpoint=true、pos=[1499,478]、seed112、paused=trueをUIのLoadで復元する。通常プレイでここまで進んだ証拠にはしない。

| 使用ケース | frame・その他の準備 | 手順と期待結果 |
|---|---|---|
| 配送口と危険の同tick接触 | frame67、deaths0/outcomes2、bugs=[]またはB03のみ | Resume→moveを1tick。正常はdeaths1/deliveries2/outcomes3、B03はdeaths1/deliveries3/outcomes4 |
| 結果→再プレイ | frame128、安全位相、bugs=[] | Resume→moveを1tickでresult/deliveries3/deaths0。その後Replayでplay/stage0/deliveries0、pos=[64,478] |
| 非既定進行の保存復元 | frame128、deaths3/outcomes5、B03のみ | Load後に準備ファイルを削除しUI Saveで再生成。Reset/Startで状態変更→Load、さらにsource再起動→Loadで保存前のframe/stage/seed/deaths/deliveries/carrying/checkpoint/bugs、positionとpausedを比較 |

期待値の基準はテスト開始時に固定する。保存前Observe snapshotは保存ファイルの読み戻しから作らず、Saveのno-opは準備ファイルの削除・再生成確認で検出する。既知バグの注入ケースで予定した違反を検出したNUnitの成功は、注入ゲームが正常であることやPlaytest ScenarioのPassedを意味しない。

## 証拠と制約

各sourceケースのTRXは`output/source-regression-results/`、公式APIのObserve/World/Diagnostics JSON添付は`output/source-regression/`、配布smokeのログとEXE SHAは`output/distribution-smoke/`へ分離する。CIは同じ成果物と配布ZIPをartifactへ保存する。これらは独自のPlaytest Run/Trace形式ではない。

GUI画像・実サイズ・ネイティブ入力・操作感は未検証。Playtest E2Eも未実行であり、内部モデルやsource回帰、配布smokeの成功を昇格させない。音は未実装。SDK不足は具体的な未検証事項として記録し、独自wire/runnerで補完しない。

足場端や着地直前の広範なタイミング探索は未実施。モデルT10は着地直前の代表ケース、source X02は足場離脱2/8tick後の代表ケースであり、全タイミングの成立を保証しない。

実行日時・対象SHA・結果・旧ケースの移行対応は [PRの証拠対応](https://github.com/gua-project/playtest-sample-action2d-game/pull/2#issuecomment-6494357576) を参照する。旧EXE試行はPlaytest Run/Traceではなく、現在のHEADの成功証拠でもない。ローカルのraw/ログパスはGitへの保存を意味せず、期限付きCI artifactの長期可用性も保証しない。保存済みの [証拠JSON](evidence/) は元の対象と判定範囲を保って扱う。
