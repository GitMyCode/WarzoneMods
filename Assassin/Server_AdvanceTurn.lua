require("Util/AssassinUtil")

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
	local eliminatedTargets = IsPlayersEliminatedByState(game)
	print("[Assassin] Eliminated targets this order check: " .. tostring(#eliminatedTargets))
	local eliminatedTargetID = eliminatedTargets[1]
	if eliminatedTargetID ~= nil then
		LatchAssassinWinnerFromEliminatedTarget(game, eliminatedTargetID)
		EndGameIfWinnerLatched(game, addNewOrder)
	end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	local eliminatedTargets = IsPlayersEliminatedByState(game)
	local eliminatedTargetID = eliminatedTargets[1]
	if eliminatedTargetID ~= nil then
		LatchAssassinWinnerFromEliminatedTarget(game, eliminatedTargetID)
	end
	EndGameIfWinnerLatched(game, addNewOrder)
end
