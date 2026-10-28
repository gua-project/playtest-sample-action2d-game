# 実行記録

2026-10-28。作業ブランチ `feat/delivery-factory`。提出commitは後で記録する。

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

## 未完了・ブロッカー

- 最終のメニュー寿命修正後EXEは再検証中。最新buildとrun/hashの対応は `output/runs/` の各JSONに記録。
- GUI対象 `Delivery Robot Factory` のウィンドウ発見・起動まで実施。画面取得のアプリ承認が `Computer Use app approval timed out`。GUI入力は実行されず、対象PIDとパスを照合して終了、枠解放済み。画像／人間のキー入力・操作感・各実サイズの実表示は未検証。承認を迂回していない。音は未実装。
- 外部Guaの同tickプレス境界と設置後落下は確認済み。足場端や着地直前の広範なタイミング探索、死亡とポーズの外部同時入力は未実施（モデルに代表ケースあり）。
- CI と push は準備中。
- リモートは空リポジトリでmain/base commitなし。main bootstrap pushは制約に従い未実施。比較元がないためDraft PRはまだ作成不能。

初期の `output/exe-fixed/` は試行で上書きされたため、全初期失敗のraw保持は主張しない。以後は `output/runs/<timestamp>-exe` と `-source` に分離し、EXE SHA256・source hash・実行時commitを対応付ける。実プロセス接続の初期失敗は、自分の初期ホストとのポート競合を解消した後に復旧。セキュリティ設定は変更していない。未検証・エラーを成功に数えない。
