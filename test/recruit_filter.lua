-- Run from the add-on directory: lua test/recruit_filter.lua
EVENT_CHAT_MESSAGE_CHANNEL = 100
GUILD_LINK_TYPE = "guild"

CHAT_CHANNEL_ZONE = 1
CHAT_CHANNEL_SAY = 2
CHAT_CHANNEL_YELL = 3
CHAT_CHANNEL_WHISPER = 4
CHAT_CHANNEL_WHISPER_SENT = 5
CHAT_CHANNEL_GUILD_1 = 11
CHAT_CHANNEL_OFFICER_1 = 21
CHAT_CHANNEL_MONSTER_SAY = 31
CHAT_CHANNEL_MONSTER_YELL = 32
CHAT_CHANNEL_MONSTER_WHISPER = 33
CHAT_CHANNEL_MONSTER_EMOTE = 34

function GetDisplayName()
	return "@Me"
end

function GetUnitName(unit)
	assert(unit == "player")
	return "My Character"
end

local originalCalls = 0
local formatters = {
	[EVENT_CHAT_MESSAGE_CHANNEL] = function(channel, fromName, text, isCustomerService,
		fromDisplayName, extra)
		originalCalls = originalCalls + 1
		return channel, fromName, text, isCustomerService, fromDisplayName, extra
	end,
}

CHAT_ROUTER = {}
function CHAT_ROUTER:GetRegisteredMessageFormatters()
	return formatters
end
function CHAT_ROUTER:RegisterMessageFormatter(event, formatter)
	formatters[event] = formatter
end

PBS_CHAT_ASSISTANT = {
	sv = {
		enabled = true,
		recruitFilterEnabled = false,
		recruitFilterWhispers = false,
		npcChatFilterEnabled = false,
	},
}

dofile("RecruitFilter.lua")
local addon = PBS_CHAT_ASSISTANT
assert(addon:InstallRecruitmentFilter())
assert(addon:InstallRecruitmentFilter(), "install must be idempotent")

local formatter = formatters[EVENT_CHAT_MESSAGE_CHANNEL]
local guildLink = "Join us |H1:guild:12345|h[Example Guild]|h today"
local itemLink = "WTS |H1:item:54321:0:0|h[Nirncrux]|h"

local function shown(channel, text, fromName, fromDisplayName)
	return formatter(channel, fromName or "Someone", text, false,
		fromDisplayName or "@Someone", "future argument") ~= nil
end

assert(shown(CHAT_CHANNEL_ZONE, guildLink), "filter is off by default")
assert(shown(CHAT_CHANNEL_MONSTER_SAY, "Move along"), "NPC filter is off by default")

addon.sv.npcChatFilterEnabled = true
assert(not shown(CHAT_CHANNEL_MONSTER_SAY, "Move along"))
assert(not shown(CHAT_CHANNEL_MONSTER_YELL, "You will pay!"))
assert(not shown(CHAT_CHANNEL_MONSTER_WHISPER, "Come closer"))
assert(not shown(CHAT_CHANNEL_MONSTER_EMOTE, "The creature snarls"))
assert(shown(CHAT_CHANNEL_SAY, "player speech remains visible"))
addon.sv.npcChatFilterEnabled = false

addon.sv.recruitFilterEnabled = true
assert(not shown(CHAT_CHANNEL_ZONE, guildLink))
assert(not shown(CHAT_CHANNEL_SAY, guildLink))
assert(not shown(CHAT_CHANNEL_YELL, guildLink))
assert(shown(CHAT_CHANNEL_ZONE, "ordinary zone chat"))
assert(shown(CHAT_CHANNEL_ZONE, itemLink), "non-guild links must remain visible")
assert(shown(CHAT_CHANNEL_GUILD_1, guildLink), "guild chat is exempt")
assert(shown(CHAT_CHANNEL_OFFICER_1, guildLink), "officer chat is exempt")
assert(shown(CHAT_CHANNEL_WHISPER, guildLink), "whispers are exempt by default")

addon.sv.recruitFilterWhispers = true
assert(not shown(CHAT_CHANNEL_WHISPER, guildLink))
assert(not shown(CHAT_CHANNEL_WHISPER_SENT, guildLink))
assert(shown(CHAT_CHANNEL_ZONE, guildLink, "My Character", "@Me"),
	"the player's own messages must remain visible")

addon.sv.enabled = false
assert(shown(CHAT_CHANNEL_ZONE, guildLink), "the add-on master switch must bypass the filter")
assert(addon.hiddenRecruitment == 5)
assert(addon.hiddenNpcChat == 4)
assert(originalCalls > 0)

print("PASS recruitment adverts and NPC chat are filtered with ChatFilter exemptions")
