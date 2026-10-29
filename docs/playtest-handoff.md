# Gua Playtest への接続情報（E2E未実行）

この文書は引継ぎ資料であり、PlaytestのScenario/Environmentとしてvalidate済みのファイルでも実行runnerでもない。承認済みPlaytest契約に沿う正式ファイル・engine fixtureとの接続はPlaytest側で行う。まだ存在しない実行機能をこのrepoで代替しない。

## 固定対象

- 対象: `build/DeliveryFactory-windows.zip` をフォルダごと展開した `DeliveryFactory.exe` とGua DLL。
- エンジン: Godot4.7 stable、Gua正式1.1.2。ゲーム/シナリオ内容版 `factory-scenario-1`。この文字列はPlaytest Scenario definitionVersionやGuaライブラリbuildIdとは別。
- 実ゲームbuild: 選択したCI artifactのHEAD・EXE SHA256・ZIP SHA256を実行前に固定する。現在のexportの値は `output/build-sha256.txt` とCI artifactを使う。Gua `get_version.buildId` をゲームbuildIdとして使わない。ホスト/fixtureによる実build identityの確認はPlaytestの接続要件として残す。
- seed112、既定bugs=[]。既知バグ比較はB01/B02/B03を一つずつ有効化。初期状態はタイトルから通常Start、またはEnvironmentで明示承認した保存fixture。fixtureを使った結果を通常Startからの走破と呼ばない。
- このrepoの専用portは18241（source回帰）、18244（限定配布smoke）、GUI使用時のみ18242。Playtest実行では別の明示port/save/outputをEnvironmentに与え、既存プロセスや他repoの保存を共有しない。
- 起動パラメータ/保存: `GUA_BRIDGE_PORT`、`FACTORY_SAVE_DIR`、`--log-file <run専用path>`。通常実時間と `-- --fixed-clock` を区別する。仮想時計の対応確認・操作リース・cleanup/attach権限はPlaytestが所有する。
- 観測: UI `start/pause/resume/save/load/reset/replay/language/size`、world object `robot/cargo/platform/press/goal/checkpoint` の標準position。world Observe `mode/stage/frame/carrying/cargo_lost/checkpoint/deaths/deliveries/outcomes/paused/pending_respawn/softlocked/support/last_event/seed/bugs/press_active/grounded`。Observeは既定Debug。公開profileの選択を独自に上書きしない。
- 通常入力: move(axis1d -1..1)、jump(button hold/release)、interact(button edge)。専用clear操作なし。

## Scenario/Environment候補と独立期待値

すべて**将来Playtest E2E未実行**。以下のIDは候補ラベルであり正式Scenario登録済みという意味ではない。Scenario/Environmentのbytes/hash、fixture/独立期待値の版/hash、実build、seed、flags、clock、許可・上限、Run/Traceの対応をPlaytest側で固定する。

| 候補 | 初期条件/バグ設定 | 独立した期待結果 |
|---|---|---|
| PT-A2D-DELIVERY | 通常Start、seed112、bugs=[]、固定時計の採否明示 | 通常move/jump/interactで3配送→result→replay、stage0/deliveries0へ。未観測の成功禁止 |
| PT-A2D-REALTIME | 同じ開始状態、仮想時計なし | 3配送。壁時計とsimulation tickを別記録し、agent判断/入力遅延とゲームの挙動を分ける。旧120秒は旧smokeの探索上限であり製品既定値にしない |
| PT-A2D-RESTORE | 通常保存後に状態変更し、配布EXEを再起動またはattach | 保存位置/所持/チェックポイント/進行/seed/flags復元、play復元後paused。attachは終了/reset許可を暗黙取得しない |
| PT-A2D-RECOVER | 荷物を設置した直後に落下、bugs=[] | 復帰後carrying=false、cargo_lost=false、荷物を通常操作で回収して配送可能 |
| PT-A2D-B01 | 移動床付近x510..790から落下。正常/ B01_PLATFORM_RESPAWNを比較 | 正常はdeath1→復帰1。注入時softlocked=trueで復帰不能。この違反を製品の正常Passedにしない |
| PT-A2D-B02 | 所持して死亡。正常/ B02_CARGO_LOSSを比較 | 正常は所持解除し荷物復元。注入時cargo_lost=true、配送不能を検出 |
| PT-A2D-B03 | 所持し配送口と危険ゲートに同tick接触。正常/ B03_DOUBLE_RESULTを比較 | 正常は死亡だけで配送数不変。注入時deathsとdeliveries両方増加、outcomesも2増加。この二重結果を検出 |

基準となるゲーム判定と、既知バグが予定どおり存在するというfixture判定は別。Playtest自身が採点したResultだけに頼らず、ここで固定した期待値とゲーム事実・元のGua Traceを照合する。サンプルは別のGoal evaluatorやTrace/Replay engineを提供しない。

## 証拠の扱い

過去のEXE試行の日時・対象SHA・hash・JSON・ログの所在は [検証記録](validation.md) を参照する。旧自作クライアントのJSONはPlaytest Run/Result/Traceではなく、Playtest E2Eの完了証拠には使用しない。新しいRunでは実build identityと証拠を改めて固定する。
参照する正本: [Playtest preparation](https://github.com/gua-project/gua-playtest/blob/main/docs/preparation.md)、[Run責務](https://github.com/gua-project/gua-playtest/blob/main/docs/execution.md)、[fixture独立証拠](https://github.com/gua-project/gua-playtest/blob/main/docs/fixture-evidence.md)、[製品全体E2E #18](https://github.com/gua-project/gua-playtest/issues/18)。
