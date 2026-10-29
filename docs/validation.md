# 実行記録

## 2026-10-29 責務分担変更

ゲームコード・Godot4.7・Gua1.1.2は変更せず、旧JS外部EXE runnerを退役。正式Gua.Testing/Gua.Testing.Godotのsource scene回帰、内部モデル回帰、起動だけの配布smokeへ整理した。現行結果はこの節に記録する。下記のEXE操作結果とCIは移行前の履歴であり、Playtest E2Eの成功ではない。Playtest側の統合は未実行。GUI承認未完了も維持する。独立レビュー既存1回は移行前のもので、今回の変更を独立監査済みとはしない。

- 正式 NuGet 1.1.2 を locked restore、.NET 10でコンパイル。source scene回帰12件成功・失敗0・skip0。TRX: `output/source-regression-results/20261029T114026873/source-regression.trx`。各ケースに公式Observe/World/Diagnostics JSONと明示保存fixtureを添付。
- import（既存拡張cacheも一時分離）、内部モデル32assert、source起動smoke成功。移行前のGDScript直接UI統合10assertは正式C#へ移したため現在の件数に加算しない。
- 正式guarded UI/入力の完了をpollし、clockはSDKの `RunClockForAsync` を利用。観測待機は要求前のUI/Worldフレームを基準にする。連続移動は各固定ステップで同じSDK所有入力を更新する。更新なしで短い時計要求を反復する初期試行ではSDKのhost completion timeoutが発生したため、この更新なしの長時間保持契約は未検証として残す。独自wireへのフォールバック、SDK/addon改変はしていない。
- B01はsoftlockにより荷物も復帰しないため、cargo位置の復元は正常版だけへ要求する。B02はcargo_lost、B03は同tickの死亡と配送の増加を個別期待値として判定。
- 既存配布EXEの起動・読込・正常終了だけのsmoke成功（`output/distribution-smoke/20261029T113233342/`）。新CI初回はgua-testerの通常Windows engine EXEをPowerShellが待たず、import exit code未取得で失敗（run40807039810）。PowerShellのimport/exportだけ同じ公式archive内のconsole EXEへ変更し、source hostの通常EXEは維持した。同HEAD eb8dcbb のPR run40807308595は全step成功したが、push run40807303665はロード時のstale_guardで失敗した。後者も成功扱いせず、要求前に拒否されたstale_guardだけ、同epochでLocatorと最新UIを再検証する上限2回の再観測に修正。enqueue済み・不確実・timeoutの操作は再送しない。最終結果はPR checksと本文を参照。配布EXEの操作/探索/再起動/Trace/ReplayはこのCIの対象外、Playtest E2Eは未実行。
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

## 最終ローカルEXE証拠

最終ゲームソースのEXE SHA256: `379fe8cdc69180e684cdea1fb10f7ada34bb0455dd11973eecc7bda2c7853263`。

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
- 2026-10-29、ユーザーの明示承認に基づき、空tree `4b825dc642cb6eb9a060e54bf8d69288fbee4904` の既存ancestor `fb8c288620bb84facfd1dd6e43209809f2a63e94` だけをmainへ初期push。mainを既定ブランチに設定。ゲームコードのmainへのマージ、force push、自動マージ、Release公開は行っていない。
- main向けDraft PRは当初、自動承認レビューで本人の明示承認不足として実行前に拒否された。ユーザー本人の「2Dアクションと3Dの実装ブランチのpush・Draft PR作成を許可します」という具体的承認を確認後、remoteに重複PRがないことを確認し、[Draft PR #2](https://github.com/gua-project/playtest-sample-action2d-game/pull/2) を作成。GUI未検証・既知のeditor条件を本文へ明記した。正式Approve、実装マージ、自動マージ、Release公開は未実施。

初期の `output/exe-fixed/` は試行で上書きされたため、全初期失敗のraw保持は主張しない。以後は `output/runs/<timestamp>-exe` と `-source` に分離し、EXE SHA256・source hash・実行時commitを対応付ける。実プロセス接続の初期失敗は、自分の初期ホストとのポート競合を解消した後に復旧。未検証・エラーを成功に数えない。
