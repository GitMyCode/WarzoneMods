require("Util/BountyReward")

---Server_StartDistribution hook
---@param game GameServerHook
---@param standing GameStanding
function Server_StartDistribution(game, standing)
	Mod.PublicGameData = BountyEnsurePublicData(Mod.PublicGameData)
end
