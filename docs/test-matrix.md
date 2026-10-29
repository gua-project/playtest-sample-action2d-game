# issue #1 → 実装 → テスト対応

現在の責務区分・旧ケースとの全対応は [test-ownership.md](test-ownership.md) を参照。以下の外部EXEケースは過去の期待値を保つ一覧であり、現在はPlaytestへ移管予定・未実行。現行source回帰と同一視しない。

全ケース: Godot4.7 / Gua1.1.2 / scenario `factory-scenario-1` / seed112 / bugs=[] が既定。バグ比較のみ指定IDを一つ有効化する。ビルドIDと実際の結果は validation.md と各実行 JSON を参照。

| ID | 目的・初期状態・手順 | 期待結果／判定根拠 | 実装 | 自動確認と実行層 |
|---|---|---|---|---|
| T01 | 同seedで初期化し同入力列120tick | snapshot一致、位相・物理再現 | factory.tick/platform_position | model_tests.gd |
| T02/E04 | 移動後ポーズ、60tick進める | tick・位置・障害停止 | factory.tick | モデル／外部Gua |
| T03/E05 | 中断snapshotをJSON化→復元、不正位置型で再試行 | 状態持ち越し、不正保存は未適用 | snapshot/restore, main.save_game/load_game | モデル／外部Guaのファイル保存 |
| T04 | 同初期状態、ジャンプ3tickで離す／16tick保持 | apex差40px以上 | factory.tick | モデル |
| T05 | 運搬の有無で移動ジャンプ | 運搬時速度・ジャンプが弱い | interact_cargo/tick | モデル |
| T06 | 穴の下に境界fixture、2tick | 正常は死亡1・復帰1、B01はsoftlock | die/respawn | モデルの注入比較 |
| T07 | 所持死亡直後ポーズ→再開 | pending1回、正常荷物復元、B02消失 | die/respawn | モデルの注入比較 |
| T08 | 同tick死亡＋ゴールfixture | 正常は死亡のみ、B03は配送も記録 | resolve_contacts | モデルの注入比較 |
| T09 | 移動床に接地、1tick進行 | 相対位置維持 | factory.tick | モデル |
| T10 | 着地1tick前にジャンプ押下 | 先行入力で次tick跳ぶ | buffer/coyote | モデル |
| T11 | ステージ2コンベア上で無入力 | ベルト方向に動く | factory.tick | モデル |
| T12/E06 | 通常開始→取得→3回ジャンプ→プレス待機→配送、3区間 | 配送3、死亡0、結果画面 | main/game input + factory | モデル／将来Playtest（未実行） |
| T13/E07 | 結果から再プレイ | stage0、配送0、プレイ | replay | モデル／外部Gua |
| E01 | EXEへ接続しversion/Observe購読 | core/runtime/plugin1.1.2、追加状態18件以上available | 正式addon + observe owner | 将来Playtest（未実行）。固定UI部分はsource回帰 |
| E02/E03 | 通常入力map読取→startクリック | move/jump/interactとplay遷移 | main.setup_gua/show_menu | 将来Playtest（未実行）。固定UI部分はsource回帰 |
| E08 | 通常移動と荷物取得で穴に落下、正常/B01/B02を個別比較 | 死亡1、正常復帰、B01停止、B02荷物消失 | die/respawn | source固定回帰／将来Playtest EXE（未実行） |
| E09 | EXE終了→別プロセス起動→ロード | 保存tick/位置/seed/所持/進行一致、paused | main.load_game | source固定回帰／将来Playtest EXE（未実行） |
| E10 | 3区間通常移動し、最終ゲートの危険開始tickに配送口へ入る | 正常死亡のみ、B03だけ死亡+配送 | resolve_contacts | source固定回帰／将来Playtest EXE（未実行） |
| R01 | 仮想時計なしの通常EXE、同じ目的で移動取得ジャンプ配送 | 120秒以内に配送3・死亡0、実時間とtickを別記録 | 全体 | 将来Playtest（未実行）。120秒は旧試験上限 |
| U01–04 | 日英メニュー寸法・保存復元・設定再初期化・不正ファイル | viewport内に収まる、復元/永続化/未適用 | main | 正式C# source回帰、画像検証とは別 |
| V01 | 日英、3画面サイズでタイトル・ポーズ・プレイ・結果を目視 | 欠け・重なり・誤表示なし | main UI/font/stretch | 画像と実機が必要 |
| V02 | 人間が開始→通常操作で配送→再プレイ | 入力・難度が実時間で成立 | 全体 | 人間操作が必要 |
| X01 | 「荷物を置き穴へ落ちる、救出して再配送」を探索 | 荷物・所持整合、復帰可能 | interact_cargo/respawn | 将来Playtest（未実行） |
| X02 | 通常移動で足場を離れ2/8tick後にジャンプを入力 | 2tickは猶予内ジャンプ、8tickは空中ジャンプ不可 | tick/coyote | 正式C# source回帰。EXEの既存結果は履歴のみ |
| X03 | 通常移動で落下死亡、次tick前にポーズ→60tick→再開 | 停止中は復帰予約維持、再開で復帰1回、二重死亡なし | tick/die/respawn | 正式C# source回帰。EXEの既存結果は履歴のみ |

固定ステップはエージェントの実時間判断速度を測定しない。状態値判定の自動結果は画像・音・人間の操作感を保証しない。Windows EXE の検証結果がないケースはモデルの成功をそのまま昇格しない。
