# テスト責務と旧ケースの移し先

今回の整理はユーザー承認の責務分担に従う。JSをC#へ全量移植する変更ではない。旧実装は commit `a40816fe2bd3f4574df557793f92d7d984a82694`、旧期待結果と実行JSONは `docs/evidence/windows-*.json` とgit履歴に保持する。旧raw wireはローカル `output/runs/`、旧CI artifactに残る。これらは旧テストの履歴であり、現在の回帰やPlaytest E2Eの成功に昇格させない。

| 旧ファイル・ID | 維持する目的/期待値 | 現在の所有先 |
|---|---|---|
| model_tests.gd T01–T13 | seed再現、ジャンプ/運搬、移動床/コンベア、着地先行入力、内部復元、競合、モデル内通常ルート | 同ファイルを高速な内部単体回帰として維持。直接状態準備を使う。Gua UIやEXE/Playtestの証拠ではない |
| ui_tests.gd U01–U04 | 日英の論理境界、保存復元/設定永続化、不正JSON未適用 | C# `LanguageMenusFitTheLogicalViewport` / `MenuPauseSaveLoadAndSourceRestart` / `InvalidSaveDoesNotChangeTheLiveState`。旧GDScript直接UI操作は削除 |
| exe-acceptance.mjs E01/E02 | Gua1.1.2、Observe、標準入力map | C# SourceSceneが正式SDKへ接続しversion/Observeとguarded入力を使用。sourceでの確認。EXE版互換性全体は将来Playtest |
| 同 E03/E04/E05 | 開始、pauseで停止、保存後に変更→復元、言語/サイズ保持 | C# `MenuPauseSaveLoadAndSourceRestart`。サイズは設定値/論理UIであり実サイズの画像保証ではない |
| 同 E06 / realtime.mjs R01 | 通常開始から3配送、死亡0。実時間/固定ステップを区別 | 将来Playtest E2E PT-A2D-DELIVERY / PT-A2D-REALTIME。現在のC#へ探索/走破policyを移植しない。過去成功は履歴のみ |
| 同 E07 | 結果→再プレイで進行初期化 | C# `ResultScreenReplayResetsProgress`。明示保存fixtureから最後の配送だけを通常入力する短いsource回帰。3区間走破ではない |
| 同 E08 | 正常落下復帰、B01停止、B02荷物消失 | C# `CargoFallDetectsOnlyTheSelectedKnownBug`。seed112、タイトルの個別フラグ、通常取得/落下で比較 |
| restart-check.mjs E09 | 保存状態を別プロセスで復元 | sourceの再起動はC# Menuケース。配布EXEの再起動/所有権は将来Playtest PT-A2D-RESTORE |
| exploration.mjs X01 | 設置→落下→復帰→回収を目的に探索 | 将来Playtest PT-A2D-RECOVER。探索driverはサンプルから削除。内部の荷物復元期待値はT07とsourceのCargoFallに保持 |
| 同 E10 | ゴール/死亡同tick、正常死亡優先、B03だけ二重結果 | C# `PreparedDockContactGivesDeathPriorityUnlessBugEnabled`。明示saveをUIロードし通常move1tickで接触。Playtestの通常経路/探索とは別 |
| boundaries.mjs X02 | 足場を離れて2/8tick後の入力 | C# `EdgeJumpRespectsCoyoteBoundary`。通常移動で端へ進み、2tickは上昇・8tickは落下 |
| 同 X03 | 死亡直後pause→60tick→resumeで一回復帰 | C# `DeathThenPauseDefersExactlyOneRespawn`。普通の移動で落下、UIpause/resumeで検証 |
| gua-client.mjs | UI/入力要求、poll、Observe/World、時計、独自wire記録 | 削除。正式Gua.Testing APIで相関/所有者を扱う。独自wireやTrace形式は追加しない |
| run-acceptance.ps1 | EXE起動・探索/境界/再起動/実時間を一括実行 | 削除。`run-exe-smoke.ps1` はリソース読込・起動・正常終了のみ。以外のEXE統合はPlaytest |
| V01/V02 | 画像/実サイズ、人間のネイティブ入力、操作感 | 正規GUI承認未完了のため未検証を維持。今回再要求なし |

## source保存fixture

`tests/fixtures/dock-save.json` は source回帰用の明示的な初期条件。通常プレイの操作ではない。ステージ3・配送2・所持あり・x1499/y478・seed112を保存してUIのLoadから復元する。frame67は危険開始の直前、frame128は安全位相。バグIDだけを各TestCaseに応じて設定する。

その後の配送口への接触は正式Game Inputのmoveで実行し、内部のclear/die/setterは呼ばない。通常3区間を配送した証拠には使わない。NUnitは固定fixtureが持つ期待した不具合を検出できたら成功するため、注入ゲームが正常という意味でもPlaytestのScenario Passedでもない。

## 監査と結果の扱い

独立レビューの既存1回を維持し、今回のC#・CI・責務整理は追加の独立監査をしていない。今回のコンパイル/ローカル実行/CI結果を別途 validation.md とTRXで報告する。失敗・未実行・API制約は成功/skipへ変換しない。SDK不足なら具体的な呼び出し・状態を報告し、サンプル独自runnerやwireで補完しない。

正式APIの正本: [Gua.Testing.Godot source host 1.1.2](https://github.com/gua-project/gua/blob/gua-v1.1.2/bindings/dotnet/src/Gua.Testing.Godot/GodotSceneTestHost.cs)、[共通SDK](https://github.com/gua-project/gua/blob/gua-v1.1.2/bindings/dotnet/src/Gua.Testing/GuaWebSocketContext.cs)、[guarded dispatch](https://github.com/gua-project/gua/blob/gua-v1.1.2/bindings/dotnet/src/Gua.Testing/GuaRemoteGuardedDispatch.cs)。source UI回帰では要求前のstale_guard拒否だけを同epochの再観測・Locator再検証後に最大2回再要求する。enqueue後の拒否/不確実/timeoutを再要求で隠さない。
