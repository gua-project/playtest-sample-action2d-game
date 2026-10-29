# 実行記録

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
- main向けDraft PRの作成は自動承認レビューで実行前に拒否された。「ユーザー承認は空のmain初期化に限定され、PR作成の明示承認がない」という理由。PRは未作成、別経路の再試行なし。作成内容は `output/pr-body.md` に準備済みで、親側に明示承認の確認を依頼中。

初期の `output/exe-fixed/` は試行で上書きされたため、全初期失敗のraw保持は主張しない。以後は `output/runs/<timestamp>-exe` と `-source` に分離し、EXE SHA256・source hash・実行時commitを対応付ける。実プロセス接続の初期失敗は、自分の初期ホストとのポート競合を解消した後に復旧。セキュリティ設定は変更していない。未検証・エラーを成功に数えない。
