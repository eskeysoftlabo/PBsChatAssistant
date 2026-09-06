local strings = {
	SI_KEYBINDINGS_CATEGORY_PBSCHATASSISTANT = "PB’s ChatAssistant",
	SI_BINDING_NAME_PBSCHATASSISTANT_START_CHAT = "Open Chat",
	SI_BINDING_NAME_PBSCHATASSISTANT_CHANNEL_NEXT = "Next Chat Channel",
	SI_BINDING_NAME_PBSCHATASSISTANT_CHANNEL_PREV = "Previous Chat Channel",

	SI_PBSCHATASSISTANT_ENABLED = "Enabled",
	SI_PBSCHATASSISTANT_ENABLED_TOOLTIP = "Master switch. Turn this off and the add-on does nothing at all.",
	SI_PBSCHATASSISTANT_DELAY = "Wait before opening",
	SI_PBSCHATASSISTANT_DELAY_TOOLTIP = "The console raises its text input screen only when the chat box takes focus fresh, so the box is opened after a short pause rather than instantly. If the box opens but the input screen does not follow, this is too short for your console: raise it.",
	SI_PBSCHATASSISTANT_ENTER = "Open chat with Enter",
	SI_PBSCHATASSISTANT_ENTER_TOOLTIP = "Listening for the Enter key needs keyboard focus, and while it is held the controller's buttons are paused. The sticks keep working, and the add-on stands down by itself as soon as the input screen appears. Leave this off and open the chat window from the controller as usual -- the input screen still comes up.",
	SI_PBSCHATASSISTANT_AUTOSAFE = "Release the keyboard once chat opens",
	SI_PBSCHATASSISTANT_AUTOSAFE_TOOLTIP = "Give the controller's buttons back the moment the input screen appears, instead of holding the keyboard for the whole session. Turn this off for a long stretch of typing where the controller is not wanted anyway.",
	SI_PBSCHATASSISTANT_CHANNEL_KEYS = "Left and right change channel",
	SI_PBSCHATASSISTANT_CHANNEL_KEYS_TOOLTIP = "While Enter is armed and the chat box is closed, the arrow keys walk the channel your next message goes to. Inside an open box they move the text cursor instead. A controller button bound under Controls does the same thing with nothing armed.",
	SI_PBSCHATASSISTANT_WATCH = "Raise the input screen automatically",
	SI_PBSCHATASSISTANT_WATCH_TOOLTIP = "Watch for a chat box that has focus but no input screen, and give it one. This is what makes the console's keyboard appear for a chat window opened any way at all, the controller included. Turning it off leaves only the game's own behaviour.",
	SI_PBSCHATASSISTANT_LOG = "Log to chat",
	SI_PBSCHATASSISTANT_LOG_TOOLTIP = "Print what the add-on is doing -- keys seen, opens, channel changes. For diagnosing a problem, not for everyday use.",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
