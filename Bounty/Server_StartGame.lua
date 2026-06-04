require("Util/BountyReward")

---Server_StartGame hook
---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
	Mod.PublicGameData = BountyEnsurePublicData(Mod.PublicGameData)
end
