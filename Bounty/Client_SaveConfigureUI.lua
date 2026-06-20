require("Util/BountyReward")

---@param value number
---@return integer
local function ToInt(value)
	return math.floor(value)
end

---@return string
local function SelectedRewardMode()
	if BountyGlobalGrowthRadio ~= nil and BountyGlobalGrowthRadio.GetIsChecked() then
		return BOUNTY_REWARD_MODE_GLOBAL_GROWTH
	end
	if BountyKillCountRadio ~= nil and BountyKillCountRadio.GetIsChecked() then
		return BOUNTY_REWARD_MODE_KILL_COUNT
	end
	if BountyInheritanceRadio ~= nil and BountyInheritanceRadio.GetIsChecked() then
		return BOUNTY_REWARD_MODE_INHERITANCE
	end
	return BOUNTY_REWARD_MODE_FIXED
end

---@return string
local function SelectedGrowthType()
	if BountyPercentGrowthRadio ~= nil and BountyPercentGrowthRadio.GetIsChecked() then
		return BOUNTY_GROWTH_TYPE_PERCENT
	end
	return BOUNTY_GROWTH_TYPE_FLAT
end

---@param value number
---@param label string
---@param max integer
---@param alert fun(message: string)
---@return integer | nil
local function ValidateWholeNumber(value, label, max, alert)
	local intValue = ToInt(value)
	if value < 0 then
		alert(label .. " must be 0 or greater")
		return nil
	end
	if value > max then
		alert(label .. " is too high")
		return nil
	end
	if value ~= intValue then
		alert(label .. " must be a whole number")
		return nil
	end
	return intValue
end

---Client_SaveConfigureUI hook
---@param alert fun(message: string)
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
	if Mod.Settings == nil then
		Mod.Settings = {}
	end

	if BountyRewardInput == nil or BountyGrowthFlatInput == nil or BountyGrowthPercentInput == nil then
		alert("Could not read settings inputs. Please reopen the settings and try again.")
		return
	end

	local reward = ValidateWholeNumber(BountyRewardInput.GetValue(), "Starting bounty", BOUNTY_MAX_REWARD, alert)
	if reward == nil then
		return
	end

	local flatAmount = ValidateWholeNumber(BountyGrowthFlatInput.GetValue(), "Flat growth amount", BOUNTY_MAX_GROWTH_FLAT_AMOUNT, alert)
	if flatAmount == nil then
		return
	end

	local percent = ValidateWholeNumber(BountyGrowthPercentInput.GetValue(), "Percentage growth amount", BOUNTY_MAX_GROWTH_PERCENT, alert)
	if percent == nil then
		return
	end

	Mod.Settings.BountyRewardMode = SelectedRewardMode()
	Mod.Settings.BountyGrowthType = SelectedGrowthType()
	Mod.Settings.BountyReward = reward
	Mod.Settings.BountyGrowthFlatAmount = flatAmount
	Mod.Settings.BountyGrowthPercent = percent

	-- Legacy setting names kept populated for old helper/function compatibility.
	Mod.Settings.BountyKillerBountyIncrease = flatAmount
	Mod.Settings.BountyEscalationPercent = percent

	if Mod.Settings.BountyRewardMode == nil then
		Mod.Settings.BountyRewardMode = BOUNTY_REWARD_MODE_FIXED
	end
	if Mod.Settings.BountyGrowthType == nil then
		Mod.Settings.BountyGrowthType = BOUNTY_GROWTH_TYPE_FLAT
	end
	if Mod.Settings.BountyReward == nil then
		Mod.Settings.BountyReward = BOUNTY_DEFAULT_REWARD
	end
	if Mod.Settings.BountyGrowthFlatAmount == nil then
		Mod.Settings.BountyGrowthFlatAmount = BOUNTY_DEFAULT_GROWTH_FLAT_AMOUNT
	end
	if Mod.Settings.BountyGrowthPercent == nil then
		Mod.Settings.BountyGrowthPercent = BOUNTY_DEFAULT_GROWTH_PERCENT
	end
end
