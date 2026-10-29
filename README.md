# 配送ロボットの工場

Godot **4.7 stable** / **Windows x64 限定** / 正式 **Gua 1.1.2**。issue [#1](https://github.com/gua-project/playtest-sample-action2d-game/issues/1) のアクション QA サンプルです。仮素材で実装しています。

荷物を拾い、足場とプレスを越え、緑の配送口へ届けます。基本移動、コンベアを含む運搬、配送口と危険ゲートが近接する複合障害の3ステージです。

## 起動と操作

`DeliveryFactory-windows.zip` を**フォルダごと展開**し、`DeliveryFactory.exe` を実行してください。Gua の DLL とライセンスも同梱されるため EXE だけを別フォルダへ移動しないでください。

| 操作 | キー |
|---|---|
| 左右移動 | A/D または ←/→ |
| ジャンプ | Space（長押しで高く、離すと上昇を抑える） |
| 近くの荷物の取得／設置 | E（押した瞬間） |
| ポーズ／再開・設定・保存 | Esc または右上の Ⅱ |

タイトルの「配送を開始」から開始します。荷物を配送口へ運ぶと次のステージへ進み、3回配送すると結果画面です。「もう一度プレイ」で同じ seed とバグ設定の新しい周回を開始します。初期状態へのリセットはタイトルに戻ります。seed と個別バグはタイトルで設定できます。通常版のバグ設定はすべて OFF です。

荷物運搬中は移動とジャンプが弱まります。穴を越える足場は上から着地できます。旗を通過して接地するとチェックポイントが確定します。プレスの赤表示と配送口脇の赤ゲートが危険な時間です。停止して安全な周期を待ちましょう。

## 保存・設定

ポーズ中にセーブ／ロードできます。物理 tick、位置・速度、荷物、チェックポイント、進行、死亡回数、seed、バグ設定、直前入力を保存し、プレイ状態のロード後は一時停止します。ロード前のデータ検証に失敗したら変更しません。保存は一時ファイルから置換します。

日本語／英語と 960×600・1152×720・1440×900 を選択できます。設定は次回起動に持ち越します。標準保存先は `%APPDATA%/GuaAction2DFactory`、検証では `FACTORY_SAVE_DIR` に担当専用ディレクトリを指定します。UI は 1152×720 を基準にスケールします。日本語フォント M PLUS 1p は SIL OFL 同梱です。

## 開発・ビルド

既存 Godot 4.7 と同版の Windows export template、PowerShell 7、.NET 10 SDK を使用します。ゲームは GDScript のままです。Node.js と自作 JS wire client は現在のテストには使いません。依存キャッシュ・保存先・出力は checkout 内へ分離します。

```powershell
./scripts/install-gua.ps1
./scripts/verify.ps1
./scripts/run-source-tests.ps1 -Restore # 正式C# APIでsource sceneの固定回帰
./scripts/build-windows.ps1
./scripts/run-exe-smoke.ps1             # 配布物の起動・リソース読込だけ
```

`build/windows/` が配布フォルダ、`build/DeliveryFactory-windows.zip` が配布 ZIP、`output/build-sha256.txt` に EXE の SHA256 を出力します。テンプレートが既定場所にない場合、`build-windows.ps1 -TemplateDirectory <既存テンプレートフォルダ>` を使用します。CI では同じ公式 Godot のハッシュ検証済み配布を専用 runner に取得します。

`verify.ps1` は import、32項目の内部モデル検証、source起動 smoke を行います。これはGua UI/E2Eの証拠とは別です。`run-source-tests.ps1` は正式 NuGet **Gua.Testing.Godot 1.1.2 / Gua.Testing 1.1.2** と NUnit を使用します。`GodotSceneTestHost` で `res://main.tscn` を起動し、正式 Locator/guarded UI・入力、Observe、World、仮想時計で開始・保存復元・境界・個別バグ・結果からの再プレイを確認します。TRXと公式APIのJSON添付は `output/source-regression-results/` と `output/source-regression/` へ保存します。source sceneの検証であり、配布EXEの受入とは呼びません。

`run-exe-smoke.ps1` はEXEがリソース/DLLを読み込んで起動マーカーに達し、エラーログなく終了することだけを確認します。操作、探索、目標判定、外部接続の保証、Playtestの合格判定は行いません。

CIは [gua-tester](https://github.com/gua-project/gua-tester) の `setup-godot` と `link-gua-gdscript-addon`（v3.2 commit固定）を使い、Godot4.7/Gua1.1.2を固定します。単体回帰、正式C# source回帰、export、限定配布smokeを別stepにします。Windows hosted editor終了時のnative拡張クラッシュ対策として、importだけ拡張ロードを分離し、exportには公式recovery modeを使用します。source回帰では正式Guaを有効に戻します。

## Playtest との分担

このサンプルはゲーム本体と再現条件・独立した期待値を提供します。配布EXEの launch/attach、Scenario/Environment、探索、予算・中断・cleanup、Trace/Recording/Replay、製品としてのRun/Resultは **Gua Playtest側** の責務です。このrepoにはその代替Runnerを追加しません。Playtest未完成部分を独自実装で埋めず、未実行E2Eとして残します。

[テスト責務と判定契約](docs/test-ownership.md) と [Playtest接続情報・独立期待値](docs/playtest-handoff.md) を参照してください。過去のEXE試行は [検証記録](docs/validation.md) に分離し、現在のsource回帰やPlaytest E2Eの成功とは区別します。

## Gua 接続と時間

ブリッジは専用 `ws://127.0.0.1:18241`（`GUA_BRIDGE_PORT` で変更可能）。同時実行はポート・保存先を分離してください。通常起動では実時間を固定60Hzの accumulator に反映し、1描画で最大0.1秒を処理します。大きな描画停止による負荷連鎖を抑えるため、実時間と simulation tick は同一とは限りません。

`DeliveryFactory.exe -- --fixed-clock` は Gua virtual clock を停止状態で導入し、標準 `clock_run_for` で60Hzの同じゲーム処理を進めます。UI は停止中も動きます。ポーズは物理・コンベア・プレス周期・死亡からの復帰を停止します。入力リースは Gua の実時間で管理され、仮想時計とは別です。

標準 Semantic UI でメニュー、標準 Game Input の `move`（axis1d）、`jump`、`interact` で通常プレイを操作します。World Tree の `robot` / `cargo` / `platform` / `press` / `goal` / `checkpoint` に標準位置を発行します。追加状態は正式 Observe の world owner で登録し、独自の公開範囲判定や「クリア」API は実装していません。Observe は既定の Debug 登録です。Player 公開・非公開の判断は Gua の既存プロトコルに従います。

テストは正式SDKが返す相関済み完了を待ち、その完了後のUI・World・Observe公開とavailable状態を揃えてから判定します。Observeの利用不能やtimeoutを成功に読み替えません。C#のTimeSpanが100ns精度のため、source回帰の時計stepは1/60秒を上へ丸めた16.6667msです。物理処理はゲーム側の固定60Hzだけで実行します。

## 検証範囲

[テスト一覧・要件対応](docs/test-matrix.md)、[実装判断と既知バグ](docs/design.md)、[実行結果](docs/validation.md) を参照してください。未実施の EXE・画像・探索・人間操作検証をモデルテストの成功で代用しません。音は仮素材段階では実装していないため、音による判断・音質は対象外です。3本のサンプルでゲーム QA 全般の網羅は主張しません。
