local strings = {
	SI_BINDING_NAME_PBSCHATASSISTANT_START_CHAT = "チャットを開く",
	SI_BINDING_NAME_PBSCHATASSISTANT_CHANNEL_NEXT = "次のチャンネル",
	SI_BINDING_NAME_PBSCHATASSISTANT_CHANNEL_PREV = "前のチャンネル",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
