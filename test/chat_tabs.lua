-- Run from the add-on directory: lua test/chat_tabs.lua
local controls = {}

TOP, CT_LABEL = "top", "label"
TEXT_ALIGN_CENTER = "center"
DT_HIGH = "high"
DL_BACKGROUND, DL_CONTROLS, DL_TEXT, DL_OVERLAY = "background", "controls", "text", "overlay"
GuiRoot = {}

local function NewControl(name)
	local control = { name = name, hidden = false }
	function control:SetMouseEnabled(value) self.mouseEnabled = value end
	function control:SetAnchorFill() self.anchorFill = true end
	function control:SetHorizontalAlignment(value) self.horizontal = value end
	function control:SetVerticalAlignment(value) self.vertical = value end
	function control:SetDimensions(width, height) self.width, self.height = width, height end
	function control:ClearAnchors() self.anchor = nil end
	function control:SetAnchor(...) self.anchor = { ... } end
	function control:SetFont(value) self.font = value end
	function control:SetDrawTier(value) self.drawTier = value end
	function control:SetDrawLayer(value) self.drawLayer = value end
	function control:SetHidden(value) self.hidden = value end
	function control:IsHidden() return self.hidden end
	function control:SetText(value) self.text = value end
	function control:SetColor(...) self.colour = { ... } end
	controls[name] = control
	return control
end

WINDOW_MANAGER = {
	CreateTopLevelWindow = function(_, name) return NewControl(name) end,
	CreateControl = function(_, name) return NewControl(name) end,
}

CHAT_CATEGORY_GUILD_1, CHAT_CATEGORY_GUILD_2 = 11, 12
CHAT_CATEGORY_GUILD_3, CHAT_CATEGORY_GUILD_4, CHAT_CATEGORY_GUILD_5 = 13, 14, 15
CHAT_CATEGORY_OFFICER_1, CHAT_CATEGORY_OFFICER_2 = 21, 22
CHAT_CATEGORY_OFFICER_3, CHAT_CATEGORY_OFFICER_4, CHAT_CATEGORY_OFFICER_5 = 23, 24, 25
CHAT_CHANNEL_GUILD_1, CHAT_CHANNEL_GUILD_2 = 31, 32
CHAT_CHANNEL_GUILD_3, CHAT_CHANNEL_GUILD_4, CHAT_CHANNEL_GUILD_5 = 33, 34, 35
CHAT_CHANNEL_OFFICER_1, CHAT_CHANNEL_OFFICER_2 = 41, 42
CHAT_CHANNEL_OFFICER_3, CHAT_CHANNEL_OFFICER_4, CHAT_CHANNEL_OFFICER_5 = 43, 44, 45
CHAT_CHANNEL_SAY, CHAT_CHANNEL_ZONE = 1, 7
CHAT_CATEGORY_PARTY, CHAT_CHANNEL_PARTY = 5, 6
SI_PBSCHATASSISTANT_GROUP_TAB = "group-tab"

local sceneName = "hud"
local hudScene = {}
function hudScene:RegisterCallback(_, callback) self.callback = callback end
SCENE_MANAGER = {
	IsShowing = function(_, name) return name == sceneName end,
	GetScene = function(_, name) return name == "hud" and hudScene or nil end,
}

local guilds = { [1] = { id = 101, name = "Guild One" } }
function GetNumGuilds()
	local count = 0
	for _ in pairs(guilds) do count = count + 1 end
	return count
end
function GetGuildId(index) return guilds[index] and guilds[index].id end
function GetGuildName(id)
	for _, guild in pairs(guilds) do
		if guild.id == id then return guild.name end
	end
end
function GetChatCategoryColor(category)
	if category == CHAT_CATEGORY_PARTY then
		return 0.1, 0.9, 0.3
	end
	if category == CHAT_CATEGORY_GUILD_2 then
		return 0.7, 0.5, 0.2
	end
	assert(category == CHAT_CATEGORY_GUILD_1)
	return 0.2, 0.4, 0.6
end
function GetNumChatCategories() return 25 end
function GetString(id)
	if id == SI_PBSCHATASSISTANT_GROUP_TAB then return "Group" end
	return "Tab: %s"
end
function d() end

function ZO_PostHook(object, method, callback)
	local original = assert(object[method])
	object[method] = function(self, ...)
		local results = { original(self, ...) }
		callback(self, ...)
		return table.unpack(results)
	end
end

local function Window(hidden, tab)
	return { tab = { index = tab }, buffer = {}, hidden = hidden,
		IsHidden = function(self) return self.hidden end }
end

local container = {
	names = { "Normal", "Guild One" },
	windows = { Window(false, 1), Window(true, 2) },
}
function container:GetTabName(index) return self.names[index] end
function container:SetTabName(index, name) self.names[index] = name end
container.filters = {}
function container:SetWindowFilterEnabled(tabIndex, category, enabled)
	self.filters[tabIndex] = self.filters[tabIndex] or {}
	self.filters[tabIndex][category] = enabled
end
function container:AddWindow(name)
	local index = #self.windows + 1
	self.names[index] = name
	self.windows[index] = Window(true, index)
end
function container:RemoveWindow(index)
	local removed = table.remove(self.windows, index)
	table.remove(self.names, index)
	-- The client keeps its per-tab filters by position and closes the gap itself.
	for position = index, #self.windows + 1 do
		self.filters[position] = self.filters[position + 1]
	end
	for newIndex, window in ipairs(self.windows) do window.tab.index = newIndex end
	if removed and self.currentBuffer == removed.buffer then
		self.currentBuffer = self.windows[1] and self.windows[1].buffer
	end
end
function container:HandleTabClick(tab)
	for index, window in ipairs(self.windows) do window.hidden = index ~= tab.index end
	self.currentBuffer = self.windows[tab.index].buffer
end

local chat = { primaryContainer = container, currentChannel = 1, setChannelCalls = 0 }
function chat:SetChannel(channelId)
	self.currentChannel = channelId
	self.setChannelCalls = self.setChannelCalls + 1
end
function chat:GetDefaultChatChannel() return CHAT_CHANNEL_ZONE end
function ZO_GetChatSystem() return chat end

PBS_CHAT_ASSISTANT = {
	sv = {
		guildTabsEnabled = true,
		tabNameVisible = true,
		tabStripPlaced = true,
		tabStripX = 30,
		tabStripY = 140,
		tabTextSize = 32,
		tabTextLayer = "text",
	},
}

dofile("ChatTabs.lua")
local tabs = assert(PBS_CHAT_ASSISTANT.chatTabs)
local count = 0
local function test(name, fn)
	fn()
	count = count + 1
	print("PASS " .. name)
end

test("normal tab is shown in white at the configured size and position", function()
	tabs:RefreshStrip(container)
	assert(tabs.indicatorLabel.text == "Normal")
	assert(tabs.indicatorLabel.font == "$(GAMEPAD_MEDIUM_FONT)|32|soft-shadow-thick")
	assert(tabs.indicator.drawTier == DT_HIGH and tabs.indicatorLabel.drawLayer == DL_TEXT)
	assert(tabs.indicatorLabel.colour[1] == 1 and tabs.indicatorLabel.colour[2] == 1
		and tabs.indicatorLabel.colour[3] == 1 and tabs.indicatorLabel.colour[4] == 1)
	assert(tabs.indicator.anchor[4] == 30 and tabs.indicator.anchor[5] == 140)
end)

test("client tab changes refresh the name and use that guild's chat colour", function()
	container:HandleTabClick(container.windows[2].tab)
	assert(tabs.indicatorLabel.text == "Guild One")
	assert(tabs.indicatorLabel.colour[1] == 0.2 and tabs.indicatorLabel.colour[2] == 0.4
		and tabs.indicatorLabel.colour[3] == 0.6 and tabs.indicatorLabel.colour[4] == 1)
	assert(chat.currentChannel == CHAT_CHANNEL_GUILD_1)
end)

test("normal tab restores a non-guild outgoing channel", function()
	container:HandleTabClick(container.windows[1].tab)
	assert(tabs.indicatorLabel.text == "Normal")
	assert(chat.currentChannel == CHAT_CHANNEL_SAY)
end)

test("menu scenes hide the indicator and returning to HUD shows it", function()
	sceneName = "menu"
	hudScene.callback()
	assert(tabs.indicator:IsHidden())
	sceneName = "hud"
	hudScene.callback()
	assert(not tabs.indicator:IsHidden())
end)

test("minimised window visibility does not lose the selected tab", function()
	container:HandleTabClick(container.windows[2].tab)
	container.windows[1].hidden = true
	container.windows[2].hidden = true
	assert(tabs:GetActiveIndex(container) == 2)
	container.windows[2].hidden = false
end)

test("login guild channel selects its guild tab without replacing the channel", function()
	chat.currentChannel = CHAT_CHANNEL_OFFICER_1
	assert(tabs:SelectTabForChannel(CHAT_CHANNEL_OFFICER_1))
	assert(tabs:GetActiveIndex(container) == 2)
	assert(chat.currentChannel == CHAT_CHANNEL_OFFICER_1)
end)

test("login non-guild channel selects the normal tab without replacing the channel", function()
	chat.currentChannel = 7
	assert(tabs:SelectTabForChannel(7))
	assert(tabs:GetActiveIndex(container) == 1)
	assert(chat.currentChannel == 7)
end)

test("external destination changes select the matching tab", function()
	chat:SetChannel(CHAT_CHANNEL_GUILD_1)
	assert(tabs:GetActiveIndex(container) == 2)
	assert(tabs.indicatorLabel.text == "Guild One")
	chat:SetChannel(CHAT_CHANNEL_ZONE)
	assert(tabs:GetActiveIndex(container) == 1)
	assert(tabs.indicatorLabel.text == "Normal")
end)

test("programmatic selection uses the tab group callback exactly once", function()
	container.tabGroup = {
		clicked = container.windows[1].tab,
		GetClickedButton = function(self) return self.clicked end,
		SetClickedButton = function(self, button)
			self.clicked = button
			container:HandleTabClick(button)
		end,
	}
	local before = chat.setChannelCalls
	assert(tabs:SelectTab(2, false))
	assert(tabs:GetActiveIndex(container) == 2)
	assert(chat.currentChannel == CHAT_CHANNEL_GUILD_1)
	assert(chat.setChannelCalls == before + 1)
end)

test("programmatic selection repairs a restored tab group whose callback does not fire", function()
	container.tabGroup = {
		clicked = container.windows[2].tab,
		GetClickedButton = function(self) return self.clicked end,
		SetClickedButton = function(self, button) self.clicked = button end,
	}
	chat.currentChannel = CHAT_CHANNEL_OFFICER_1
	assert(tabs:SelectTab(1, false, false))
	assert(tabs:GetActiveIndex(container) == 1)
	assert(container.currentBuffer == container.windows[1].buffer)
	assert(chat.currentChannel == CHAT_CHANNEL_OFFICER_1)
end)

test("settings restyle the existing indicator", function()
	PBS_CHAT_ASSISTANT.sv.tabStripX = -50
	PBS_CHAT_ASSISTANT.sv.tabStripY = 200
	PBS_CHAT_ASSISTANT.sv.tabTextSize = 48
	PBS_CHAT_ASSISTANT.sv.tabTextLayer = "overlay"
	tabs:PositionStrip()
	assert(tabs.indicatorLabel.font == "$(GAMEPAD_MEDIUM_FONT)|48|soft-shadow-thick")
	assert(tabs.indicatorLabel.drawLayer == DL_OVERLAY)
	assert(tabs.indicator.anchor[4] == -50 and tabs.indicator.anchor[5] == 200)
end)

test("active tab text can be hidden without disabling tab switching", function()
	PBS_CHAT_ASSISTANT.sv.tabNameVisible = false
	tabs:RefreshStrip(container)
	assert(tabs.indicator:IsHidden())
	assert(PBS_CHAT_ASSISTANT.sv.guildTabsEnabled)
	container:HandleTabClick(container.windows[2].tab)
	assert(chat.currentChannel == CHAT_CHANNEL_GUILD_1)
	PBS_CHAT_ASSISTANT.sv.tabNameVisible = true
	tabs:RefreshStrip(container)
	assert(not tabs.indicator:IsHidden())
end)

test("disabling guild tabs hides the indicator", function()
	PBS_CHAT_ASSISTANT.sv.guildTabsEnabled = false
	tabs:RefreshStrip(container)
	assert(tabs.indicator:IsHidden())
end)

test("reconcile leaves exactly one tab for each joined guild", function()
	PBS_CHAT_ASSISTANT.sv.guildTabsEnabled = true
	PBS_CHAT_ASSISTANT.sv.guildTabNames = {
		["101"] = "Guild One",
		["999"] = "Old Guild",
	}
	container:AddWindow("Guild One")
	container:AddWindow("Old Guild")
	assert(#container.windows == 4)
	tabs:Reconcile()
	-- Normal, one per guild, and the group tab.
	assert(#container.windows == GetNumGuilds() + 2)
	assert(container:GetTabName(1) == "Normal")
	assert(container:GetTabName(2) == "Guild One")
	assert(PBS_CHAT_ASSISTANT.sv.guildTabNames["999"] == nil)
end)

test("reconcile adds one group tab carrying party chat only, and does not add it twice", function()
	local groupIndex = tabs:GroupTabIndex(container)
	assert(groupIndex and container:GetTabName(groupIndex) == "Group")
	assert(PBS_CHAT_ASSISTANT.sv.groupTabName == "Group")
	assert(container.filters[groupIndex][CHAT_CATEGORY_PARTY] == true)
	assert(container.filters[groupIndex][CHAT_CATEGORY_GUILD_1] == false)
	local before = #container.windows
	tabs:Reconcile()
	assert(#container.windows == before)
end)

test("the chord walks normal, group, then guilds in slot order, whatever order the tabs stand in", function()
	guilds[2] = { id = 102, name = "Guild Two" }
	tabs:Reconcile()
	-- Physically: Normal, Guild One, Group, Guild Two. The group tab was made after Guild One.
	assert(container:GetTabName(2) == "Guild One" and container:GetTabName(3) == "Group")
	container.tabGroup = nil
	assert(tabs:SelectTab(1, false, false))
	local walked = {}
	for _ = 1, 4 do
		assert(tabs:Cycle(1))
		walked[#walked + 1] = container:GetTabName(tabs:GetActiveIndex(container))
	end
	assert(table.concat(walked, ",") == "Group,Guild One,Guild Two,Normal", table.concat(walked, ","))
end)

test("the group tab sends to party chat, in party colour, and normal restores the earlier channel", function()
	assert(tabs:SelectTab(1, false, false))
	chat.currentChannel = CHAT_CHANNEL_ZONE
	tabs.normalChannel = CHAT_CHANNEL_ZONE
	assert(tabs:Cycle(1))
	assert(container:GetTabName(tabs:GetActiveIndex(container)) == "Group")
	assert(chat.currentChannel == CHAT_CHANNEL_PARTY)
	assert(tabs.indicatorLabel.text == "Group")
	assert(tabs.indicatorLabel.colour[1] == 0.1 and tabs.indicatorLabel.colour[2] == 0.9)
	assert(tabs:SelectTab(1, false))
	assert(chat.currentChannel == CHAT_CHANNEL_ZONE)
end)

test("choosing party chat through the game selects the group tab", function()
	chat:SetChannel(CHAT_CHANNEL_PARTY)
	assert(container:GetTabName(tabs:GetActiveIndex(container)) == "Group")
	assert(chat.currentChannel == CHAT_CHANNEL_PARTY)
end)

test("turning the tabs off removes the group tab too", function()
	tabs:RemoveAll()
	assert(tabs:GroupTabIndex(container) == nil)
	assert(PBS_CHAT_ASSISTANT.sv.groupTabName == nil)
	assert(#container.windows == 1)
end)

print(count .. " tests passed")
