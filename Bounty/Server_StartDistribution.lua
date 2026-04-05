---Server_StartDistribution hook
---@param game GameServerHook
---@param standing GameStanding
function Server_StartDistribution(game, standing)
	local publicData = Mod.PublicGameData or {}
	publicData.BountyTrapOwnerByTerritory = publicData.BountyTrapOwnerByTerritory or {}
	Mod.PublicGameData = publicData
end
