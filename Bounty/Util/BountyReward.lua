BOUNTY_DEFAULT_REWARD = 20

BOUNTY_REWARD_MODE_FIXED = "fixed"
BOUNTY_REWARD_MODE_GLOBAL_GROWTH = "globalGrowth"
BOUNTY_REWARD_MODE_KILL_COUNT = "killCount"
BOUNTY_REWARD_MODE_INHERITANCE = "inheritance"

-- Legacy values from previous iterations.
BOUNTY_REWARD_MODE_ESCALATING = "escalating"
BOUNTY_REWARD_MODE_KILLER_BOUNTY = "killerBounty"

BOUNTY_GROWTH_TYPE_FLAT = "flat"
BOUNTY_GROWTH_TYPE_PERCENT = "percent"

BOUNTY_DEFAULT_GROWTH_FLAT_AMOUNT = 25
BOUNTY_DEFAULT_GROWTH_PERCENT = 20
BOUNTY_PREVIEW_REWARD_COUNT = 5
BOUNTY_MAX_REWARD = 100000
BOUNTY_MAX_GROWTH_FLAT_AMOUNT = 100000
BOUNTY_MAX_GROWTH_PERCENT = 1000

---@param value any
---@param fallback number
---@return number
function BountyReadNonNegativeNumber(value, fallback)
	if type(value) ~= "number" then
		return fallback
	end
	if value < 0 then
		return fallback
	end
	return value
end

---@param value any
---@param fallback integer
---@return integer
function BountyReadNonNegativeInt(value, fallback)
	local number = BountyReadNonNegativeNumber(value, fallback)
	return math.floor(number)
end

---@param settings table | nil
---@return string
function BountyGetRewardMode(settings)
	local mode = settings and settings.BountyRewardMode or nil
	if mode == BOUNTY_REWARD_MODE_GLOBAL_GROWTH or mode == BOUNTY_REWARD_MODE_ESCALATING then
		return BOUNTY_REWARD_MODE_GLOBAL_GROWTH
	end
	if mode == BOUNTY_REWARD_MODE_KILL_COUNT or mode == BOUNTY_REWARD_MODE_KILLER_BOUNTY then
		return BOUNTY_REWARD_MODE_KILL_COUNT
	end
	if mode == BOUNTY_REWARD_MODE_INHERITANCE then
		return BOUNTY_REWARD_MODE_INHERITANCE
	end
	return BOUNTY_REWARD_MODE_FIXED
end

---@param settings table | nil
---@return string
function BountyGetGrowthType(settings)
	local growthType = settings and settings.BountyGrowthType or nil
	if growthType == BOUNTY_GROWTH_TYPE_PERCENT then
		return BOUNTY_GROWTH_TYPE_PERCENT
	end
	if growthType == BOUNTY_GROWTH_TYPE_FLAT then
		return BOUNTY_GROWTH_TYPE_FLAT
	end

	-- Migration path for games configured while the only growing mode was percent-based global escalation.
	if settings ~= nil and settings.BountyRewardMode == BOUNTY_REWARD_MODE_ESCALATING then
		return BOUNTY_GROWTH_TYPE_PERCENT
	end
	if settings ~= nil
		and settings.BountyEscalationPercent ~= nil
		and settings.BountyGrowthFlatAmount == nil
		and settings.BountyKillerBountyIncrease == nil
	then
		return BOUNTY_GROWTH_TYPE_PERCENT
	end

	return BOUNTY_GROWTH_TYPE_FLAT
end

---@param settings table | nil
---@return integer
function BountyGetBaseReward(settings)
	return BountyReadNonNegativeInt(settings and settings.BountyReward or nil, BOUNTY_DEFAULT_REWARD)
end

---@param settings table | nil
---@return integer
function BountyGetGrowthFlatAmount(settings)
	if settings == nil then
		return BOUNTY_DEFAULT_GROWTH_FLAT_AMOUNT
	end

	local value = settings.BountyGrowthFlatAmount
	if value == nil then
		-- Migration path for the first killer-bounty-growth implementation.
		value = settings.BountyKillerBountyIncrease
	end

	return BountyReadNonNegativeInt(value, BOUNTY_DEFAULT_GROWTH_FLAT_AMOUNT)
end

---@param settings table | nil
---@return integer
function BountyGetKillerBountyIncrease(settings)
	return BountyGetGrowthFlatAmount(settings)
end

---@param settings table | nil
---@return integer
function BountyGetGrowthPercent(settings)
	if settings == nil then
		return BOUNTY_DEFAULT_GROWTH_PERCENT
	end

	local value = settings.BountyGrowthPercent
	if value == nil then
		-- Migration path for the original global escalating bounty setting.
		value = settings.BountyEscalationPercent
	end

	return BountyReadNonNegativeInt(value, BOUNTY_DEFAULT_GROWTH_PERCENT)
end

---@param publicData table | nil
---@return integer
function BountyGetGlobalBountyCount(publicData)
	return BountyReadNonNegativeInt(publicData and publicData.BountyEscalatingRewardCount or nil, 0)
end

---@param publicData table | nil
---@return table
function BountyGetKillCountsByPlayer(publicData)
	if publicData == nil then
		return {}
	end
	publicData.BountyKillCountsByPlayer = publicData.BountyKillCountsByPlayer or {}
	return publicData.BountyKillCountsByPlayer
end

---@param publicData table | nil
---@return table
function BountyGetInheritedBountiesByPlayer(publicData)
	if publicData == nil then
		return {}
	end
	publicData.BountyInheritedBountyByPlayer = publicData.BountyInheritedBountyByPlayer or {}
	return publicData.BountyInheritedBountyByPlayer
end

---@param publicData table | nil
---@return table
function BountyEnsurePublicData(publicData)
	publicData = publicData or {}
	publicData.BountyTrapOwnerByTerritory = publicData.BountyTrapOwnerByTerritory or {}
	publicData.BountyEscalatingRewardCount = BountyGetGlobalBountyCount(publicData)
	publicData.BountyKillCountsByPlayer = publicData.BountyKillCountsByPlayer or {}
	publicData.BountyInheritedBountyByPlayer = publicData.BountyInheritedBountyByPlayer or {}
	return publicData
end

---@param counts table | nil
---@param playerID PlayerID | nil
---@return integer
local function BountyReadPlayerCount(counts, playerID)
	if counts == nil or playerID == nil then
		return 0
	end

	local value = counts[tostring(playerID)]
	if value ~= nil then
		return BountyReadNonNegativeInt(value, 0)
	end

	value = counts[playerID]
	if value ~= nil then
		return BountyReadNonNegativeInt(value, 0)
	end

	local num = tonumber(tostring(playerID))
	if num ~= nil then
		value = counts[num]
		if value ~= nil then
			return BountyReadNonNegativeInt(value, 0)
		end
	end

	return 0
end

---@param publicData table | nil
---@param playerID PlayerID | nil
---@return integer
function BountyGetPlayerKillCount(publicData, playerID)
	return BountyReadPlayerCount(publicData and publicData.BountyKillCountsByPlayer or nil, playerID)
end

---@param publicData table
---@param playerID PlayerID | nil
---@return integer
function BountyRecordKillForPlayer(publicData, playerID)
	if playerID == nil then
		return 0
	end

	publicData = BountyEnsurePublicData(publicData)
	local count = BountyGetPlayerKillCount(publicData, playerID) + 1
	publicData.BountyKillCountsByPlayer[tostring(playerID)] = count
	return count
end

---@param publicData table
---@return integer
function BountyRecordGlobalBountyIncrease(publicData)
	publicData = BountyEnsurePublicData(publicData)
	publicData.BountyEscalatingRewardCount = BountyGetGlobalBountyCount(publicData) + 1
	return publicData.BountyEscalatingRewardCount
end

---@param value number
---@return integer
function BountyRoundNearest(value)
	value = BountyReadNonNegativeNumber(value, 0)
	return math.floor(value + 0.5)
end

---@param base number
---@param growthType string
---@param flatAmount number
---@param percent number
---@param count integer
---@return integer
function BountyCalculateGrowthValue(base, growthType, flatAmount, percent, count)
	base = BountyReadNonNegativeInt(base, BOUNTY_DEFAULT_REWARD)
	flatAmount = BountyReadNonNegativeInt(flatAmount, BOUNTY_DEFAULT_GROWTH_FLAT_AMOUNT)
	percent = BountyReadNonNegativeInt(percent, BOUNTY_DEFAULT_GROWTH_PERCENT)
	count = BountyReadNonNegativeInt(count, 0)

	if growthType == BOUNTY_GROWTH_TYPE_PERCENT then
		if base <= 0 then
			return 0
		end
		return BountyRoundNearest(base * ((1 + percent / 100) ^ count))
	end

	return base + (flatAmount * count)
end

---@param settings table | nil
---@param count integer
---@return integer
function BountyCalculateConfiguredGrowthValue(settings, count)
	return BountyCalculateGrowthValue(
		BountyGetBaseReward(settings),
		BountyGetGrowthType(settings),
		BountyGetGrowthFlatAmount(settings),
		BountyGetGrowthPercent(settings),
		count
	)
end

---@param settings table | nil
---@return string
function BountyGrowthDescription(settings)
	if BountyGetGrowthType(settings) == BOUNTY_GROWTH_TYPE_PERCENT then
		return "+" .. tostring(BountyGetGrowthPercent(settings)) .. "%"
	end
	return "+" .. tostring(BountyGetGrowthFlatAmount(settings)) .. " armies"
end

---@param mode string
---@return boolean
function BountyRewardModeUsesGrowth(mode)
	return mode == BOUNTY_REWARD_MODE_GLOBAL_GROWTH or mode == BOUNTY_REWARD_MODE_KILL_COUNT
end

---@param mode string
---@return boolean
function BountyRewardModeUsesPlayerBounties(mode)
	return mode == BOUNTY_REWARD_MODE_KILL_COUNT or mode == BOUNTY_REWARD_MODE_INHERITANCE
end

---@param settings table | nil
---@param publicData table | nil
---@param playerID PlayerID | nil
---@return integer
function BountyGetInheritedPlayerBounty(settings, publicData, playerID)
	local base = BountyGetBaseReward(settings)
	if publicData == nil or playerID == nil then
		return base
	end

	local bounties = publicData.BountyInheritedBountyByPlayer
	if bounties == nil then
		return base
	end

	local value = bounties[tostring(playerID)]
	if value ~= nil then
		return BountyReadNonNegativeInt(value, base)
	end

	value = bounties[playerID]
	if value ~= nil then
		return BountyReadNonNegativeInt(value, base)
	end

	local num = tonumber(tostring(playerID))
	if num ~= nil then
		value = bounties[num]
		if value ~= nil then
			return BountyReadNonNegativeInt(value, base)
		end
	end

	return base
end

---@param settings table | nil
---@param publicData table
---@param playerID PlayerID | nil
---@param amount integer
---@return integer
function BountyAddToInheritedPlayerBounty(settings, publicData, playerID, amount)
	if playerID == nil then
		return 0
	end

	publicData = BountyEnsurePublicData(publicData)
	amount = BountyReadNonNegativeInt(amount, 0)
	local bounty = BountyGetInheritedPlayerBounty(settings, publicData, playerID) + amount
	publicData.BountyInheritedBountyByPlayer[tostring(playerID)] = bounty
	return bounty
end

---@param settings table | nil
---@param publicData table | nil
---@param playerID PlayerID | nil
---@return integer
function BountyPlayerBounty(settings, publicData, playerID)
	local mode = BountyGetRewardMode(settings)
	if mode == BOUNTY_REWARD_MODE_GLOBAL_GROWTH then
		return BountyCalculateConfiguredGrowthValue(settings, BountyGetGlobalBountyCount(publicData))
	end
	if mode == BOUNTY_REWARD_MODE_KILL_COUNT then
		return BountyCalculateConfiguredGrowthValue(settings, BountyGetPlayerKillCount(publicData, playerID))
	end
	if mode == BOUNTY_REWARD_MODE_INHERITANCE then
		return BountyGetInheritedPlayerBounty(settings, publicData, playerID)
	end
	return BountyGetBaseReward(settings)
end

---@param settings table | nil
---@param publicData table | nil
---@param playerID PlayerID | nil
---@return integer
function BountyNextReward(settings, publicData, playerID)
	return BountyPlayerBounty(settings, publicData, playerID)
end

---@param base number
---@param count integer | nil
---@return string
function BountyFormatFixedPreviewSequence(base, count)
	base = BountyReadNonNegativeInt(base, BOUNTY_DEFAULT_REWARD)
	count = BountyReadNonNegativeInt(count, BOUNTY_PREVIEW_REWARD_COUNT)

	local values = {}
	for _ = 1, count do
		table.insert(values, tostring(base))
	end
	return table.concat(values, ", ")
end

---@param base number
---@param growthType string
---@param flatAmount number
---@param percent number
---@param startCount integer | nil
---@param count integer | nil
---@return string
function BountyFormatGrowthPreviewSequence(base, growthType, flatAmount, percent, startCount, count)
	startCount = BountyReadNonNegativeInt(startCount, 0)
	count = BountyReadNonNegativeInt(count, BOUNTY_PREVIEW_REWARD_COUNT)

	local values = {}
	for i = 0, count - 1 do
		table.insert(values, tostring(BountyCalculateGrowthValue(base, growthType, flatAmount, percent, startCount + i)))
	end
	return table.concat(values, ", ")
end

---@param base number
---@param increase number
---@param startKillCount integer | nil
---@param count integer | nil
---@return string
function BountyFormatKillerBountyPreviewSequence(base, increase, startKillCount, count)
	return BountyFormatGrowthPreviewSequence(base, BOUNTY_GROWTH_TYPE_FLAT, increase, BOUNTY_DEFAULT_GROWTH_PERCENT, startKillCount, count)
end

---@param mode string
---@param base number
---@param growthType string
---@param flatAmount number
---@param percent number
---@param startCount integer | nil
---@param count integer | nil
---@return string
function BountyFormatPreviewSequence(mode, base, growthType, flatAmount, percent, startCount, count)
	if BountyRewardModeUsesGrowth(mode) then
		return BountyFormatGrowthPreviewSequence(base, growthType, flatAmount, percent, startCount, count)
	end
	return BountyFormatFixedPreviewSequence(base, count)
end
