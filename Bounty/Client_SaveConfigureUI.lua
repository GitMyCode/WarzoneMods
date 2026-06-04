require("Util/BountyReward")

---@param value number
---@return integer
local function ToInt(value)
	return math.floor(value)
end

---@return string
local function SelectedRewardMode()
	if BountyEscalatingRewardRadio ~= nil and BountyEscalatingRewardRadio.GetIsChecked() then
		return BOUNTY_REWARD_MODE_ESCALATING
	end
	return BOUNTY_REWARD_MODE_FIXED
end

---Client_SaveConfigureUI hook
---@param alert fun(message: string)
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
	if Mod.Settings == nil then
		Mod.Settings = {}
	end

	if BountyRewardInput == nil or BountyEscalationPercentInput == nil then
		alert("Could not read settings inputs. Please reopen the settings and try again.")
		return
	end

	local rewardValue = BountyRewardInput.GetValue()
	local reward = ToInt(rewardValue)

	if rewardValue < 0 then
		alert("Bounty reward must be 0 or greater")
		return
	end
	if rewardValue > BOUNTY_MAX_REWARD then
		alert("Bounty reward is too high")
		return
	end
	if rewardValue ~= reward then
		alert("Bounty reward must be a whole number")
		return
	end

	local percentValue = BountyEscalationPercentInput.GetValue()
	local percent = ToInt(percentValue)

	if percentValue ~= percent then
		alert("Escalation increase must be a whole-number percent")
		return
	end
	if percent < 0 then
		alert("Escalation increase must be 0% or greater")
		return
	end
	if percent > BOUNTY_MAX_ESCALATION_PERCENT then
		alert("Escalation increase is too high (maximum is " .. tostring(BOUNTY_MAX_ESCALATION_PERCENT) .. "%)")
		return
	end

	Mod.Settings.BountyRewardMode = SelectedRewardMode()
	Mod.Settings.BountyReward = reward
	Mod.Settings.BountyEscalationPercent = percent

	if Mod.Settings.BountyRewardMode == nil then
		Mod.Settings.BountyRewardMode = BOUNTY_REWARD_MODE_FIXED
	end
	if Mod.Settings.BountyReward == nil then
		Mod.Settings.BountyReward = BOUNTY_DEFAULT_REWARD
	end
	if Mod.Settings.BountyEscalationPercent == nil then
		Mod.Settings.BountyEscalationPercent = BOUNTY_DEFAULT_ESCALATION_PERCENT
	end
end
