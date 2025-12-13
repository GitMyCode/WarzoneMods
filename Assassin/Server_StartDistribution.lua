require("Annotations")
require("Util/AssassinUtil")

---Server_StartDistribution hook
---@param game GameServerHook
---@param standing GameStanding
function Server_StartDistribution(game, standing)
	local publicData = Mod.PublicGameData
	if publicData == nil then
		publicData = {}
	end
	if publicData.AssassinTargetsAssigned then
		return
	end

	-- Initialize PlayerGameData for all players
	local playerData = Mod.PlayerGameData
	if playerData == nil then
		playerData = {}
	end

	-- Initialize each player's data
	for playerID, _ in pairs(game.Game.PlayingPlayers) do
		if playerData[playerID] == nil then
			playerData[playerID] = {}
		end
	end

	Mod.PlayerGameData = playerData

	-- Assign targets
	local targets = AssignTargets(game)
	if next(targets) ~= nil then
		SaveTargets(targets)
		publicData.AssassinTargetsAssigned = true
		Mod.PublicGameData = publicData
	end
end
