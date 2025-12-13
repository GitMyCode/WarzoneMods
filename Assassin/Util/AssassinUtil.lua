require("Annotations")

---Assigns targets to all players in a circular fashion
---@param game GameServerHook
---@return table<PlayerID, PlayerID> # Returns mapping of player -> target
function AssignTargets(game)
	-- Get all playing players (not invited/declined/etc)
	local players = {}
	for playerID, player in pairs(game.Game.PlayingPlayers) do
		table.insert(players, playerID)
	end

	-- Need at least 2 players for targets to make sense
	if #players < 2 then
		return {}
	end

	-- Shuffle players to randomize target assignment
	for i = #players, 2, -1 do
		local j = math.random(i)
		players[i], players[j] = players[j], players[i]
	end

	-- Assign targets in a circular way (each player targets the next one)
	-- This ensures no one has a target that also targets them
	local targets = {}
	for i = 1, #players do
		local player = players[i]
		local target = players[(i % #players) + 1]
		targets[player] = target
	end

	return targets
end

---Check if a player has been eliminated (has no territories)
---@param game GameServerHook
---@param playerID PlayerID
---@return boolean # Returns true if player has no territories
function PlayerOwnsAnyTerritory(game, playerID)
	for _, terr in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		if terr.OwnerPlayerID == playerID then
			return true
		end
	end
	return false
end

function IsPlayerEliminated(game, playerID)
	return not PlayerOwnsAnyTerritory(game, playerID)
end

---Saves the target assignments to Mod.PlayerGameData
---@param targets table<PlayerID, PlayerID>
function SaveTargets(targets)
	local data = Mod.PlayerGameData
	if data == nil then
		data = {}
	end

	for player, target in pairs(targets) do
		if data[player] == nil then
			data[player] = {}
		end
		data[player].Target = target
	end

	Mod.PlayerGameData = data

	print("  SaveTargets: Mod.PlayerGameData is now " .. tostring(Mod.PlayerGameData))
	if Mod.PlayerGameData then
		for pid, pdata in pairs(Mod.PlayerGameData) do
			print("    Player " .. tostring(pid) .. " has target: " .. tostring(pdata.Target or "nil"))
		end
	end
end
