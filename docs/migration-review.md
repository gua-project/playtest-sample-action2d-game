# テスト責務移行の独立レビュー（別枠1回）

2026-10-29。初回ゲーム実装レビュー1回とは別に、移行差分 `a40816f..42d797a` を独立read-only reviewerが1回確認した。正式GitHub Approve・GUI・追加ゲーム探索は行っていない。以下は同じレビューの指摘と修正確認であり、初回回数をリセットした扱いでも、追加の全面監査でもない。

| 指摘 | 欠落していた期待値 | 修正 |
|---|---|---|
| MR01 / P2 | 再起動後が既定ja/0なのでload_settingsのno-opを検出できない | UIで非既定en/size1を保存、source再起動後の英語Start表示と、通常Start/Pause/Saveが生成したpayloadのlocale/sizeを検証 |
| MR02 / P2 | 旧E01の各version、E02のaction exact3件とid/typeの明示assertが縮小 | 正式GuaVersionのCoreVersion/RuntimeVersion/GodotPluginVersion各1.1.2、標準mapのexact3 actionとid/valueTypeをassert。rangeは旧版にも明示assertなし |
| MR03 / P2 | 旧E09のframe/stage/seed/deaths/deliveries/carrying/checkpoint比較がframe/positionへ縮小 | Save前の独立Observe snapshotを保持し、旧7キー＋bugsとposition/pausedを同一sourceとsource再起動の両方で比較。明示非既定fixtureから通常Saveする追加回帰も用意 |

MR03追加回帰の初期条件はseed112、stage2、deliveries2、deaths3、carrying/checkpoint=true、B03のみ、frame128。Loadで初期状態を検証後、準備用保存ファイルを削除し通常UIのSaveで再生成する。Reset/Startで進行を変更してからLoadし、source再起動後のLoadとも比較する。fixture準備はsource回帰の初期条件であり、通常3区間走破や配布EXE/Playtest E2Eの成功証拠にはしない。

レビューでは、正式API/CIの構造的な誤用、専用clear/setter、Playtest未実行の成功扱い、EXE smokeのrunner肥大は見つからなかった。新たなAPI制約を独自wireやrunnerで埋めていない。修正確認と実行結果はPR本文およびvalidation.mdに記録する。

残余リスク: GUI画像・実サイズ・ネイティブ入力、Playtest E2E、更新なしの長時間保持入力契約は未検証。今回のレビューやsource回帰はこれらを保証しない。
