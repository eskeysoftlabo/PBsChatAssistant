-- Default binds, declared at file scope from the last file the manifest loads.
--
-- The timing is the whole point of this file existing. Called from EVENT_ADD_ON_LOADED, which is
-- where this used to live, CreateDefaultActionBind did nothing: /pbchat binds reported the
-- actions registered at 1/7/1..3 with nothing bound to any of them. By then every file has been
-- read and the binding system has already settled, so a default arriving afterwards has nothing
-- to be the default of.
--
-- Loaded after Bindings.xml instead, the actions exist -- Bindings.xml has just registered them
-- -- and load is still in progress, which is the only window a default can plausibly land in.
--
-- Unproven either way. CreateDefaultActionBind is documented and carries no private or protected
-- marker, but it appears nowhere in the game's own UI source, so there is no known-good example
-- of when or how it is meant to be called. This file holds nothing else, so if the call throws,
-- it takes only itself down.
--
-- L1 + R1 is KEY_GAMEPAD_BOTH_SHOULDERS, key 147, which the client names "L1 + R1". Only NEXT
-- gets a default: the channel list wraps, so one button reaches every channel.
if type(CreateDefaultActionBind) == "function" and KEY_GAMEPAD_BOTH_SHOULDERS then
	CreateDefaultActionBind("PBSCHATASSISTANT_CHANNEL_NEXT", KEY_GAMEPAD_BOTH_SHOULDERS)
end
