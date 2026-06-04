require("Util/BountyReward")

---Server_Created hook
---@param game GameServerHook
---@param settings GameSettings
function Server_Created(game, settings)
	Mod.PublicGameData = BountyEnsurePublicData(Mod.PublicGameData)
end
