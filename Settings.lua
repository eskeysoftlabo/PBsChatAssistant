-- PBS_CHAT_ASSISTANT is nil if Main.lua bailed out early (the add-on was already loaded).
if not PBS_CHAT_ASSISTANT then
	return
end

local addon = PBS_CHAT_ASSISTANT

function addon:InitSettings()
	local LibHarvensAddonSettings = LibHarvensAddonSettings
	if not LibHarvensAddonSettings then
		return
	end

	local settings = LibHarvensAddonSettings:AddAddon(self.title)
	if not settings then
		return
	end

	self.settingsControls = settings
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_ENABLED),
			tooltip = GetString(SI_PBSCHATASSISTANT_ENABLED_TOOLTIP),
			default = true,
			getFunction = function()
				return self.sv.enabled
			end,
			setFunction = function(value)
				self.sv.enabled = value
				self:ApplyCatcher()
				self:ApplyWatch()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SLIDER,
			label = GetString(SI_PBSCHATASSISTANT_DELAY),
			tooltip = GetString(SI_PBSCHATASSISTANT_DELAY_TOOLTIP),
			min = 0,
			max = 2000,
			step = 50,
			default = 100,
			format = "%d",
			unit = "ms",
			getFunction = function()
				return self.sv.delayMs
			end,
			setFunction = function(value)
				self.sv.delayMs = value
			end
		}
	)

	-- Arming Enter is the one setting with a cost attached, so it says so in its tooltip rather
	-- than leaving the player to discover it by pressing a button that does nothing.
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_ENTER),
			tooltip = GetString(SI_PBSCHATASSISTANT_ENTER_TOOLTIP),
			default = false,
			getFunction = function()
				return self.sv.captureMode ~= "off"
			end,
			setFunction = function(value)
				self.sv.captureMode = value and "default" or "off"
				self.sv.followInput = false
				self:ApplyCatcher()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_AUTOSAFE),
			tooltip = GetString(SI_PBSCHATASSISTANT_AUTOSAFE_TOOLTIP),
			default = true,
			getFunction = function()
				return self.sv.autoSafe
			end,
			setFunction = function(value)
				self.sv.autoSafe = value
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_CHANNEL_KEYS),
			tooltip = GetString(SI_PBSCHATASSISTANT_CHANNEL_KEYS_TOOLTIP),
			default = true,
			getFunction = function()
				return self.sv.channelKeys
			end,
			setFunction = function(value)
				self.sv.channelKeys = value
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_WATCH),
			tooltip = GetString(SI_PBSCHATASSISTANT_WATCH_TOOLTIP),
			default = true,
			getFunction = function()
				return self.sv.watch
			end,
			setFunction = function(value)
				self.sv.watch = value
				self:ApplyWatch()
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSCHATASSISTANT_LOG),
			tooltip = GetString(SI_PBSCHATASSISTANT_LOG_TOOLTIP),
			default = false,
			getFunction = function()
				return self.sv.log
			end,
			setFunction = function(value)
				self.sv.log = value
			end
		}
	)
end
