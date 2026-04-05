---Server_Created hook
---@param game GameServerHook
---@param settings GameSettings
function Server_Created(game, settings)
	local publicData = Mod.PublicGameData or {}
	publicData.BountyTrapOwnerByTerritory = publicData.BountyTrapOwnerByTerritory or {}
	Mod.PublicGameData = publicData
end
