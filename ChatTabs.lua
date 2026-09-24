-- Chat tabs: the normal tab, plus one per guild.
--
-- Console chat ships with a single tab and no way to add one. The parts are all there and are
-- shared rather than keyboard-only: SharedChatContainer:AddWindow makes a tab, HandleTabClick
-- switches to one, SetWindowFilterEnabled routes a category to a tab, and ZO_ChatWindowTabTemplate
-- is in the shared XML. The note in gamepadchatsystem.lua about not wanting more chat containers
-- on console is about containers, not about tabs inside one. Confirmed on a PS5 before this was
-- written: a tab can be added, selected from Lua, and removed again.
--
-- Officer chat shares its guild's tab. Splitting it would double the tab count for something read
-- in the same breath as the guild it belongs to.
if not PBS_CHAT_ASSISTANT then
	return
end

local addon = PBS_CHAT_ASSISTANT
local tabs = {}
addon.chatTabs = tabs

-- Guild data is not ready the moment the world appears, and a tab named after a guild needs the
-- name. Reconciling is debounced so the three events that can trigger it do not do the work three
-- times over.
local RECONCILE_DELAY_MS = 2000

-- Tab strip geometry, applied by this add-on rather than by the client.
--
-- The client anchors tabs BOTTOMLEFT to the container's TOPLEFT, which puts them above the box
-- and outside its rectangle. On console that comes out invisible: measured with five tabs, all
-- reporting hidden false with real widths, and nothing on screen. Rather than work out which of
-- the several reasons that could be, the strip is placed inside the container where there is
-- nothing to argue with -- and along the bottom, which is where it was asked for.
local TAB_STRIP_X = -20
local TAB_STRIP_Y = -215
local TAB_STRIP_WIDTH = 900
local TAB_STRIP_HEIGHT = 32

local function Print(formatString, ...)
	d(string.format("|cFF69B4PB's ChatAssistant|r: " .. formatString, ...))
end

local function GetContainer()
	local strip = self.strip
	Print("strip %s, hidden %s, drawn tabs %d", tostring(strip ~= nil),
		tostring(strip and strip:IsHidden()), self.stripTabs and #self.stripTabs or 0)

	local chat = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
	return chat and chat.primaryContainer
end

-- Built rather than declared: a table constructor with a nil key raises at load, and these are
-- client constants that a future update could rename.
local function GuildCategories(index)
	local guild = { CHAT_CATEGORY_GUILD_1, CHAT_CATEGORY_GUILD_2, CHAT_CATEGORY_GUILD_3,
		CHAT_CATEGORY_GUILD_4, CHAT_CATEGORY_GUILD_5 }
	local officer = { CHAT_CATEGORY_OFFICER_1, CHAT_CATEGORY_OFFICER_2, CHAT_CATEGORY_OFFICER_3,
		CHAT_CATEGORY_OFFICER_4, CHAT_CATEGORY_OFFICER_5 }
	return guild[index], officer[index]
end

-- Which guilds the player is in, by slot, with the names the tabs are called after.
function tabs:GuildSlots()
	local slots = {}
	local numGuilds = GetNumGuilds and GetNumGuilds() or 0
	for guildIndex = 1, numGuilds do
		local guildId = GetGuildId and GetGuildId(guildIndex)
		local name = guildId and GetGuildName and GetGuildName(guildId)
		if guildId then
			slots[#slots + 1] = { index = guildIndex, guildId = guildId, name = name }
		end
	end
	return slots
end

-- Per guild, not one switch for all of them. Missing means shown, so a guild joined later behaves
-- the way the chat did before any of this existed.
function tabs:IsGuildInMainTab(guildId)
	local map = addon.sv and addon.sv.guildMainTab
	if not map or guildId == nil then
		return true
	end
	local stored = map[tostring(guildId)]
	if stored == nil then
		return true
	end
	return stored
end

function tabs:SetGuildInMainTab(guildId, shown)
	if not addon.sv or guildId == nil then
		return
	end
	addon.sv.guildMainTab = addon.sv.guildMainTab or {}
	addon.sv.guildMainTab[tostring(guildId)] = shown and true or false
	self:Reconcile()
end

local function GuildTabName(guildIndex)
	local guildId = GetGuildId and GetGuildId(guildIndex)
	local name = guildId and GetGuildName and GetGuildName(guildId)
	if name and name ~= "" then
		return name
	end
	return nil
end

local function FindTabByName(container, name)
	for index = 1, #container.windows do
		if container:GetTabName(index) == name then
			return index
		end
	end
	return nil
end

----------------------------------------------------------------------------------------------
-- Category routing
----------------------------------------------------------------------------------------------

-- Everything off except this guild and its officer channel.
--
-- A new tab inherits whatever categories the client had enabled by default, which is most of
-- them, so the guild tab has to be cleared rather than only added to. SetWindowFilterEnabled is a
-- no-op when the value already matches, so this is cheap on every pass but the first.
function tabs:RouteGuildTab(container, tabIndex, guildCategory, officerCategory)
	if type(GetNumChatCategories) ~= "function" then
		return
	end

	for category = 1, GetNumChatCategories() do
		local wanted = (category == guildCategory) or (category == officerCategory)
		container:SetWindowFilterEnabled(tabIndex, category, wanted)
	end
end

-- The normal tab keeps everything it had; only the guild and officer categories are touched, and
-- only according to the setting. Reading every guild in one place is the point of leaving them on.
function tabs:ApplyMainTabGuildVisibility(container)
	for guildIndex = 1, 5 do
		local guildCategory, officerCategory = GuildCategories(guildIndex)
		local guildId = GetGuildId and GetGuildId(guildIndex)
		local wanted = self:IsGuildInMainTab(guildId)

		if guildCategory then
			container:SetWindowFilterEnabled(1, guildCategory, wanted)
		end
		if officerCategory then
			container:SetWindowFilterEnabled(1, officerCategory, wanted)
		end
	end
end

----------------------------------------------------------------------------------------------
-- Reconciling
----------------------------------------------------------------------------------------------

-- Tabs persist in the client's own chat settings, so this has to be idempotent: a tab is created
-- only when one of that name is not already there, or every login would add another.
--
-- Tabs we created are remembered by name against the guild id, so a guild the player has left can
-- have its tab taken away again without touching a tab somebody made by hand.
function tabs:Reconcile()
	if not addon.sv or not addon.sv.guildTabsEnabled then
		return
	end

	local container = GetContainer()
	if not container or #container.windows == 0 then
		return
	end

	addon.sv.guildTabNames = addon.sv.guildTabNames or {}
	local known = addon.sv.guildTabNames
	local seen = {}

	local numGuilds = GetNumGuilds and GetNumGuilds() or 0
	for guildIndex = 1, numGuilds do
		local name = GuildTabName(guildIndex)
		local guildCategory, officerCategory = GuildCategories(guildIndex)
		local guildId = GetGuildId and GetGuildId(guildIndex)

		if name and guildCategory and guildId then
			seen[tostring(guildId)] = true

			local tabIndex = FindTabByName(container, name)
			if not tabIndex then
				-- Renamed guild: reuse the tab we made for it rather than leaving an orphan.
				local previous = known[tostring(guildId)]
				if previous then
					tabIndex = FindTabByName(container, previous)
					if tabIndex then
						container:SetTabName(tabIndex, name)
					end
				end
			end

			if not tabIndex then
				container:AddWindow(name)
				tabIndex = FindTabByName(container, name)
			end

			if tabIndex then
				known[tostring(guildId)] = name
				self:RouteGuildTab(container, tabIndex, guildCategory, officerCategory)
			end
		end
	end

	-- Tabs for guilds no longer joined.
	for guildId, name in pairs(known) do
		if not seen[guildId] then
			local tabIndex = FindTabByName(container, name)
			if tabIndex and tabIndex > 1 then
				container:RemoveWindow(tabIndex)
			end
			known[guildId] = nil
		end
	end

	self:ApplyMainTabGuildVisibility(container)
	self:RefreshStrip(container)
end

function tabs:ScheduleReconcile()
	if self.reconcilePending then
		return
	end
	self.reconcilePending = true
	zo_callLater(function()
		self.reconcilePending = false
		self:Reconcile()
	end, RECONCILE_DELAY_MS)
end

-- Takes away every tab this add-on made, and hands the guild categories back to the normal tab so
-- nothing becomes unreadable by turning the feature off.
function tabs:RemoveAll()
	local container = GetContainer()
	if not container or not addon.sv then
		return
	end

	local known = addon.sv.guildTabNames or {}
	for guildId, name in pairs(known) do
		local tabIndex = FindTabByName(container, name)
		if tabIndex and tabIndex > 1 then
			container:RemoveWindow(tabIndex)
		end
		known[guildId] = nil
	end

	for index = 1, 5 do
		local guildCategory, officerCategory = GuildCategories(index)
		if guildCategory then
			container:SetWindowFilterEnabled(1, guildCategory, true)
		end
		if officerCategory then
			container:SetWindowFilterEnabled(1, officerCategory, true)
		end
	end
end

----------------------------------------------------------------------------------------------
-- Selecting
----------------------------------------------------------------------------------------------

-- HandleTabClick hides every window but the chosen one, so the visible window is the active tab.
function tabs:GetActiveIndex(container)
	for index = 1, #container.windows do
		if not container.windows[index]:IsHidden() then
			return index
		end
	end
	return 1
end

-- The tab strip, drawn entirely by this add-on.
--
-- The client's own tab buttons never appear on console. Measured: width 36, height 24, alpha 1,
-- hidden false, parent ZO_GamepadTextChat itself shown with alpha 1 -- every reading says visible
-- and nothing is on screen, whether they are placed above the chat box or inside it. They keep
-- the job they are good at, which is owning the buffers, the filters and the switching.
--
-- Everything below is this add-on's own controls: a window, and per tab a backdrop with a label.
-- The starting geometry is deliberately the one configuration known to have displayed on this
-- platform -- a top level window of 1100x40 anchored TOP to GuiRoot at y 110, labels in
-- ZoFontGame -- because the point of this pass is to be seen first and pretty second. Where it
-- sits is a setting, so it can be moved to wherever it belongs without another build.
local STRIP_NAME = "PBsChatAssistantTabStrip"
local STRIP_WIDTH = 1100
local STRIP_HEIGHT = 40
local TAB_PADDING_X = 14
local TAB_GAP = 8

local function Colour(control, r, g, b, a)
	if control and control.SetColor then
		control:SetColor(r, g, b, a)
	end
end

function tabs:EnsureStrip()
	if self.strip then
		return self.strip
	end
	if type(WINDOW_MANAGER) ~= "table" then
		return nil
	end

	local window = WINDOW_MANAGER:CreateTopLevelWindow(STRIP_NAME)
	window:SetDimensions(STRIP_WIDTH, STRIP_HEIGHT)
	window:SetMouseEnabled(false)
	window:SetHidden(true)

	self.strip = window
	self.stripTabs = {}
	self:PositionStrip()
	return window
end

-- Anchored TOP to GuiRoot, with both offsets settings. X moves it sideways from the centre, Y
-- down from the top, which is the easiest pair to describe to somebody nudging it into place.
function tabs:PositionStrip()
	if not self.strip then
		return
	end
	local x = (addon.sv and addon.sv.tabStripX) or 0
	local y = (addon.sv and addon.sv.tabStripY) or 110
	self.strip:ClearAnchors()
	self.strip:SetAnchor(TOP, GuiRoot, TOP, x, y)
end

-- One backdrop and one label per tab, made once and reused.
function tabs:AcquireStripTab(index)
	local existing = self.stripTabs[index]
	if existing then
		return existing
	end

	local name = string.format("%sTab%d", STRIP_NAME, index)
	local backdrop = WINDOW_MANAGER:CreateControl(name, self.strip, CT_BACKDROP)
	backdrop:SetEdgeTexture("", 1, 1, 1)
	backdrop:SetHeight(STRIP_HEIGHT - 6)

	local label = WINDOW_MANAGER:CreateControl(name .. "Label", backdrop, CT_LABEL)
	label:SetAnchorFill()
	label:SetFont("ZoFontGame")
	label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

	local entry = { backdrop = backdrop, label = label }
	self.stripTabs[index] = entry
	return entry
end

function tabs:RefreshStrip(container)
	container = container or GetContainer()
	local strip = self:EnsureStrip()
	if not strip then
		return
	end

	local wanted = container and addon.sv and addon.sv.guildTabsEnabled and #container.windows > 1
	strip:SetHidden(not wanted)
	if not wanted then
		return
	end

	local activeIndex = self:GetActiveIndex(container)
	local count = #container.windows

	-- Laid out centre-outwards: total width first, then each tab from the left edge of that.
	local widths = {}
	local total = 0
	for index = 1, count do
		local entry = self:AcquireStripTab(index)
		local name = container:GetTabName(index) or tostring(index)
		entry.label:SetText(name)
		local width = entry.label:GetTextWidth() + TAB_PADDING_X * 2
		widths[index] = width
		total = total + width + (index > 1 and TAB_GAP or 0)
	end

	local x = -total / 2
	for index = 1, count do
		local entry = self.stripTabs[index]
		local active = index == activeIndex

		entry.backdrop:SetWidth(widths[index])
		entry.backdrop:ClearAnchors()
		entry.backdrop:SetAnchor(LEFT, strip, CENTER, x, 0)
		entry.backdrop:SetHidden(false)
		entry.backdrop:SetCenterColor(0, 0, 0, active and 0.8 or 0.4)
		Colour(entry.label, 1, 1, 1, active and 1 or 0.45)

		x = x + widths[index] + TAB_GAP
	end

	-- Tabs left over from a guild that has gone.
	for index = count + 1, #self.stripTabs do
		self.stripTabs[index].backdrop:SetHidden(true)
	end
end

-- The smallest possible question: can this add-on put anything on screen at all?
--
-- It could once. The status label this add-on used to show for the outgoing channel was a top
-- level window of 1100x40 anchored TOP to GuiRoot at y 110 with a ZoFontGame label, and it
-- displayed. The tab strip is built the same way and does not. So this reproduces that label
-- exactly, adds a bright backdrop behind it so there is something to see even if text is the
-- problem, and is created and shown immediately rather than from inside a reconcile.
--
-- If this shows, the fault is in when or whether RefreshStrip runs. If it does not, nothing this
-- add-on draws reaches the screen any more and the strip cannot be built this way at all.
function tabs:DrawTest(on)
	if not on then
		if self.testWindow then
			self.testWindow:SetHidden(true)
		end
		Print("draw test off")
		return
	end

	if not self.testWindow then
		local window = WINDOW_MANAGER:CreateTopLevelWindow("PBsChatAssistantDrawTest")
		window:SetDimensions(1100, 40)
		window:SetAnchor(TOP, GuiRoot, TOP, 0, 110)
		window:SetMouseEnabled(false)

		local backdrop = WINDOW_MANAGER:CreateControl("PBsChatAssistantDrawTestBg", window, CT_BACKDROP)
		backdrop:SetAnchorFill()
		backdrop:SetCenterColor(1, 0, 0, 0.8)
		backdrop:SetEdgeColor(1, 1, 0, 1)

		local label = WINDOW_MANAGER:CreateControl("PBsChatAssistantDrawTestLabel", window, CT_LABEL)
		label:SetAnchorFill()
		label:SetFont("ZoFontGame")
		label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		label:SetText("PB DRAW TEST")
		label:SetColor(1, 1, 1, 1)

		self.testWindow = window
	end

	self.testWindow:SetHidden(false)
	Print("draw test on: red bar with PB DRAW TEST, top centre, 110 down")
end

function tabs:SelectTab(index, announce)
	local container = GetContainer()
	local window = container and container.windows[index]
	if not window then
		return false
	end

	if container.tabGroup and window.tab then
		container.tabGroup:SetClickedButton(window.tab)
	end
	container:HandleTabClick(window.tab)
	self:RefreshStrip(container)

	if announce then
		Print(GetString(SI_PBSCHATASSISTANT_TAB_LABEL), tostring(container:GetTabName(index)))
	end
	return true
end

function tabs:Cycle(step)
	local container = GetContainer()
	if not container then
		return false
	end

	local count = #container.windows
	if count < 2 then
		return false
	end

	local current = self:GetActiveIndex(container)
	local nextIndex = ((current - 1 + step) % count) + 1
	return self:SelectTab(nextIndex, true)
end

function tabs:PrintStatus()
	local container = GetContainer()
	if not container then
		Print("no chat container")
		return
	end

	local strip = self.strip
	Print("strip %s, hidden %s, drawn tabs %d", tostring(strip ~= nil),
		tostring(strip and strip:IsHidden()), self.stripTabs and #self.stripTabs or 0)

	local chat = type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
	Print("tabs %d, active %d, guild tabs %s, guilds %d", #container.windows,
		self:GetActiveIndex(container), tostring(addon.sv and addon.sv.guildTabsEnabled),
		GetNumGuilds and GetNumGuilds() or -1)

	-- Whether a tab exists and whether it can be seen are different questions, and the answer so
	-- far is "no visible change", which both would produce. Minimised is the suspect: the console
	-- chat sits collapsed during play, and the tabs are children of the container that collapses.
	Print("container hidden %s, minimised %s, HUD %s",
		tostring(container.control and container.control:IsHidden()),
		tostring(chat and chat.isMinimized), tostring(chat and chat.hudEnabled))

	for index = 1, #container.windows do
		local tab = container.windows[index].tab
		local label = tab and tab.GetNamedChild and tab:GetNamedChild("Text")
		local parent = tab and tab:GetParent()
		Print("  %d: %s w %s h %s a %s hidden %s", index, tostring(container:GetTabName(index)),
			tostring(tab and tab:GetWidth()), tostring(tab and tab:GetHeight()),
			tostring(tab and tab:GetAlpha()), tostring(tab and tab:IsHidden()))
		Print("     parent %s (hidden %s, a %s), label %s (hidden %s, a %s)",
			tostring(parent and parent.GetName and parent:GetName()),
			tostring(parent and parent:IsHidden()), tostring(parent and parent:GetAlpha()),
			tostring(label ~= nil), tostring(label and label:IsHidden()),
			tostring(label and label:GetAlpha()))
	end
	for _, slot in ipairs(self:GuildSlots()) do
		Print("  guild %d %s: in normal tab %s", slot.index, tostring(slot.name),
			tostring(self:IsGuildInMainTab(slot.guildId)))
	end
end
