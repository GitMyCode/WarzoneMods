local DEFAULT_TROOPS_REWARD = 10
local DEFAULT_GOLD_REWARD = 10

---@param message string
local function Log(message)
	print("[Bounty] " .. message)
end

---@param a PlayerID | nil
---@param b PlayerID | nil
---@return boolean
local function SamePlayerID(a, b)
	if a == nil or b == nil then
		return false
	end
	if a == b then
		return true
	end
	return tostring(a) == tostring(b)
end

---@param counts table
---@param playerID PlayerID | nil
---@return integer
local function CountForPlayer(counts, playerID)
	if counts == nil or playerID == nil then
		return 0
	end

	local value = counts[playerID]
	if value ~= nil then
		return value
	end

	local str = tostring(playerID)
	value = counts[str]
	if value ~= nil then
		return value
	end

	local num = tonumber(str)
	if num ~= nil then
		value = counts[num]
		if value ~= nil then
			return value
		end
	end

	return 0
end

---@param game GameServerHook
---@param playerID PlayerID
---@return string
local function PlayerName(game, playerID)
	if playerID == nil then
		return "nil"
	end
	if playerID == WL.PlayerID.Neutral then
		return "Neutral"
	end
	local player = game.Game.Players[playerID]
	if player == nil then
		return tostring(playerID)
	end
	return player.DisplayName(nil, false)
end

---@param game GameServerHook
---@return table<TerritoryID, PlayerID>
local function BuildOwnerByTerritory(game)
	local owners = {}
	for terrID, terr in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		owners[terrID] = terr.OwnerPlayerID
	end
	return owners
end

---@param game GameServerHook
---@param owners table<TerritoryID, PlayerID>
---@return table<PlayerID, integer>
local function BuildCountsFromOwnerMap(game, owners)
	local counts = {}
	for playerID, _ in pairs(game.Game.Players) do
		counts[playerID] = 0
	end
	for _, ownerID in pairs(owners) do
		if ownerID ~= WL.PlayerID.Neutral and counts[ownerID] ~= nil then
			counts[ownerID] = counts[ownerID] + 1
		end
	end
	return counts
end

--- Manually deduce afterOwners from beforeOwners + the current order's effect.
--- This avoids reading LatestTurnStanding, which is one order behind in _Order.
---@param beforeOwners table<TerritoryID, PlayerID>
---@param order GameOrder
---@param orderResult GameOrderResult
---@return table<TerritoryID, PlayerID>
local function BuildAfterOwners(beforeOwners, order, orderResult)
	-- Start with a shallow copy
	local after = {}
	for terrID, ownerID in pairs(beforeOwners) do
		after[terrID] = ownerID
	end

	if order == nil then
		return after
	end

	-- Successful attack: attacker takes the target territory
	if order.proxyType == "GameOrderAttackTransfer" then
		if orderResult ~= nil and orderResult.IsAttack == true and orderResult.IsSuccessful == true then
			after[order.To] = order.PlayerID
		end
		return after
	end

	-- Blockade or Abandon: territory becomes Neutral
	if order.proxyType == "GameOrderPlayCardBlockade" or order.proxyType == "GameOrderPlayCardAbandon" then
		local terrID = order.TargetTerritoryID
		if terrID ~= nil then
			after[terrID] = WL.PlayerID.Neutral
		end
		return after
	end

	return after
end

---@param settings table
---@param key string
---@param defaultValue integer
---@return integer
local function GetNonNegativeIntSetting(settings, key, defaultValue)
	local value = settings and settings[key] or nil
	if type(value) ~= "number" then
		return defaultValue
	end
	value = math.floor(value)
	if value < 0 then
		return defaultValue
	end
	return value
end

---@param game GameServerHook
---@return boolean
local function IsCommerceGame(game)
	return game ~= nil and game.Settings ~= nil and game.Settings.CommerceGame == true
end

---@param order GameOrder
---@param orderResult GameOrderResult
---@param beforeOwners table<TerritoryID, PlayerID>
---@param victimID PlayerID
---@return PlayerID | nil
local function ResolveOrderKillerForVictim(order, orderResult, beforeOwners, victimID)
	if order == nil or order.proxyType ~= "GameOrderAttackTransfer" then
		return nil
	end
	if orderResult == nil or orderResult.IsAttack ~= true then
		return nil
	end

	local toTerritory = order.To
	if toTerritory == nil then
		return nil
	end

	-- Successful attack: attacker took a territory from the victim
	if orderResult.IsSuccessful == true then
		local previousOwner = beforeOwners[toTerritory]
		if not SamePlayerID(previousOwner, victimID) then
			return nil
		end
		return order.PlayerID
	end

	-- Failed attack: if the attacker IS the victim, the defender gets credit
	if not SamePlayerID(order.PlayerID, victimID) then
		return nil
	end
	local defenderID = beforeOwners[toTerritory]
	if defenderID == nil or defenderID == WL.PlayerID.Neutral then
		return nil
	end
	return defenderID
end

---@param trapOwners table<TerritoryID, PlayerID>
---@param afterOwners table<TerritoryID, PlayerID>
local function ClearConqueredTraps(trapOwners, afterOwners)
	for terrID, trapOwner in pairs(trapOwners) do
		local owner = afterOwners[terrID]
		if owner == nil or owner ~= WL.PlayerID.Neutral or trapOwner == nil or trapOwner == WL.PlayerID.Neutral then
			if trapOwner ~= nil then
				Log("Cleared trap on territory " .. tostring(terrID))
			end
			trapOwners[terrID] = nil
		end
	end
end

---@param order GameOrder
---@param afterOwners table<TerritoryID, PlayerID>
---@param trapOwners table<TerritoryID, PlayerID>
local function UpdateTrapOwnershipForOrder(order, afterOwners, trapOwners)
	ClearConqueredTraps(trapOwners, afterOwners)

	if order == nil then
		return
	end

	if order.proxyType ~= "GameOrderPlayCardBlockade" and order.proxyType ~= "GameOrderPlayCardAbandon" then
		return
	end

	local terrID = order.TargetTerritoryID
	if terrID == nil then
		return
	end
	if afterOwners[terrID] ~= WL.PlayerID.Neutral then
		return
	end
	if order.PlayerID == nil or order.PlayerID == WL.PlayerID.Neutral then
		return
	end

	trapOwners[terrID] = order.PlayerID
	Log("Trap set on territory " .. tostring(terrID) .. " by " .. tostring(order.PlayerID))
end

--- Check if the victim died by attacking a trapped territory.
--- This handles commander cascades: victim attacks a blockaded Neutral territory,
--- commander dies in the battle, engine cascades all victim's territories to Neutral.
--- BuildAfterOwners can't see the cascade, but we know the victim attacked a trap.
---@param game GameServerHook
---@param order GameOrder
---@param victimID PlayerID
---@param trapOwners table<TerritoryID, PlayerID>
---@return PlayerID | nil
local function ResolveTrapKiller(game, order, victimID, trapOwners)
	if order == nil or order.proxyType ~= "GameOrderAttackTransfer" then
		return nil
	end
	-- Victim must be the attacker (they died attacking the trap)
	if not SamePlayerID(order.PlayerID, victimID) then
		return nil
	end
	local targetTerr = order.To
	if targetTerr == nil then
		return nil
	end
	local trapOwner = trapOwners[targetTerr]
	if trapOwner == nil or SamePlayerID(trapOwner, victimID) or trapOwner == WL.PlayerID.Neutral then
		return nil
	end
	if game.Game.Players[trapOwner] == nil then
		return nil
	end
	return trapOwner
end

---@param game GameServerHook
---@param killerID PlayerID
---@param victimID PlayerID
---@param addNewOrder fun(order: GameOrder)
local function GrantEliminationReward(game, killerID, victimID, addNewOrder)
	local killer = game.Game.Players[killerID]
	local victim = game.Game.Players[victimID]
	local killerName = killer and killer.DisplayName(nil, false) or tostring(killerID)
	local victimName = victim and victim.DisplayName(nil, false) or tostring(victimID)

	if IsCommerceGame(game) then
		local goldReward = GetNonNegativeIntSetting(Mod.Settings, "FixedGoldReward", DEFAULT_GOLD_REWARD)
		if goldReward <= 0 then
			Log("Skipped gold reward (configured amount is 0)")
			return
		end

		local rewardOrder = WL.GameOrderEvent.Create(
			killerID,
			"Bounty: " .. killerName .. " earned +" .. tostring(goldReward) .. " gold for eliminating " .. victimName,
			nil,
			nil,
			nil,
			nil
		)
		rewardOrder.AddResourceOpt = {
			[killerID] = {
				[WL.ResourceType.Gold] = goldReward,
			},
		}
		addNewOrder(rewardOrder)
		Log("REWARD: +" .. tostring(goldReward) .. " gold to " .. killerName .. " for eliminating " .. victimName)
		return
	end

	local troopsReward = GetNonNegativeIntSetting(Mod.Settings, "FixedTroopsReward", DEFAULT_TROOPS_REWARD)
	if troopsReward <= 0 then
		Log("Skipped troops reward (configured amount is 0)")
		return
	end

	local reinforcement = WL.ReinforcementCardInstance.Create(troopsReward)
	addNewOrder(WL.GameOrderReceiveCard.Create(killerID, { reinforcement }))
	addNewOrder(
		WL.GameOrderEvent.Create(
			killerID,
			"Bounty: " .. killerName .. " earned +" .. tostring(troopsReward) .. " troops for eliminating " .. victimName,
			nil,
			nil,
			nil,
			nil
		)
	)
	Log("REWARD: +" .. tostring(troopsReward) .. " troops to " .. killerName .. " for eliminating " .. victimName)
end

-- ============================================================================
-- HOOKS
-- ============================================================================

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
	Log("=== Turn Start ===")
	local publicData = Mod.PublicGameData or {}
	publicData.BountyPrevOwnerByTerritory = BuildOwnerByTerritory(game)
	publicData.BountyTrapOwnerByTerritory = publicData.BountyTrapOwnerByTerritory or {}
	publicData.BountyProcessedEliminations = publicData.BountyProcessedEliminations or {}
	publicData.BountyLastAttackerByVictim = {} -- reset per-turn tracking
	Mod.PublicGameData = publicData

	-- Log initial territory counts
	local counts = BuildCountsFromOwnerMap(game, publicData.BountyPrevOwnerByTerritory)
	for playerID, count in pairs(counts) do
		Log("  " .. PlayerName(game, playerID) .. " owns " .. tostring(count) .. " territories")
	end
end

---@param game GameServerHook
---@param order GameOrder
---@param orderResult GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
	-- Log FIRST before touching any order fields that might crash
	Log("--- Order: " .. tostring(order and order.proxyType or "???") .. " by " .. tostring(order and order.PlayerID or "???"))

	local publicData = Mod.PublicGameData or {}
	local beforeOwners = publicData.BountyPrevOwnerByTerritory or BuildOwnerByTerritory(game)
	local trapOwners = publicData.BountyTrapOwnerByTerritory or {}
	local processedEliminations = publicData.BountyProcessedEliminations or {}
	local lastAttackerByVictim = publicData.BountyLastAttackerByVictim or {}

	-- === DIAGNOSTIC: log every player's State on every _Order call ===
	-- This answers: does player.State update immediately on the same _Order
	-- call where a commander cascade happens, or is it delayed?
	for playerID, player in pairs(game.Game.Players) do
		Log("  [DIAG] " .. PlayerName(game, playerID)
			.. " State=" .. tostring(player.State)
			.. " territories(beforeOwners)=" .. tostring(CountForPlayer(BuildCountsFromOwnerMap(game, beforeOwners), playerID)))
	end

	-- Log attack details if applicable
	if order ~= nil and order.proxyType == "GameOrderAttackTransfer" then
		local toTerr = order.To
		local fromTerr = order.From
		local isAttack = orderResult and orderResult.IsAttack
		local isSuccessful = orderResult and orderResult.IsSuccessful
		local defenderID = toTerr and beforeOwners[toTerr] or nil
		Log("  Attack/Transfer: from=" .. tostring(fromTerr) .. " to=" .. tostring(toTerr)
			.. " defender=" .. tostring(defenderID)
			.. " isAttack=" .. tostring(isAttack) .. " isSuccessful=" .. tostring(isSuccessful))
	end

	-- Manually deduce afterOwners from beforeOwners + order effect.
	-- We cannot use LatestTurnStanding here because it is one order behind.
	local afterOwners = BuildAfterOwners(beforeOwners, order, orderResult)

	-- Log ownership changes from this order
	for terrID, newOwner in pairs(afterOwners) do
		local prev = beforeOwners[terrID]
		if prev ~= nil and not SamePlayerID(prev, newOwner) then
			Log("  Ownership change: territory " .. tostring(terrID)
				.. " " .. tostring(prev) .. " -> " .. tostring(newOwner))
		end
	end

	-- Track last attacker per victim (for _End fallback)
	if order ~= nil and order.proxyType == "GameOrderAttackTransfer" then
		if orderResult ~= nil and orderResult.IsAttack == true and orderResult.IsSuccessful == true then
			local victimOfOrder = beforeOwners[order.To]
			if victimOfOrder ~= nil and victimOfOrder ~= WL.PlayerID.Neutral then
				lastAttackerByVictim[tostring(victimOfOrder)] = order.PlayerID
				Log("  Tracked last attacker of " .. tostring(victimOfOrder) .. " = " .. tostring(order.PlayerID))
			end
		end
	end

	local beforeCounts = BuildCountsFromOwnerMap(game, beforeOwners)
	local afterCounts = BuildCountsFromOwnerMap(game, afterOwners)

	UpdateTrapOwnershipForOrder(order, afterOwners, trapOwners)

	-- === Elimination Detection ===

	---@type PlayerID[]
	local eliminatedPlayers = {}

	-- Method 1: Territory count comparison (beforeCount > 0 and afterCount == 0)
	for playerID, _ in pairs(game.Game.Players) do
		local pidStr = tostring(playerID)
		if not processedEliminations[pidStr] then
			local bc = CountForPlayer(beforeCounts, playerID)
			local ac = CountForPlayer(afterCounts, playerID)
			if bc > 0 and ac == 0 then
				table.insert(eliminatedPlayers, playerID)
				processedEliminations[pidStr] = true
				Log("  ELIMINATED (territory count): " .. PlayerName(game, playerID)
					.. " (" .. tostring(bc) .. " -> " .. tostring(ac) .. ")")
			end
		end
	end

	-- Method 2: player.State check (handles commander cascades, boots, etc.)
	for playerID, player in pairs(game.Game.Players) do
		local pidStr = tostring(playerID)
		if not processedEliminations[pidStr] then
			local state = player.State
			if state ~= nil and state ~= 2 then -- not Playing
				table.insert(eliminatedPlayers, playerID)
				processedEliminations[pidStr] = true
				Log("  ELIMINATED (player.State=" .. tostring(state) .. "): " .. PlayerName(game, playerID))
			end
		end
	end

	table.sort(eliminatedPlayers, function(a, b)
		return tostring(a) < tostring(b)
	end)

	-- === Kill Attribution & Rewards ===

	for _, victimID in ipairs(eliminatedPlayers) do
		Log("  Resolving killer for victim: " .. PlayerName(game, victimID))
		local killerID = nil

		-- Try attribution from the current order
		local orderKiller = ResolveOrderKillerForVictim(order, orderResult, beforeOwners, victimID)
		if orderKiller ~= nil
			and not SamePlayerID(orderKiller, victimID)
			and orderKiller ~= WL.PlayerID.Neutral
			and game.Game.Players[orderKiller] ~= nil
		then
			killerID = orderKiller
			Log("    -> Killer from order: " .. PlayerName(game, killerID))
		end

		-- Try trap attribution
		if killerID == nil then
			local trapKiller = ResolveTrapKiller(game, order, victimID, trapOwners)
			if trapKiller ~= nil then
				killerID = trapKiller
				Log("    -> Killer from trap: " .. PlayerName(game, killerID))
			end
		end

		-- Try last-attacker fallback
		if killerID == nil then
			local lastAttacker = lastAttackerByVictim[tostring(victimID)]
			if lastAttacker ~= nil
				and not SamePlayerID(lastAttacker, victimID)
				and lastAttacker ~= WL.PlayerID.Neutral
				and game.Game.Players[lastAttacker] ~= nil
			then
				killerID = lastAttacker
				Log("    -> Killer from last-attacker tracking: " .. PlayerName(game, killerID))
			end
		end

		if killerID ~= nil then
			GrantEliminationReward(game, killerID, victimID, addNewOrder)
		else
			Log("    -> NO KILLER FOUND for " .. PlayerName(game, victimID) .. "; no bounty")
		end
	end

	-- Save state
	publicData.BountyPrevOwnerByTerritory = afterOwners
	publicData.BountyTrapOwnerByTerritory = trapOwners
	publicData.BountyProcessedEliminations = processedEliminations
	publicData.BountyLastAttackerByVictim = lastAttackerByVictim
	Mod.PublicGameData = publicData
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
	Log("=== Turn End ===")
	local publicData = Mod.PublicGameData or {}
	local processedEliminations = publicData.BountyProcessedEliminations or {}
	local lastAttackerByVictim = publicData.BountyLastAttackerByVictim or {}

	-- Final sweep: catch any eliminations missed during _Order
	local missedAny = false
	for playerID, player in pairs(game.Game.Players) do
		local pidStr = tostring(playerID)
		if not processedEliminations[pidStr] then
			local state = player.State
			if state ~= nil and state ~= 2 then
				missedAny = true
				processedEliminations[pidStr] = true
				Log("  LATE elimination in _End: " .. PlayerName(game, playerID) .. " (state=" .. tostring(state) .. ")")

				local killerID = lastAttackerByVictim[pidStr]
				if killerID ~= nil
					and not SamePlayerID(killerID, playerID)
					and killerID ~= WL.PlayerID.Neutral
					and game.Game.Players[killerID] ~= nil
				then
					Log("  Late attribution: " .. PlayerName(game, killerID))
					GrantEliminationReward(game, killerID, playerID, addNewOrder)
				else
					Log("  No attribution available for late elimination of " .. PlayerName(game, playerID))
				end
			end
		end
	end

	if not missedAny then
		Log("  No missed eliminations")
	end

	-- Save clean state for next turn
	publicData.BountyPrevOwnerByTerritory = BuildOwnerByTerritory(game)
	publicData.BountyTrapOwnerByTerritory = publicData.BountyTrapOwnerByTerritory or {}
	publicData.BountyProcessedEliminations = processedEliminations
	Mod.PublicGameData = publicData
end
