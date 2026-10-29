# issue #1・実装・テスト契約

Godot4.7 / 正式Gua1.1.2 / 内容版`factory-scenario-1` / seed112 / bugs=[]を既定とする。バグ比較は指定IDだけを有効化する。実行層とfixtureの詳細は [test-ownership.md](test-ownership.md)、実行方法は [README](../README.md#開発ビルド) を参照。下記は期待値であり、実行成功の一覧ではない。実行日時・対象build・結果は [validation.md](validation.md) に分離する。

## 内部モデル回帰

`tests/model_tests.gd`は内部状態の準備を許す単体回帰。source UI・配布EXEで通常操作した証拠とは区別する。

| ID | 初期条件・手順 | 期待結果 | 実装 |
|---|---|---|---|
| T01 | 同seed・同入力列120tick | snapshot一致、位相・物理再現 | tick/platform_position |
| T02 | 移動後pauseし60tick | tick・位置・障害停止 | tick |
| T03 | 中断snapshotをJSON化→復元、不正位置型でも試行 | 状態持越し、不正保存は未適用 | snapshot/restore |
| T04 | 初期状態からジャンプ3tick解放／16tick保持 | apex差40px以上 | tick |
| T05 | 運搬あり／なしで移動・ジャンプ | 運搬時に速度とジャンプが弱い | interact_cargo/tick |
| T06 | 移動床付近の穴の下へfixture準備し2tick | 正常は死亡1・復帰1、B01はsoftlock | die/respawn |
| T07 | 所持死亡直後pause→resume | pendingは1回、正常は荷物復元、B02は消失 | die/respawn |
| T08 | 同tick死亡＋ゴールのfixture | 正常は死亡のみ、B03は配送も記録 | resolve_contacts |
| T09 | 移動床上に接地し1tick | 相対位置維持 | tick |
| T10 | 着地1tick前にジャンプ押下 | 先行入力で次tick跳ぶ | buffer/coyote |
| T11 | 第2区間コンベア上で無入力 | ベルト方向に動く | tick |
| T12 | 内部入力で取得・ジャンプ・プレス待機・配送を3区間 | deliveries3/deaths0、result | factory |
| T13 | 結果からreplay | play/stage0/deliveries0 | replay |

## 正式Gua source回帰

[FactoryRegressionTests.cs](../tests/dotnet/FactoryRegressionTests.cs)を`GodotSceneTestHost`でsource sceneへ実行する。各ケースは分離した保存・出力先で開始する。旧E/U/X IDは履歴との対応ラベルであり、EXEテストという意味ではない。

| 対応ID・ケース | 初期条件・手順 | 独立した期待結果 |
|---|---|---|
| E01/E02・各source起動 | version、Observe、標準入力mapを正式SDKで取得 | core/runtime/Godot plugin各1.1.2、Observe18項目以上available、actionがexact3件でmove:axis1d、jump/interact:button |
| E03–05/E09/U02–03・MenuPauseSaveLoadAndSourceRestart | 通常Start→6tick→Pause→60tick→Save。Resumeで移動し言語/サイズ変更後Load、さらにsource再起動後Load | pause中frame不変。保存前のframe/stage/seed/deaths/deliveries/carrying/checkpoint/bugsとpositionを両経路で復元、paused=true。変更した英語/size1から保存済み日本語/size0へ戻る |
| U03・同ケースの設定初期化 | titleでUIからen/size1を保存→source再起動→Start/Pause/Save | Startの英語表示と新しいゲーム保存payloadのlocale=en/size1。既定値への一致だけで初期化を判定しない |
| E09・NonDefaultProgressSurvivesSaveLoadAndSourceRestart | 明示dock fixtureでstage2/deliveries2/deaths3/所持・checkpoint=true/B03のみ/frame128。準備ファイル削除後UI Save→Reset/Start→Load、source再起動→Load | Saveがファイルを再生成し、保存前の旧7キー＋bugs、position/pausedを両経路で復元 |
| U01・LanguageMenusFitTheLogicalViewport | title/pause/resultを日英、playを英語で確認。result準備は安全位相dock fixture | visibleなSemantic UI boundsが1152×720内。文字描画・実ウィンドウサイズの画像保証ではない |
| U04・InvalidSaveDoesNotChangeTheLiveState | Start→3tick→Pause、不正JSONを書きLoad | Observe状態とposition不変、UIにLOAD ERROR |
| X02・EdgeJumpRespectsCoyoteBoundary | 通常移動でx505付近から足場を離れ、2/8tick後にjump | 2tickは猶予内で上昇、8tickは空中ジャンプせず落下、deaths0 |
| X03・DeathThenPauseDefersExactlyOneRespawn | 通常移動で落下死亡、次tick前にPause→60tick→Resume | 停止中はpending_respawn維持、再開1tickで一回復帰、pos=[64,478]、二重死亡なし |
| E08・CargoFallDetectsOnlyTheSelectedKnownBug | 通常Start・x145付近で取得→通常移動で落下。bugs=[]/B01のみ/B02のみを比較 | deaths1、所持解除。正常は復帰し荷物も復元。B01はsoftlocked=true、B02はcargo_lost=true。B01に正常復帰済みのcargo位置は要求しない |
| E10・PreparedDockContactGivesDeathPriorityUnlessBugEnabled | 危険直前frame67のdock fixture、正常/B03のみ。Resume→move1tick | 正常はdeaths1/deliveries2/outcomes3、B03はdeaths1/deliveries3/outcomes4 |
| E07・ResultScreenReplayResetsProgress | 安全frame128のdock fixture、正常。Resume→move1tick→Replay | result/deliveries3/deaths0からplay/stage0/deliveries0、pos=[64,478] |

## 配布smoke・Playtest・GUI

| ID・対象 | 初期条件・手順 | 期待結果／現在の判定範囲 |
|---|---|---|
| 配布起動smoke | build/windowsのEXEを専用port/save/outputでheadless起動し30frameで終了 | DLL/リソース読込・起動マーカー・エラーなし・exit0のみ |
| E06・PT-A2D-DELIVERY | 通常Start→取得・ジャンプ・障害待機・配送を3区間→Replay | deliveries3/deaths0/result、その後play/stage0/deliveries0。Playtest E2E未実行 |
| R01・PT-A2D-REALTIME | 通常Start、仮想時計なしで配送 | 壁時計とsimulation tickを別記録して3配送を確認。Playtest E2E未実行。旧試験の120秒は製品の既定上限ではない |
| E09・PT-A2D-RESTORE | 配布EXEで保存後に状態変更し、EXE再起動またはattach→Load | 保存位置・所持・checkpoint・進行・seed・flags復元、paused。Playtest E2E未実行 |
| X01・PT-A2D-RECOVER | 荷物を設置→落下→復帰→再回収・配送を探索 | 所持と荷物の整合、復帰後carrying=false/cargo_lost=false、再配送可能。Playtest E2E未実行 |
| E08/E10・PT-A2D-B01/B02/B03 | 配布EXEの通常経路で各再現条件を成立 | [design.md](design.md)の正常/注入差分を検出。Playtest E2E未実行。sourceの準備fixtureを通常走破に昇格しない |
| V01 | 日英・960×600/1152×720/1440×900でtitle/pause/play/resultを画像確認 | 欠け・重なり・誤表示なし。GUI未検証 |
| V02 | ネイティブキーで通常Start→配送→Replay | 入力・難度・操作感が実時間で成立。GUI/人間操作未検証 |

固定ステップはエージェントの判断速度を測らない。状態値による判定は画像・音・人間の操作感を保証しない。配布EXEの過去の結果は検証記録に保持し、未実行Playtestの成功には使わない。
