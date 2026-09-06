-- HUD channel switching. L2 release detection compensates for missing binding Up events.
local NAME = "PBsChatAssistantHUDChannel"
local HOST_ADDON = "PBsChatAssistant"
local LAYER = "PBsChatAssistantHUDChannelLayer"
local channel = { buttons = {} }
PBS_CHAT_ASSISTANT_HUD_CHANNEL = channel

local function GetChat()
    return type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
end

local function IsEnabled()
    local addon = PBS_CHAT_ASSISTANT
    return addon and addon.sv and addon.sv.enabled and addon.sv.captureMode == "off"
end

function channel:ResetButtons()
    self.buttons = {}
    self.chordLatched = false
    self.triggerWasDown = false
end

function channel:SampleTrigger()
    if self.triggerUnavailable then return end
    local ok, value = false, nil
    if type(GetGamepadLeftTriggerMagnitude) == "function" then
        ok, value = pcall(GetGamepadLeftTriggerMagnitude)
    end
    if not ok or type(value) ~= "number" or value ~= value or value < 0 or value > 1 then
        self.triggerUnavailable = true
        return
    end
    if value >= 0.5 then
        self.triggerWasDown = true
    elseif value <= 0.1 and self.triggerWasDown then
        self:ResetButtons()
    end
end

function channel:SetActive(active)
    if self.active == active then return end
    self.active = active
    self:ResetButtons()
    if active then
        local ok = pcall(function() self.scene:AddFragment(self.fragment) end)
        if not ok then
            self.failed = true
            self:SetActive(false)
        end
    else
        if self.fragment then self.scene:RemoveFragment(self.fragment) end
        RemoveActionLayerByName(LAYER)
        if self.window then self.window:SetHidden(true) end
    end
end

function channel:RefreshLabel()
    local chat = GetChat()
    local id = chat and chat.currentChannel
    local name = id and type(GetChannelName) == "function" and GetChannelName(id)
    local text = string.format(GetString(SI_PBSCHATASSISTANT_CHANNEL_LABEL), tostring(name or id or "--"))
    if text ~= self.lastText then
        self.label:SetText(text)
        self.lastText = text
    end
end

function channel:ButtonDown(button)
    if not self.active or not IsEnabled() or not SCENE_MANAGER:IsShowing("hud") then return false end
    self:SampleTrigger()
    self.buttons[button] = true
    if self.buttons.L3 and self.buttons.L2 and not self.chordLatched then
        self.chordLatched = true
        local chat = GetChat()
        if chat and type(chat.IsTextEntryOpen) == "function" and not chat:IsTextEntryOpen()
            and not (type(IsVirtualKeyboardOnScreen) == "function" and IsVirtualKeyboardOnScreen()) then
            local ok = pcall(function() PBS_CHAT_ASSISTANT:CycleChannel(1, true) end)
            if ok then
                self:RefreshLabel()
            else
                self.failed = true
                self:SetActive(false)
            end
        end
    end
    return false
end

function channel:ButtonUp(button)
    self.buttons[button] = nil
    if not self.buttons.L3 and not self.buttons.L2 then self.chordLatched = false end
    return false
end

function channel:Update()
    self:SetActive(not self.failed and not not IsEnabled())
    if not self.active then return end
    local onHUD = SCENE_MANAGER:IsShowing("hud")
    self.window:SetHidden(not onHUD)
    if onHUD then
        self:SampleTrigger()
        self:RefreshLabel()
    end
end

function channel:Start()
    if self.running then return end
    if not self.window then
        self.scene = SCENE_MANAGER:GetScene("hud")
        self.fragment = ZO_ActionLayerFragment:New(LAYER)
        self.fragment:RegisterCallback("StateChange", function() self:ResetButtons() end)
        self.window = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "Status")
        self.window:SetDimensions(1100, 40)
        self.window:SetAnchor(TOP, GuiRoot, TOP, 0, 110)
        self.window:SetMouseEnabled(false)
        self.window:SetHidden(true)
        self.label = WINDOW_MANAGER:CreateControl(NAME .. "Label", self.window, CT_LABEL)
        self.label:SetAnchorFill()
        self.label:SetFont("ZoFontGame")
        self.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    self.failed = false
    self.triggerUnavailable = false
    self.running = true
    self:Update()
    EVENT_MANAGER:RegisterForUpdate(NAME, 10, function() self:Update() end)
end

function channel:Stop()
    self.running = false
    EVENT_MANAGER:UnregisterForUpdate(NAME)
    self:SetActive(false)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= HOST_ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    -- Activation recurs after loading screens; keep these callbacks registered.
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function() channel:Start() end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function() channel:Stop() end)
end)
