-- Chat tabs: one per guild, alongside the normal chat tab.
--
-- PROBE ONLY at this stage. Nothing here runs unless /pbchat tabprobe is typed.
--
-- The parts all exist and are shared rather than keyboard-only: SharedChatContainer:AddWindow
-- creates a tab, HandleTabClick switches to one, SetWindowFilterEnabled routes a category to a
-- tab, and ZO_ChatWindowTabTemplate lives in the shared XML so console has it too. The note in
-- gamepadchatsystem.lua about not wanting more chat containers on console is about containers,
-- not about tabs inside one.
--
-- What is not known is whether an add-on may call AddWindow at all. It is client code that builds
-- UI out of control pools, and client closures created while an add-on frame is on the stack come
-- out permanently untrusted -- which would leave a tab that exists and cannot be clicked, or whose
-- category settings cannot be saved. That is worth one deliberate attempt with a report, not a
-- whole feature written blind.
if not PBS_CHAT_ASSISTANT then
	return
end

local addon = PBS_CHAT_ASSISTANT
local tabs = {}
addon.chatTabs = tabs

local function Print(formatString, ...)
	d(string.format("|cFF69B4PB's ChatAssistant|r: " .. formatString, ...))
end

local function GetContainer()
	local chat = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
	return chat and chat.primaryContainer, chat
end

-- Guild categories, paired with the officer channel of the same guild. Built rather than
-- declared: a table constructor with a nil key raises at load.
local function GuildCategoryPairs()
	local pairsList = {}
	local guild = { CHAT_CATEGORY_GUILD_1, CHAT_CATEGORY_GUILD_2, CHAT_CATEGORY_GUILD_3,
		CHAT_CATEGORY_GUILD_4, CHAT_CATEGORY_GUILD_5 }
	local officer = { CHAT_CATEGORY_OFFICER_1, CHAT_CATEGORY_OFFICER_2, CHAT_CATEGORY_OFFICER_3,
		CHAT_CATEGORY_OFFICER_4, CHAT_CATEGORY_OFFICER_5 }
	for index = 1, 5 do
		if guild[index] then
			pairsList[index] = { guild = guild[index], officer = officer[index] }
		end
	end
	return pairsList
end

-- Read-only. Safe to run at any time.
function tabs:PrintStatus()
	local container, chat = GetContainer()
	if not container then
		Print("no chat container")
		return
	end

	local containerId = container.id
	local numTabs = type(GetNumChatContainerTabs) == "function" and GetNumChatContainerTabs(containerId)
	Print("container %s, tabs %s (windows %d), categories %s",
		tostring(containerId), tostring(numTabs), #container.windows,
		tostring(type(GetNumChatCategories) == "function" and GetNumChatCategories()))

	Print("guilds: %d", GetNumGuilds and GetNumGuilds() or -1)

	for index, pair in ipairs(GuildCategoryPairs()) do
		local guildId = GetGuildId and GetGuildId(index)
		local name = guildId and GetGuildName and GetGuildName(guildId)
		local enabled = {}
		for tabIndex = 1, (#container.windows) do
			if type(IsChatContainerTabCategoryEnabled) == "function"
				and IsChatContainerTabCategoryEnabled(containerId, tabIndex, pair.guild) then
				enabled[#enabled + 1] = tostring(tabIndex)
			end
		end
		Print("  guild %d %s: category %s on tab(s) %s", index, tostring(name or "-"),
			tostring(pair.guild), #enabled > 0 and table.concat(enabled, ",") or "none")
	end
end

-- The one deliberate attempt. Adds a single tab and reports what came back.
--
-- Reversible with /pbchat tabprobe remove, and it refuses to run twice so a mistyped command
-- cannot fill the container with tabs.
function tabs:AddProbeTab()
	local container = GetContainer()
	if not container then
		Print("no chat container")
		return
	end

	if self.probeTabIndex then
		Print("probe tab already added at %d -- /pbchat tabprobe remove first", self.probeTabIndex)
		return
	end

	local before = #container.windows
	Print("adding a tab, windows before: %d", before)

	local window = container:AddWindow("PBprobe")
	local after = #container.windows

	if not window or after <= before then
		Print("AddWindow returned nothing; windows still %d", after)
		return
	end

	self.probeTabIndex = after
	self.probeWindow = window
	Print("tab added at %d, name %s, tab control %s", after,
		tostring(container:GetTabName(after)), tostring(window.tab ~= nil))
	Print("now try: click it with the pad, then /pbchat tabprobe status")
end

function tabs:RemoveProbeTab()
	local container = GetContainer()
	if not container or not self.probeTabIndex then
		Print("no probe tab to remove")
		return
	end

	local index = self.probeTabIndex
	self.probeTabIndex = nil
	self.probeWindow = nil
	container:RemoveWindow(index)
	Print("removed tab %d, windows now %d", index, #container.windows)
end

-- Switches to a tab by index, which is the other half of the feature and is worth measuring in
-- the same round: a tab that cannot be selected from Lua is no use for L2 + D-pad Right.
function tabs:SelectTab(index)
	local container = GetContainer()
	if not container or not container.windows[index] then
		Print("no tab %s", tostring(index))
		return
	end

	local window = container.windows[index]
	if container.tabGroup and window.tab then
		container.tabGroup:SetClickedButton(window.tab)
	end
	container:HandleTabClick(window.tab)
	Print("selected tab %d (%s)", index, tostring(container:GetTabName(index)))
end
