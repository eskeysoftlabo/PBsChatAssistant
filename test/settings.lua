-- Run from the add-on directory: lua test/settings.lua
local stringIds = {
	"DEFAULT_CHANNEL", "DEFAULT_CHANNEL_NONE", "DEFAULT_CHANNEL_TOOLTIP", "DELAY",
	"DELAY_TOOLTIP", "GUILDINMAIN", "GUILDINMAIN_TOOLTIP", "GUILDTABS",
	"GUILDTABS_TOOLTIP", "GUILD_EMPTY", "HUDCHANNEL", "HUDCHANNEL_TOOLTIP",
	"NPC", "NPC_NOTE", "NPC_SECTION", "NPC_TOOLTIP",
	"RECRUIT", "RECRUIT_NOTE", "RECRUIT_SECTION", "RECRUIT_TOOLTIP",
	"RECRUIT_WHISPER", "RECRUIT_WHISPER_TOOLTIP",
	"TABSTRIP_POS_TOOLTIP", "TABSTRIP_X", "TABSTRIP_Y", "TAB_LAYER",
	"TAB_LAYER_BACKGROUND", "TAB_LAYER_CONTROLS", "TAB_LAYER_OVERLAY", "TAB_LAYER_TEXT",
	"TAB_LAYER_TOOLTIP", "TAB_TEXT_SIZE", "TAB_TEXT_SIZE_TOOLTIP", "TAB_VISIBLE",
	"TAB_VISIBLE_TOOLTIP",
}
for _, suffix in ipairs(stringIds) do
	_G["SI_PBSCHATASSISTANT_" .. suffix] = suffix
end

function GetString(id)
	if id == SI_PBSCHATASSISTANT_GUILDINMAIN then
		return "通常チャットに表示: <<1>>"
	end
	return id
end

function zo_strformat(template, value)
	return (template:gsub("<<1>>", value))
end

function ZO_ClearNumericallyIndexedTable(items)
	for index = #items, 1, -1 do
		items[index] = nil
	end
end

local definitions = {}
local panel = {}
function panel:AddSetting(definition)
	definitions[#definitions + 1] = definition
end

LibHarvensAddonSettings = {
	ST_CHECKBOX = "checkbox",
	ST_DROPDOWN = "dropdown",
	ST_LABEL = "label",
	ST_SECTION = "section",
	ST_SLIDER = "slider",
	AddAddon = function()
		return panel
	end,
}

CALLBACK_MANAGER = { RegisterCallback = function() end }

local writes = {}
local refreshes = 0
PBS_CHAT_ASSISTANT = {
	title = "PB's ChatAssistant test",
	author = "test",
	version = "test",
	sv = {
		hudChannelEnabled = true,
		guildTabsEnabled = true,
		tabStripX = 0,
		tabStripY = 110,
		tabTextSize = 28,
		tabTextLayer = "text",
		tabNameVisible = true,
		recruitFilterEnabled = false,
		recruitFilterWhispers = false,
		npcChatFilterEnabled = false,
		defaultChannel = 0,
		delayMs = 100,
	},
	chatTabs = {
		GuildSlots = function()
			return {
				{ index = 1, guildId = 101, name = "一番ギルド" },
				{ index = 2, guildId = 202, name = "Second Guild" },
			}
		end,
		IsGuildInMainTab = function(_, guildId)
			return guildId == 101
		end,
		SetGuildInMainTab = function(_, guildId, value)
			writes[#writes + 1] = { guildId = guildId, value = value }
		end,
		RefreshStrip = function()
			refreshes = refreshes + 1
		end,
	},
	GetSelectableChannels = function()
		return {}
	end,
	GetChannelDisplayName = function(_, channelId)
		return tostring(channelId)
	end,
	ApplyDefaultChannel = function() end,
}

dofile("Settings.lua")
PBS_CHAT_ASSISTANT:InitSettings()

local guildRows = {}
for _, definition in ipairs(definitions) do
	if definition.label and definition.label:find("通常チャットに表示:", 1, true) then
		guildRows[#guildRows + 1] = definition
	end
end

assert(#guildRows == 2, "settings must contain one row per joined guild")
assert(guildRows[1].label == "通常チャットに表示: 一番ギルド")
assert(guildRows[2].label == "通常チャットに表示: Second Guild")
assert(guildRows[1].getFunction() == true)
assert(guildRows[2].getFunction() == false)

guildRows[1].setFunction(false)
guildRows[2].setFunction(true)
assert(writes[1].guildId == 101 and writes[1].value == false)
assert(writes[2].guildId == 202 and writes[2].value == true)

local visibleRow
for _, definition in ipairs(definitions) do
	if definition.label == SI_PBSCHATASSISTANT_TAB_VISIBLE then
		visibleRow = definition
	end
end
assert(visibleRow and visibleRow.getFunction() == true)
visibleRow.setFunction(false)
assert(PBS_CHAT_ASSISTANT.sv.tabNameVisible == false and refreshes == 1)

local recruitRow, whisperRow
local npcRow
for _, definition in ipairs(definitions) do
	if definition.label == SI_PBSCHATASSISTANT_RECRUIT then
		recruitRow = definition
	elseif definition.label == SI_PBSCHATASSISTANT_RECRUIT_WHISPER then
		whisperRow = definition
	elseif definition.label == SI_PBSCHATASSISTANT_NPC then
		npcRow = definition
	end
end
assert(recruitRow and whisperRow and npcRow)
recruitRow.setFunction(true)
whisperRow.setFunction(true)
assert(PBS_CHAT_ASSISTANT.sv.recruitFilterEnabled == true)
assert(PBS_CHAT_ASSISTANT.sv.recruitFilterWhispers == true)
npcRow.setFunction(true)
assert(PBS_CHAT_ASSISTANT.sv.npcChatFilterEnabled == true)
assert(definitions[#definitions - 6].label == SI_PBSCHATASSISTANT_RECRUIT_SECTION)
assert(definitions[#definitions - 5].label == SI_PBSCHATASSISTANT_RECRUIT_NOTE)
assert(definitions[#definitions - 4] == recruitRow)
assert(definitions[#definitions - 3] == whisperRow)
assert(definitions[#definitions - 2].label == SI_PBSCHATASSISTANT_NPC_SECTION)
assert(definitions[#definitions - 1].label == SI_PBSCHATASSISTANT_NPC_NOTE)
assert(definitions[#definitions] == npcRow)

print("PASS settings show actual joined-guild names and retain their guild IDs")
print("PASS active-tab text setting hides the label and refreshes it immediately")
print("PASS recruitment and NPC filters form the final sections of the panel")
