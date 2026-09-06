local strings = {
	SI_KEYBINDINGS_CATEGORY_PBSCHATASSISTANT = "PB’s ChatAssistant",
	SI_BINDING_NAME_PBSCHATASSISTANT_START_CHAT = "Open Chat",
	SI_BINDING_NAME_PBSCHATASSISTANT_CHANNEL_NEXT = "Next Chat Channel",
	SI_BINDING_NAME_PBSCHATASSISTANT_CHANNEL_PREV = "Previous Chat Channel",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
