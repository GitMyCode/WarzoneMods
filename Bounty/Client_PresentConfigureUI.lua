BountyRewardInput = nil

local DEFAULT_REWARD = 10

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

	local reward = ReadNonNegativeInt(Mod.Settings and Mod.Settings.BountyReward, DEFAULT_REWARD)

	UI.CreateLabel(rootParent).SetText("Bounty Mode settings")
	UI.CreateLabel(rootParent).SetText("Players earn bonus armies for eliminating another player.")

	local row = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(row).SetText("Bounty reward (armies):")
	BountyRewardInput = UI.CreateNumberInputField(row)
	BountyRewardInput.SetSliderMinValue(0)
	BountyRewardInput.SetSliderMaxValue(250)
	BountyRewardInput.SetValue(reward)
end
