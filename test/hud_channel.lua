-- Run from the add-on directory: lua test/hud_channel.lua
local time, analog, block, gamepad, sceneName, entryOpen, ime = 0, 0, false, true, 'hud', false, false
local combat = false
local events, updates = {}, {}
EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED, EVENT_PLAYER_DEACTIVATED = 1, 2, 3
EVENT_CONTROLLER_DISCONNECTED, EVENT_CONTROLLER_CONNECTED = 4, 5
EVENT_PLAYER_COMBAT_STATE = 6
SCENE_FRAGMENT_HIDDEN = 'hidden'
EVENT_MANAGER = {
 RegisterForEvent = function(_, _, id, cb) events[id] = cb end,
 UnregisterForEvent = function(_, _, id) events[id] = nil end,
 RegisterForUpdate = function(_, name, _, cb) updates[name] = cb end,
 UnregisterForUpdate = function(_, name) updates[name] = nil end,
}
function IsUnitInCombat(unit) assert(unit == "player"); return combat end
function GetGameTimeSeconds() return time end
function GetGamepadLeftTriggerMagnitude() return analog end
function IsBlockActive() return block end
function IsInGamepadPreferredMode() return gamepad end
function IsVirtualKeyboardOnScreen() return ime end
local removedLayers = {}
function RemoveActionLayerByName(name) removedLayers[name] = true end
function d() end
local chat = {currentChannel = 1, IsTextEntryOpen = function() return entryOpen end}
function ZO_GetChatSystem() return chat end
PBS_CHAT_ASSISTANT = {sv = {enabled = true, hudChannelEnabled = true, captureMode = 'off'}}
function PBS_CHAT_ASSISTANT:CycleChatTab(step)
 assert(step == 1); chat.currentChannel = chat.currentChannel % 3 + 1
end
local hud = {fragments = {}}
function hud:AddFragment(f) self.fragments[f] = true end
function hud:RemoveFragment(f)
 if self.fragments[f] then self.fragments[f] = nil; f.cb(nil, SCENE_FRAGMENT_HIDDEN) end
end
SCENE_MANAGER = {
 GetScene = function() return hud end,
 IsShowing = function(_, name) return sceneName == name end,
 GetCurrentSceneName = function() return sceneName end,
}
ZO_ActionLayerFragment = {New = function(_, name)
 return {name = name, RegisterCallback = function(self, _, cb) self.cb = cb end}
end}
dofile('HUDChannel.lua')
local c = PBS_CHAT_ASSISTANT_HUD_CHANNEL
local count = 0
local function test(name, fn) fn(); count = count + 1; print('PASS '..name) end
local function reset()
 c:Stop(); combat = false; time = 0; analog = 0; block = false; gamepad = true
 sceneName = 'hud'; entryOpen = false; ime = false; chat.currentChannel = 1
 PBS_CHAT_ASSISTANT.sv = {enabled = true, hudChannelEnabled = true, captureMode = 'off'}
 c:Start()
end
local function hold() analog = 1; c:Update() end
local function press() assert(c:OnRightDown()); assert(c:OnRightUp()); c:Update() end
events[EVENT_ADD_ON_LOADED](nil, 'PBsChatAssistant')
test('XML maps Right and blocks quest action without binding L2 or L3', function()
 local f = assert(io.open('Bindings.xml')); local xml = f:read('*a'); f:close()
 local layer = assert(xml:match('<Layer name="PBsChatAssistantHUDChannelRightLayer"(.-)</Layer>'))
 assert(layer:find('inheritsBindFrom="UI_SHORTCUT_INPUT_RIGHT"', 1, true))
 assert(layer:find('<BlockAction name="ASSIST_NEXT_TRACKED_QUEST"', 1, true))
 assert(not xml:find('UI_SHORTCUT_LEFT_TRIGGER', 1, true))
 assert(not xml:find('UI_SHORTCUT_LEFT_STICK', 1, true))
 assert(not xml:find('HUD_CHANNEL_L3', 1, true))
end)
test('right alone leaves gameplay layer unshadowed', function()
 reset(); assert(not c.layerAdded); assert(not c:OnRightDown()); assert(chat.currentChannel == 1)
end)
test('L2 plus Right cycles once and repeat Down does not cycle again', function()
 reset(); hold(); assert(c:OnRightDown()); assert(c:OnRightDown()); assert(chat.currentChannel == 2)
 assert(c:OnRightUp()); assert(c:OnRightDown()); assert(chat.currentChannel == 3); c:OnRightUp()
end)
test('L2 release before Right keeps quest block until after Up', function()
 reset(); hold(); c:OnRightDown(); analog = 0; c:Update(); assert(c.layerAdded)
 assert(c:OnRightUp()); assert(c.layerAdded); c:Update(); assert(not c.layerAdded)
end)
test('L2 alone does not cycle channels and release restores quest control', function()
 reset(); hold(); assert(chat.currentChannel == 1); analog = 0; c:Update(); assert(not c.layerAdded)
end)
test('block fallback works with unavailable analog API', function()
 reset(); local original = GetGamepadLeftTriggerMagnitude; GetGamepadLeftTriggerMagnitude = nil
 block = true; c:Update(); press(); assert(chat.currentChannel == 2); assert(block)
 GetGamepadLeftTriggerMagnitude = original
end)
test('transient analog failure recovers without restart', function()
 reset(); local original = GetGamepadLeftTriggerMagnitude
 GetGamepadLeftTriggerMagnitude = function() error('unavailable') end
 c:Update(); assert(not c.layerAdded and not c.error)
 GetGamepadLeftTriggerMagnitude = original; hold(); press(); assert(chat.currentChannel == 2)
end)
test('menus text entry IME keyboard mode and disabled settings remove layer', function()
 for _, change in ipairs({function() sceneName = 'menu' end, function() entryOpen = true end,
 function() ime = true end, function() gamepad = false end,
 function() PBS_CHAT_ASSISTANT.sv.hudChannelEnabled = false end,
 function() PBS_CHAT_ASSISTANT.sv.captureMode = 'on' end}) do
  reset(); hold(); change(); c:Update(); assert(not c.layerAdded); assert(not c:OnRightDown())
 end
end)
test('missing Right Up cannot leave quest block permanently active', function()
 reset(); hold(); c:OnRightDown(); analog = 0; time = 6; c:Update(); assert(not c.layerAdded)
end)
test('disconnect removes layer and reconnect resumes', function()
 reset(); hold(); c:OnRightDown(); events[EVENT_CONTROLLER_DISCONNECTED]()
 assert(not c.layerAdded and not c.running); analog = 0; events[EVENT_CONTROLLER_CONNECTED]()
 assert(c.running and not c.layerAdded)
end)
test('channel error still consumes Right release before removing quest block', function()
 reset(); hold(); local original = PBS_CHAT_ASSISTANT.CycleChatTab
 PBS_CHAT_ASSISTANT.CycleChatTab = function() error('test failure') end
 assert(c:OnRightDown()); analog = 0; c:Update(); assert(c.layerAdded)
 assert(c:OnRightUp()); c:Update(); assert(not c.layerAdded)
 PBS_CHAT_ASSISTANT.CycleChatTab = original
end)
test('legacy L3 layer is retired and only Right layer is attached', function()
 reset(); assert(removedLayers['PBsChatAssistantHUDChannelLayer'])
 hold(); assert(c.fragment.name == 'PBsChatAssistantHUDChannelRightLayer')
 assert(c.OnL3Down == nil and c.OnL3Up == nil)
 local f = assert(io.open('Bindings.xml')); local xml = f:read('*a'); f:close()
 assert(not xml:find('name="PBsChatAssistantHUDChannelLayer"', 1, true))
 assert(not xml:find('OnL3', 1, true))
end)
test('combat HUD never attaches quest blocking layer', function()
 reset(); combat = true; hold(); assert(not c.layerAdded); assert(not c:OnRightDown()); assert(chat.currentChannel == 1)
end)
test('combat cancels held chord immediately and recovers after combat', function()
 reset(); hold(); c:OnRightDown(); combat = true; events[EVENT_PLAYER_COMBAT_STATE](nil, true)
 assert(not c.layerAdded and not c.consumedRight); assert(not c:OnRightUp())
 combat = false; events[EVENT_PLAYER_COMBAT_STATE](nil, false); assert(c.layerAdded)
 press(); assert(chat.currentChannel == 3)
end)
test('combat rechecked in repeat Down before combat event', function()
 reset(); hold(); c:OnRightDown(); combat = true; assert(not c:OnRightDown())
 assert(chat.currentChannel == 2 and not c.layerAdded)
end)
test('reload or activation during combat does not capture Right', function()
 reset(); c:Stop(); combat = true; analog = 1; c:Start(); assert(not c.layerAdded)
end)
print(count..' tests passed; ESO physical input routing requires in-game validation')
