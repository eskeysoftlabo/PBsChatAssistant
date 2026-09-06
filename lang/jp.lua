local strings = {
	SI_BINDING_NAME_PBSCHATASSISTANT_START_CHAT = "チャットを開く",
	SI_BINDING_NAME_PBSCHATASSISTANT_CHANNEL_NEXT = "次のチャンネル",
	SI_BINDING_NAME_PBSCHATASSISTANT_CHANNEL_PREV = "前のチャンネル",

	SI_PBSCHATASSISTANT_ENABLED = "有効",
	SI_PBSCHATASSISTANT_ENABLED_TOOLTIP = "全体の切り替え。オフにするとアドオンは何もしません。",
	SI_PBSCHATASSISTANT_DELAY = "開くまでの待ち時間",
	SI_PBSCHATASSISTANT_DELAY_TOOLTIP = "本体の文字入力画面は、チャット欄が新たにフォーカスを得たときにのみ表示されます。そのため即座にではなく、少し待ってから開きます。チャット欄は開くのに入力画面が出ない場合、この値が短すぎます。",
	SI_PBSCHATASSISTANT_ENTER = "Enterでチャットを開く",
	SI_PBSCHATASSISTANT_ENTER_TOOLTIP = "Enterキーを読み取るにはキーボードのフォーカスが必要で、その間コントローラーのボタンが止まります。スティックは動きます。入力画面が出た時点で自動的に解除されます。オフのままでも、コントローラーでチャットを開けば入力画面は出ます。",
	SI_PBSCHATASSISTANT_AUTOSAFE = "チャットが開いたらキーボードを解放",
	SI_PBSCHATASSISTANT_AUTOSAFE_TOOLTIP = "入力画面が出た瞬間にコントローラーのボタンを戻します。長時間打ち続けてコントローラーが不要な場合はオフにしてください。",
	SI_PBSCHATASSISTANT_CHANNEL_KEYS = "左右キーでチャンネル変更",
	SI_PBSCHATASSISTANT_CHANNEL_KEYS_TOOLTIP = "Enterが有効で、かつチャット欄が閉じている間、左右キーで発言先チャンネルを切り替えます。開いた入力欄の中ではカーソル移動が優先されます。コントロールで割り当てたコントローラーのボタンなら、Enterの有効化なしで同じことができます。",
	SI_PBSCHATASSISTANT_WATCH = "入力画面を自動で出す",
	SI_PBSCHATASSISTANT_WATCH_TOOLTIP = "フォーカスがあるのに入力画面が出ていないチャット欄を検知して出します。コントローラーで開いた場合も含め、どの方法で開いても入力画面が出るのはこの機能によるものです。",
	SI_PBSCHATASSISTANT_LOG = "チャットにログを出力",
	SI_PBSCHATASSISTANT_LOG_TOOLTIP = "受け取ったキー、開いた記録、チャンネル変更を出力します。問題調査用で、通常は不要です。",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
