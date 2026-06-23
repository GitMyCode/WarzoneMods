require("Util/CommunicationUtil")

---Server_Created hook
---@param game GameServerHook
---@param settings GameSettings
function Server_Created(game, settings)
	if CommRequireBuiltInPrivateMessagingDisabled(Mod.Settings) then
		settings.PrivateMessaging = false
	end

	Mod.PublicGameData = CommEnsurePublicData(Mod.PublicGameData)
end
