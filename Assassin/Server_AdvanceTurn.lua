require("Util/AssassinUtil")

---End the game (neutralize everyone except the winner).
---When called from _Order, pass the current order/orderResult so we can
---correct for LatestTurnStanding being one order behind (stale).
---When called from _End, pass nil — the standing is fully up-to-date there.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param currentOrder GameOrder | nil
---@param currentOrderResult GameOrderResult | nil
---@return boolean
local function EndGameIfWinnerLatched(game, addNewOrder, currentOrder, currentOrderResult)
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

	-- Neutralize every territory not owned by the winner.
	--
	-- STALE STANDING NOTE: In _Order, LatestTurnStanding is one order behind.
	-- If the winner just captured a territory in the current order, the standing
	-- still shows the old owner. We protect that territory so the winner keeps it.
	-- See ENGINE_FINDINGS.md for the full timing proof.
	local winnerJustCaptured = nil
	if currentOrder and currentOrderResult
		and currentOrder.proxyType == "GameOrderAttackTransfer"
		and currentOrderResult.IsAttack == true
		and currentOrderResult.IsSuccessful == true
		and currentOrder.PlayerID == winnerID then
		winnerJustCaptured = currentOrder.To
		print("[Assassin] Winner just captured terr " .. tostring(winnerJustCaptured)
			.. " (not yet in standing), protecting it")
	end

	local mods = {}
	for _, terr in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		local terrID = terr.ID

		-- Skip territories owned by the winner
		if terr.OwnerPlayerID == winnerID then
			goto continue
		end

		-- Skip the territory the winner just captured (stale standing still shows old owner)
		if winnerJustCaptured and terrID == winnerJustCaptured then
			goto continue
		end

		-- Neutralize everything else — even already-neutral territories.
		-- Redundant but safe: covers every possible edge case.
		local mod = WL.TerritoryModification.Create(terrID)
		mod.SetOwnerOpt = WL.PlayerID.Neutral
		table.insert(mods, mod)

		::continue::
	end

	-- Publish all target assignments so the post-game menu can reveal them.
	-- Keys are PlayerIDs; Warzone serializes them as JSON numbers which
	-- round-trip fine through Mod.PublicGameData.
	local allTargets = {}
	local playerDataTable = Mod.PlayerGameData
	if playerDataTable then
		for pid, pdata in pairs(playerDataTable) do
			if pdata and pdata.Target then
				allTargets[pid] = pdata.Target
			end
		end
	end
	publicData.AllTargets = allTargets

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

	print("[Assassin] Game ending order added with " .. #mods .. " territory modifications")
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
		EndGameIfWinnerLatched(game, addNewOrder, order, orderResult)
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
	EndGameIfWinnerLatched(game, addNewOrder, nil, nil)
end
