# PB’s ChatAssistant 1.8.3

ESOのHUDで、**L2＋L3（左スティック押し込み）**により投稿先チャンネルを順番に切り替えます。
チャット入力画面やスラッシュコマンドを開く必要はありません。

## 使い方

1. PBsChatAssistantとLibHarvensAddonSettings（20106以上）を有効にします。
2. HUD上でL2＋L3を押します。画面上部の「投稿先」に選択したチャンネルを表示します。
3. 次の切り替え前に両方のボタンを離してください。
4. 通常の方法でチャットを開いて入力します。

利用できるチャンネルだけが対象です。相手の指定が必要なウィスパーは含みません。
メニューや文字入力画面を閉じてHUDに戻ると、再び切り替えを使えます。

## 1.8.3の変更

- 120秒の検証制限を削除し、時間制限なく使用できるようにしました。
- 検証ログ、入力回数、押し込み量、残り時間などの診断表示を削除しました。
- L2の解放確認は10ms間隔を維持します。実際の頻度はゲームのフレーム更新にも依存します。
- エリア移動などのロード後も自動で再開します。
- HUDには現在の投稿先だけを表示します。

## チャット入力

既存の日本語入力画面を開くためのフォーカス監視機能は継続しています。
設定 → アドオン → PB’s ChatAssistantから、入力画面が開くまでの待ち時間を調整できます。

キーボードのEnter捕捉機能は従来どおり任意です。有効な間はコントローラー操作と競合するため、
HUDチャンネル切り替えは一時停止します。`/pbchat safe` で捕捉を解除すると再開します。
`/pbchat off` / `/pbchat on` でアドオンを停止・再開できます。

## 開発者向け

コンソール版で計測した挙動、およびドキュメントと実クライアントの食い違いは
[FINDINGS.md](FINDINGS.md) にまとめてあります。1.8.0でL2＋L3が実現できた理由と、
それ以前に「不可能」と結論づけていた誤りの経緯も記録しています。

## 更新・配布

バージョンは **1.8.3** です。別アドオンのPBsHUDChannelProbeは無効にしてください。
ZIP内のPBsChatAssistantフォルダを使用します。既存の保存設定を維持します。

著者：PinkBanther

This Add-On is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates.
The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc.
in the United States and/or other countries. All rights reserved.
