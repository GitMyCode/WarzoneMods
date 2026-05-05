require("Util/AssassinUtil")

---End the game (neutralize everyone except the winner).
---Since we always skipThisOrder in _Order before calling this, the standing
---is never stale — no current-order correction is needed.
---In _End the standing is also fully up-to-date.
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

	-- Neutralize every territory not owned by the winner.
	local mods = {}
	for _, terr in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		if terr.OwnerPlayerID ~= winnerID then
			local mod = WL.TerritoryModification.Create(terr.ID)
			mod.SetOwnerOpt = WL.PlayerID.Neutral
			table.insert(mods, mod)
		end
	end

	-- Safety: explicitly re-stamp all winner territories back to the winner.
	-- This is redundant but guarantees the winner keeps their land even if
	-- another mod's GameOrderEvent or an edge case removed them from the map.
	for _, terr in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		if terr.OwnerPlayerID == winnerID then
			local mod = WL.TerritoryModification.Create(terr.ID)
			mod.SetOwnerOpt = winnerID
			table.insert(mods, mod)
		end
	end

	-- Publish all target assignments so the post-game menu can reveal them.
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
	local publicData = Mod.PublicGameData or {}

	-- If the game has already ended, skip all remaining player orders.
	-- Let GameOrderEvents through — our neutralization event may re-trigger _Order.
	if publicData.AssassinGameEnded then
		if order.proxyType ~= "GameOrderEvent" then
			print("[Assassin] Game already ended, skipping order: " .. tostring(order.proxyType))
			skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage)
		end
		return
	end

	-- If a winner is latched but the game-ending event hasn't been emitted yet,
	-- skip all remaining orders until we can emit from _End.
	if publicData.AssassinWinnerID ~= nil then
		if order.proxyType ~= "GameOrderEvent" then
			print("[Assassin] Winner latched, skipping order: " .. tostring(order.proxyType))
			skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage)
		end
		return
	end

	-- Check for newly eliminated players (target detection).
	local eliminatedTargets = IsPlayersEliminatedByState(game)
	print("[Assassin] Eliminated targets this order check: " .. tostring(#eliminatedTargets))

	-- Try to latch a winner from any eliminated target.
	for _, eliminatedTargetID in ipairs(eliminatedTargets) do
		local assassinID = LatchAssassinWinnerFromEliminatedTarget(game, eliminatedTargetID)
		if assassinID ~= nil then
			break
		end
	end

	-- If we just latched a winner, skip the current order (prevents the winner
	-- from being killed by their own fatal order) and emit the game-ending event.
	-- Re-read publicData since LatchAssassinWinnerFromEliminatedTarget writes
	-- directly to Mod.PublicGameData.
	publicData = Mod.PublicGameData or {}
	if publicData.AssassinWinnerID ~= nil then
		print("[Assassin] Winner detected in _Order, skipping current order and ending game")
		skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage)
		EndGameIfWinnerLatched(game, addNewOrder)
		return
	end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	-- Fallback: iterate all eliminated targets in case _Order missed any
	-- (e.g. GameOrderStateTransition doesn't fire _Order).
	local eliminatedTargets = IsPlayersEliminatedByState(game)
	for _, eliminatedTargetID in ipairs(eliminatedTargets) do
		local assassinID = LatchAssassinWinnerFromEliminatedTarget(game, eliminatedTargetID)
		if assassinID ~= nil then
			break
		end
	end
	EndGameIfWinnerLatched(game, addNewOrder)
end
