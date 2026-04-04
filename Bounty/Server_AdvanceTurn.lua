local DEFAULT_TROOPS_REWARD = 10
local DEFAULT_GOLD_REWARD = 10

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
---@return table<PlayerID, integer>
local function BuildTerritoryCountByOwner(game)
	local counts = {}
	for playerID, _ in pairs(game.Game.Players) do
		counts[playerID] = 0
	end
	for _, terr in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		local owner = terr.OwnerPlayerID
		if owner ~= WL.PlayerID.Neutral and counts[owner] ~= nil then
			counts[owner] = counts[owner] + 1
		end
	end
	return counts
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

---@param game GameServerHook
---@param beforeCounts table<PlayerID, integer>
---@param afterCounts table<PlayerID, integer>
---@return PlayerID[]
local function GetNewlyEliminatedPlayers(game, beforeCounts, afterCounts)
	---@type PlayerID[]
	local eliminated = {}
	for playerID, _ in pairs(game.Game.Players) do
		local beforeCount = beforeCounts[playerID] or 0
		local afterCount = afterCounts[playerID] or 0
		if beforeCount > 0 and afterCount == 0 then
			table.insert(eliminated, playerID)
		end
	end
	table.sort(eliminated)
	return eliminated
end

---@param game GameServerHook
---@param killerID PlayerID | nil
---@param victimID PlayerID
---@param afterCounts table<PlayerID, integer>
---@return boolean
local function IsValidKiller(game, killerID, victimID, afterCounts)
	if killerID == nil or killerID == WL.PlayerID.Neutral then
		return false
	end
	if killerID == victimID then
		return false
	end
	if game.Game.Players[killerID] == nil then
		return false
	end
	if (afterCounts[killerID] or 0) <= 0 then
		return false
	end
	return true
end

---@param order GameOrder
---@param orderResult GameOrderResult
---@param afterOwners table<TerritoryID, PlayerID>
---@return PlayerID | nil
local function ResolveDirectKiller(order, orderResult, afterOwners)
	if order == nil or order.proxyType ~= "GameOrderAttackTransfer" then
		return nil
	end
	if orderResult == nil or orderResult.IsAttack ~= true then
		return nil
	end
	if orderResult.IsSuccessful == true then
		return order.PlayerID
	end
	local toTerritory = order.To
	if toTerritory == nil then
		return nil
	end
	local defenderID = afterOwners[toTerritory]
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
end

---@param game GameServerHook
---@param victimID PlayerID
---@param beforeOwners table<TerritoryID, PlayerID>
---@param afterOwners table<TerritoryID, PlayerID>
---@param trapOwners table<TerritoryID, PlayerID>
---@param afterCounts table<PlayerID, integer>
---@return PlayerID | nil
local function ResolveTrapKiller(game, victimID, beforeOwners, afterOwners, trapOwners, afterCounts)
	local chosenTerritory = nil
	local chosenKiller = nil

	for terrID, previousOwner in pairs(beforeOwners) do
		if previousOwner == victimID and afterOwners[terrID] == WL.PlayerID.Neutral then
			local trapOwner = trapOwners[terrID]
			if IsValidKiller(game, trapOwner, victimID, afterCounts) then
				if chosenTerritory == nil or terrID < chosenTerritory then
					chosenTerritory = terrID
					chosenKiller = trapOwner
				end
			end
		end
	end

	return chosenKiller
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
		return
	end

	local troopsReward = GetNonNegativeIntSetting(Mod.Settings, "FixedTroopsReward", DEFAULT_TROOPS_REWARD)
	if troopsReward <= 0 then
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
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
	local publicData = Mod.PublicGameData or {}
	publicData.BountyPrevOwnerByTerritory = BuildOwnerByTerritory(game)
	publicData.BountyPrevTerritoryCounts = BuildTerritoryCountByOwner(game)
	publicData.BountyTrapOwnerByTerritory = publicData.BountyTrapOwnerByTerritory or {}
	Mod.PublicGameData = publicData
end

---@param game GameServerHook
---@param order GameOrder
---@param orderResult GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
	local publicData = Mod.PublicGameData or {}
	local beforeOwners = publicData.BountyPrevOwnerByTerritory or BuildOwnerByTerritory(game)
	local beforeCounts = publicData.BountyPrevTerritoryCounts or BuildTerritoryCountByOwner(game)
	local trapOwners = publicData.BountyTrapOwnerByTerritory or {}

	local afterOwners = BuildOwnerByTerritory(game)
	local afterCounts = BuildTerritoryCountByOwner(game)

	UpdateTrapOwnershipForOrder(order, afterOwners, trapOwners)

	local eliminatedPlayers = GetNewlyEliminatedPlayers(game, beforeCounts, afterCounts)
	local directKiller = ResolveDirectKiller(order, orderResult, afterOwners)

	for _, victimID in ipairs(eliminatedPlayers) do
		local killerID = nil
		if IsValidKiller(game, directKiller, victimID, afterCounts) then
			killerID = directKiller
		else
			local trapKiller = ResolveTrapKiller(game, victimID, beforeOwners, afterOwners, trapOwners, afterCounts)
			if IsValidKiller(game, trapKiller, victimID, afterCounts) then
				killerID = trapKiller
			end
		end

		if killerID ~= nil then
			GrantEliminationReward(game, killerID, victimID, addNewOrder)
		end
	end

	publicData.BountyPrevOwnerByTerritory = afterOwners
	publicData.BountyPrevTerritoryCounts = afterCounts
	publicData.BountyTrapOwnerByTerritory = trapOwners
	Mod.PublicGameData = publicData
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
	local publicData = Mod.PublicGameData or {}
	publicData.BountyPrevOwnerByTerritory = BuildOwnerByTerritory(game)
	publicData.BountyPrevTerritoryCounts = BuildTerritoryCountByOwner(game)
	publicData.BountyTrapOwnerByTerritory = publicData.BountyTrapOwnerByTerritory or {}
	Mod.PublicGameData = publicData
end
