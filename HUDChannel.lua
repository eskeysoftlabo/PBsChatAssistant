-- L2 is read, never bound. Only L3 is temporarily reassigned while L2 is held on HUD.
local NAME = "PBsChatAssistantHUDChannel"
local LAYER = "PBsChatAssistantHUDChannelLayer"
local channel = { layerAdded = false, downs = 0, ups = 0, changes = 0 }
PBS_CHAT_ASSISTANT_HUD_CHANNEL = channel

local function GetChat()
    return type(ZO_GetChatSystem) == "function" and ZO_GetChatSystem()
end

function channel:IsAvailable()
    local addon = PBS_CHAT_ASSISTANT
    if not addon or not addon.sv or not addon.sv.enabled or not addon.sv.hudChannelEnabled then return false end
    if addon.sv.captureMode ~= "off" or not SCENE_MANAGER:IsShowing("hud") then return false end
    local chat = GetChat()
    if not chat or type(chat.IsTextEntryOpen) ~= "function" or chat:IsTextEntryOpen() then return false end
    return not (type(IsVirtualKeyboardOnScreen) == "function" and IsVirtualKeyboardOnScreen())
end

function channel:ReadTrigger()
    if self.error then return nil end
    if type(GetGamepadLeftTriggerMagnitude) ~= "function" then
        self.error = "L2 analog API unavailable"
        return nil
    end
    local ok, value = pcall(GetGamepadLeftTriggerMagnitude)
    if not ok or type(value) ~= "number" or value ~= value or value < 0 or value > 1 then
        self.error = "L2 analog: " .. tostring(value)
        return nil
    end
    self.magnitude = value
    return value
end

function channel:SetLayer(wanted)
    if wanted == self.layerAdded then return end
    if wanted then
        self.layerAdded = true
        local ok, err = pcall(function() self.scene:AddFragment(self.fragment) end)
        if not ok then
            self.error = "layer: " .. tostring(err)
            self:SetLayer(false)
        end
    else
        self.layerAdded = false
        if self.fragment then self.scene:RemoveFragment(self.fragment) end
        RemoveActionLayerByName(LAYER)
    end
end

function channel:RefreshLabel()
    local chat = GetChat()
    local id = chat and chat.currentChannel
    local name = PBS_CHAT_ASSISTANT:GetChannelDisplayName(id)
    local text = string.format(GetString(SI_PBSCHATASSISTANT_CHANNEL_LABEL), tostring(name or id or "--"))
    if self.error then text = text .. "  [切替停止: /pbchat hudstatus]" end
    if self.lastText ~= text then
        self.label:SetText(text)
        self.lastText = text
    end
end

function channel:Update()
    if not self.running then return end
    local available = self:IsAvailable()
    if not available or self.error then
        self.triggerHeld = false
        self:SetLayer(false)
    else
        local value = self:ReadTrigger()
        if value then
            if value >= 0.5 then self.triggerHeld = true
            elseif value <= 0.1 then self.triggerHeld = false end
        else
            self.triggerHeld = false
        end
        self:SetLayer(self.triggerHeld == true)
    end
    self.window:SetHidden(not available)
    if available then self:RefreshLabel() end
end

function channel:OnL3Down()
    self.downs = self.downs + 1
    -- A queued event after release or after opening a menu must not switch channels.
    if not self.running or not self.layerAdded or not self:IsAvailable() then return false end
    local value = self:ReadTrigger()
    if not value or value <= 0.1 then
        self.triggerHeld = false
        self:SetLayer(false)
        return false
    end
    local chat = GetChat()
    local before = chat.currentChannel
    local ok, err = pcall(function() PBS_CHAT_ASSISTANT:CycleChannel(1, true) end)
    if not ok then
        self.error = "channel: " .. tostring(err)
        self:SetLayer(false)
    elseif chat.currentChannel ~= before then
        self.changes = self.changes + 1
    end
    self:RefreshLabel()
    -- No release latch: every delivered Down is evaluated independently.
    -- L3 is deliberately repurposed while L2 is held; no input is synthesized.
    return true
end

function channel:OnL3Up()
    self.ups = self.ups + 1
    return self.layerAdded and self:IsAvailable() or false
end

function channel:PrintStatus()
    local actual = type(IsActionLayerActiveByName) == "function" and IsActionLayerActiveByName(LAYER)
    d(string.format("[PB HUD] running=%s scene=%s available=%s L2=%s attached=%s active=%s L3 D/U=%d/%d changes=%d error=%s",
        tostring(self.running), tostring(SCENE_MANAGER:GetCurrentSceneName()), tostring(self:IsAvailable()),
        tostring(self.magnitude), tostring(self.layerAdded), tostring(actual), self.downs, self.ups,
        self.changes, tostring(self.error or "none")))
end

function channel:Start()
    if self.running then return end
    if not self.window then
        self.scene = SCENE_MANAGER:GetScene("hud")
        self.fragment = ZO_ActionLayerFragment:New(LAYER)
        self.fragment:RegisterCallback("StateChange", function(_, state)
            if state == SCENE_FRAGMENT_HIDDEN then self.triggerHeld = false end
        end)
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
    self.error = nil
    self.triggerHeld = false
    self.running = true
    self:Update()
    EVENT_MANAGER:RegisterForUpdate(NAME, 10, function() self:Update() end)
end

function channel:Stop()
    self.running = false
    self.triggerHeld = false
    EVENT_MANAGER:UnregisterForUpdate(NAME)
    self:SetLayer(false)
    if self.window then self.window:SetHidden(true) end
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= "PBsChatAssistant" then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function() channel:Start() end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function() channel:Stop() end)
end)
