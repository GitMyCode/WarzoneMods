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

---Territory-based elimination detector (previous method).
---@param game GameServerHook
---@param playerID PlayerID
---@return boolean
function IsPlayerEliminatedByTerritories(game, playerID)
	return not PlayerOwnsAnyTerritory(game, playerID)
end

---State-based elimination detector.
---Returns all PlayerIDs whose State is not "Playing".
---@param game GameServerHook
---@return PlayerID[]
function IsPlayersEliminatedByState(game)
	local PLAYING = 2

	---@type PlayerID[]
	local eliminated = {}
	for playerID, player in pairs(game.Game.Players) do
		---@type PlayerID
		local pid = playerID
		local state = player and player.State
		print("[Assassin] Checking player " .. tostring(pid) .. " state: " .. tostring(state))
		if state ~= nil and state ~= PLAYING then
			table.insert(eliminated, pid)
		end
	end
	return eliminated
end

---Find the assassin whose target matches the given player.
---@param targetPlayerID PlayerID
---@return PlayerID | nil
function FindAssassinForTarget(targetPlayerID)
	if targetPlayerID == nil then
		return nil
	end
	local playerDataTable = Mod.PlayerGameData
	if playerDataTable == nil then
		return nil
	end
	for assassinID, playerData in pairs(playerDataTable) do
		local targetID = playerData and playerData.Target
		if targetID ~= nil and targetID == targetPlayerID then
			return assassinID
		end
	end
	return nil
end

---Latch the assassin winner when the eliminated target is known.
---@param game GameServerHook
---@param eliminatedTargetID PlayerID
---@return PlayerID | nil
function LatchAssassinWinnerFromEliminatedTarget(game, eliminatedTargetID)
	local publicData = Mod.PublicGameData or {}
	if publicData.AssassinWinnerID ~= nil then
		return publicData.AssassinWinnerID
	end

	local assassinID = FindAssassinForTarget(eliminatedTargetID)
	if assassinID == nil then
		return nil
	end

	publicData.AssassinWinnerID = assassinID
	publicData.AssassinWinnerTargetID = eliminatedTargetID
	Mod.PublicGameData = publicData

	local winner = game.Game.Players[assassinID]
	local target = game.Game.Players[eliminatedTargetID]
	local winnerName = winner and winner.DisplayName(nil, false) or tostring(assassinID)
	local targetName = target and target.DisplayName(nil, false) or tostring(eliminatedTargetID)
	print("[Assassin] Winner latched (state): " .. winnerName .. " eliminated target: " .. targetName)

	return assassinID
end

---@param game GameServerHook
---@return table<PlayerID, integer>
function BuildTerritoryCountByOwner(game)
	local counts = {}
	for _, terr in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		local owner = terr.OwnerPlayerID
		if owner ~= WL.PlayerID.Neutral then
			counts[owner] = (counts[owner] or 0) + 1
		end
	end
	return counts
end

---@param playerID PlayerID
---@param counts table<PlayerID, integer>
---@return boolean
function IsEliminatedByCounts(playerID, counts)
	return playerID ~= nil and (counts[playerID] or 0) == 0
end

-- "Skip-safe / default-unsafe" list: only orders proven not to change ownership are safe.
-- Unknown/new order types are treated as potentially ownership-changing so we won't miss eliminations.
local SAFE_ORDERS = {
	GameOrderDeploy = true,
	GameOrderPurchase = true,

	-- Cards that normally don't change territory ownership
	GameOrderPlayCardSpy = true,
	GameOrderPlayCardReconnaissance = true,
	GameOrderPlayCardSurveillance = true,
	GameOrderPlayCardDiplomacy = true,
	GameOrderPlayCardSanctions = true,
	GameOrderPlayCardReinforcement = true,
	GameOrderPlayCardAirlift = true,
	GameOrderPlayCardBomb = true,
	GameOrderPlayCardFogged = true,

	-- Bookkeeping-ish orders
	GameOrderReceiveCard = true,
	GameOrderDiscard = true,
	ActiveCardWoreOff = true,
}

---@param order GameOrder
---@return boolean
function GameOrderEventChangesOwner(order)
	-- Different proxy versions can expose either TerritoryModifications or TerritoryModificationsOpt
	local mods = order.TerritoryModifications or order.TerritoryModificationsOpt
	if mods == nil then
		return false
	end
	for _, mod in pairs(mods) do
		if mod.SetOwnerOpt ~= nil then
			return true
		end
	end
	return false
end

---@param order GameOrder
---@param orderResult GameOrderResult
---@return boolean
function CouldAffectElimination(order, orderResult)
	if order == nil or order.proxyType == nil then
		return true
	end

	if order.proxyType == "GameOrderAttackTransfer" then
		-- Only successful attacks can change ownership
		return orderResult ~= nil and orderResult.IsAttack == true and orderResult.IsSuccessful == true
	end

	if order.proxyType == "GameOrderPlayCardGift" then
		return true
	end
	if order.proxyType == "GameOrderPlayCardAbandon" then
		return true
	end
	if order.proxyType == "GameOrderPlayCardBlockade" then
		return true
	end

	-- The biggest "don't miss it" category: ownership changes emitted via events
	if order.proxyType == "GameOrderEvent" then
		return GameOrderEventChangesOwner(order)
	end

	-- Custom orders can trigger server-side ownership changes
	if order.proxyType == "GameOrderCustom" then
		return true
	end

	-- Skip safe: only skip if explicitly safe
	return not SAFE_ORDERS[order.proxyType]
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
