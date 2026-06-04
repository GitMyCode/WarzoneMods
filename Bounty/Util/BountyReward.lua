BOUNTY_DEFAULT_REWARD = 10
BOUNTY_REWARD_MODE_FIXED = "fixed"
BOUNTY_REWARD_MODE_ESCALATING = "escalating"
BOUNTY_DEFAULT_ESCALATION_PERCENT = 20
BOUNTY_PREVIEW_REWARD_COUNT = 5
BOUNTY_MAX_REWARD = 100000
BOUNTY_MAX_ESCALATION_PERCENT = 1000

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
	if mode == BOUNTY_REWARD_MODE_ESCALATING then
		return BOUNTY_REWARD_MODE_ESCALATING
	end
	return BOUNTY_REWARD_MODE_FIXED
end

---@param settings table | nil
---@return integer
function BountyGetBaseReward(settings)
	return BountyReadNonNegativeInt(settings and settings.BountyReward or nil, BOUNTY_DEFAULT_REWARD)
end

---@param settings table | nil
---@return integer
function BountyGetEscalationPercent(settings)
	return BountyReadNonNegativeInt(settings and settings.BountyEscalationPercent or nil, BOUNTY_DEFAULT_ESCALATION_PERCENT)
end

---@param publicData table | nil
---@return integer
function BountyGetEscalatingRewardCount(publicData)
	return BountyReadNonNegativeInt(publicData and publicData.BountyEscalatingRewardCount or nil, 0)
end

---@param publicData table | nil
---@return table
function BountyEnsurePublicData(publicData)
	publicData = publicData or {}
	publicData.BountyTrapOwnerByTerritory = publicData.BountyTrapOwnerByTerritory or {}
	publicData.BountyEscalatingRewardCount = BountyGetEscalatingRewardCount(publicData)
	return publicData
end

---@param value number
---@return integer
function BountyRoundNearest(value)
	value = BountyReadNonNegativeNumber(value, 0)
	return math.floor(value + 0.5)
end

---@param base number
---@param percent number
---@param rewardCount integer
---@return integer
function BountyCalculateReward(base, percent, rewardCount)
	base = BountyReadNonNegativeNumber(base, 0)
	percent = BountyReadNonNegativeNumber(percent, 0)
	rewardCount = BountyReadNonNegativeInt(rewardCount, 0)

	if base <= 0 then
		return 0
	end

	return BountyRoundNearest(base * ((1 + percent / 100) ^ rewardCount))
end

---@param settings table | nil
---@param publicData table | nil
---@return integer
function BountyNextReward(settings, publicData)
	local base = BountyGetBaseReward(settings)
	if BountyGetRewardMode(settings) ~= BOUNTY_REWARD_MODE_ESCALATING then
		return base
	end

	return BountyCalculateReward(base, BountyGetEscalationPercent(settings), BountyGetEscalatingRewardCount(publicData))
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
---@param percent number
---@param startRewardCount integer | nil
---@param count integer | nil
---@return string
function BountyFormatEscalatingPreviewSequence(base, percent, startRewardCount, count)
	base = BountyReadNonNegativeInt(base, BOUNTY_DEFAULT_REWARD)
	percent = BountyReadNonNegativeInt(percent, BOUNTY_DEFAULT_ESCALATION_PERCENT)
	startRewardCount = BountyReadNonNegativeInt(startRewardCount, 0)
	count = BountyReadNonNegativeInt(count, BOUNTY_PREVIEW_REWARD_COUNT)

	local values = {}
	for i = 0, count - 1 do
		table.insert(values, tostring(BountyCalculateReward(base, percent, startRewardCount + i)))
	end
	return table.concat(values, ", ")
end

---@param mode string
---@param base number
---@param percent number
---@param startRewardCount integer | nil
---@param count integer | nil
---@return string
function BountyFormatPreviewSequence(mode, base, percent, startRewardCount, count)
	if mode == BOUNTY_REWARD_MODE_ESCALATING then
		return BountyFormatEscalatingPreviewSequence(base, percent, startRewardCount, count)
	end
	return BountyFormatFixedPreviewSequence(base, count)
end
