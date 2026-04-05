FixedTroopsRewardInput = nil
FixedGoldRewardInput = nil

local DEFAULT_TROOPS_REWARD = 10
local DEFAULT_GOLD_REWARD = 10

---@param value any
---@param fallback integer
---@return integer
local function ReadNonNegativeInt(value, fallback)
	if type(value) ~= "number" then
		return fallback
	end
	local n = math.floor(value)
	if n < 0 then
		return fallback
	end
	return n
end

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
	if Mod.Settings == nil then
		Mod.Settings = {}
	end

	local troopsReward = ReadNonNegativeInt(Mod.Settings and Mod.Settings.FixedTroopsReward, DEFAULT_TROOPS_REWARD)
	local goldReward = ReadNonNegativeInt(Mod.Settings and Mod.Settings.FixedGoldReward, DEFAULT_GOLD_REWARD)

	UI.CreateLabel(rootParent).SetText("Bounty Mode settings")
	UI.CreateLabel(rootParent).SetText("Normal games use troops reward. Commerce games use gold reward.")

	local troopsRow = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(troopsRow).SetText("Fixed troops reward:")
	FixedTroopsRewardInput = UI.CreateNumberInputField(troopsRow)
	FixedTroopsRewardInput.SetSliderMinValue(0)
	FixedTroopsRewardInput.SetSliderMaxValue(250)
	FixedTroopsRewardInput.SetValue(troopsReward)

	local goldRow = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(goldRow).SetText("Fixed gold reward (Commerce):")
	FixedGoldRewardInput = UI.CreateNumberInputField(goldRow)
	FixedGoldRewardInput.SetSliderMinValue(0)
	FixedGoldRewardInput.SetSliderMaxValue(250)
	FixedGoldRewardInput.SetValue(goldReward)
end
