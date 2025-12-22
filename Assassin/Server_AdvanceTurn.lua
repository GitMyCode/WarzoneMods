require("Util/AssassinUtil")

---Latch winner when a target is eliminated (territory-based)
---@param game GameServerHook
---@return PlayerID | nil
local function LatchAssassinWinnerIfAny(game)
	local publicData = Mod.PublicGameData or {}
	if publicData.AssassinWinnerID ~= nil then
		return publicData.AssassinWinnerID
	end

	local playerDataTable = Mod.PlayerGameData
	if playerDataTable == nil then
		return nil
	end

	local territoryCounts = BuildTerritoryCountByOwner(game)
	for assassinID, playerData in pairs(playerDataTable) do
		local targetID = playerData and playerData.Target
		if targetID ~= nil and IsEliminatedByCounts(targetID, territoryCounts) then
			publicData.AssassinWinnerID = assassinID
			publicData.AssassinWinnerTargetID = targetID
			Mod.PublicGameData = publicData

			local winner = game.Game.Players[assassinID]
			local target = game.Game.Players[targetID]
			local winnerName = winner and winner.DisplayName(nil, false) or tostring(assassinID)
			local targetName = target and target.DisplayName(nil, false) or tostring(targetID)
			print("[Assassin] Winner latched: " .. winnerName .. " eliminated target: " .. targetName)

			return assassinID
		end
	end

	return nil
end

---End the game (neutralize everyone except the winner)
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@return boolean
local function EndGameIfWinnerLatched(game, addNewOrder)
	local publicData = Mod.PublicGameData or {}
	local winnerID = publicData.AssassinWinnerID
	local targetID = publicData.AssassinWinnerTargetID
	if winnerID == nil then
		return false
	end
	if publicData.AssassinGameEnded then
		return true
	end

	local winner = game.Game.Players[winnerID]
	if winner == nil then
		return false
	end
	local target = targetID and game.Game.Players[targetID] or nil
	local targetName = target and target.DisplayName(nil, false) or (targetID and tostring(targetID) or "their target")

	local mods = {}
	for _, terr in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		if terr.OwnerPlayerID ~= WL.PlayerID.Neutral and terr.OwnerPlayerID ~= winnerID then
			local mod = WL.TerritoryModification.Create(terr.ID)
			mod.SetOwnerOpt = WL.PlayerID.Neutral
			table.insert(mods, mod)
		end
	end

	publicData.AssassinGameEnded = true
	Mod.PublicGameData = publicData

	addNewOrder(
		WL.GameOrderEvent.Create(
			WL.PlayerID.Neutral,
			"ASSASSIN WIN! "
				.. winner.DisplayName(nil, false)
				.. " has eliminated "
				.. targetName
				.. " and wins the game!",
			nil,
			mods
		)
	)

	print("[Assassin] Game ending order added")
	return true
end

-- Safe field read (won't explode if field doesn't exist on this proxy type)
local function _tryGet(obj, fieldName)
	local ok, val = pcall(function()
		return obj[fieldName]
	end)
	if ok then
		return val
	end
	return nil
end

---Server_AdvanceTurn_Start hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Start(game, addNewOrder)
	-- No per-turn reset; winner is latched in Mod.PublicGameData and game ends in Server_AdvanceTurn_End
	if Mod.PublicGameData == nil then
		Mod.PublicGameData = {}
	end
end

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param orderResult GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
	-- Latch as soon as possible, but avoid work for orders proven "safe".
	if CouldAffectElimination(order, orderResult) then
		LatchAssassinWinnerIfAny(game)
	end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	-- Final latch (covers surrender/boot/etc) and end game safely (do NOT link to an order)
	LatchAssassinWinnerIfAny(game)
	EndGameIfWinnerLatched(game, addNewOrder)
end
