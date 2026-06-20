require("Util/BountyReward")

BountyRewardInput = nil
BountyGrowthFlatInput = nil
BountyGrowthPercentInput = nil
BountyFixedRewardRadio = nil
BountyGlobalGrowthRadio = nil
BountyKillCountRadio = nil
BountyInheritanceRadio = nil
BountyFlatGrowthRadio = nil
BountyPercentGrowthRadio = nil
BountyRewardPreviewLabel = nil

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

---@param input NumberInputField | nil
---@param fallback integer
---@return integer
local function ReadInputInt(input, fallback)
	if input == nil then
		return fallback
	end
	return BountyReadNonNegativeInt(input.GetValue(), fallback)
end

local function UpdateBountyPreview()
	if BountyRewardPreviewLabel == nil then
		return
	end

	local mode = SelectedRewardMode()
	local growthType = SelectedGrowthType()
	local reward = ReadInputInt(BountyRewardInput, BOUNTY_DEFAULT_REWARD)
	local flatAmount = ReadInputInt(BountyGrowthFlatInput, BOUNTY_DEFAULT_GROWTH_FLAT_AMOUNT)
	local percent = ReadInputInt(BountyGrowthPercentInput, BOUNTY_DEFAULT_GROWTH_PERCENT)
	local usesGrowth = BountyRewardModeUsesGrowth(mode)

	if BountyGrowthFlatInput ~= nil then
		BountyGrowthFlatInput.SetInteractable(usesGrowth and growthType == BOUNTY_GROWTH_TYPE_FLAT)
	end
	if BountyGrowthPercentInput ~= nil then
		BountyGrowthPercentInput.SetInteractable(usesGrowth and growthType == BOUNTY_GROWTH_TYPE_PERCENT)
	end

	if mode == BOUNTY_REWARD_MODE_GLOBAL_GROWTH then
		local sequence = BountyFormatPreviewSequence(mode, reward, growthType, flatAmount, percent, 0, BOUNTY_PREVIEW_REWARD_COUNT)
		BountyRewardPreviewLabel.SetText("Global bounty after 0-" .. tostring(BOUNTY_PREVIEW_REWARD_COUNT - 1) .. " credited kills: " .. sequence)
	elseif mode == BOUNTY_REWARD_MODE_KILL_COUNT then
		local sequence = BountyFormatPreviewSequence(mode, reward, growthType, flatAmount, percent, 0, BOUNTY_PREVIEW_REWARD_COUNT)
		BountyRewardPreviewLabel.SetText("Player bounty after 0-" .. tostring(BOUNTY_PREVIEW_REWARD_COUNT - 1) .. " kills: " .. sequence)
	elseif mode == BOUNTY_REWARD_MODE_INHERITANCE then
		BountyRewardPreviewLabel.SetText("Stacking example: A is worth " .. tostring(reward) .. ", eliminates B worth " .. tostring(reward) .. ", then A is worth " .. tostring(reward * 2))
	else
		local sequence = BountyFormatFixedPreviewSequence(reward, BOUNTY_PREVIEW_REWARD_COUNT)
		BountyRewardPreviewLabel.SetText("Example fixed bounties: " .. sequence)
	end
end

---@param input NumberInputField
local function MakeNumberInputLookLikeTextBox(input)
	input.SetWholeNumbers(true)
	input.SetBoxPreferredWidth(80)
	input.SetSliderPreferredWidth(0)
end

---@param radio RadioButton | nil
---@param callback fun()
local function SetRadioChangeHandler(radio, callback)
	if radio == nil then
		return
	end

	-- Different Warzone annotation/runtime versions disagree on this method's casing.
	if radio.SetOnValueChanged ~= nil then
		radio.SetOnValueChanged(callback)
		return
	end
	if radio.SetOnvalueChanged ~= nil then
		radio.SetOnvalueChanged(callback)
	end
end

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
	if Mod.Settings == nil then
		Mod.Settings = {}
	end

	local mode = BountyGetRewardMode(Mod.Settings)
	local growthType = BountyGetGrowthType(Mod.Settings)
	local reward = BountyGetBaseReward(Mod.Settings)
	local flatAmount = BountyGetGrowthFlatAmount(Mod.Settings)
	local percent = BountyGetGrowthPercent(Mod.Settings)

	UI.CreateLabel(rootParent).SetText("Bounty Mode settings")
	UI.CreateLabel(rootParent).SetText("Eliminating a player grants that player's current bounty.")

	UI.CreateLabel(rootParent).SetText("Bounty scaling:")
	local modeParent = UI.CreateVerticalLayoutGroup(rootParent)
	local modeGroup = UI.CreateRadioButtonGroup(modeParent)
	BountyFixedRewardRadio = UI.CreateRadioButton(modeGroup)
	BountyFixedRewardRadio.SetGroup(modeGroup)
	BountyFixedRewardRadio.SetText("Fixed bounty")
	BountyFixedRewardRadio.SetIsChecked(mode == BOUNTY_REWARD_MODE_FIXED)

	BountyGlobalGrowthRadio = UI.CreateRadioButton(modeGroup)
	BountyGlobalGrowthRadio.SetGroup(modeGroup)
	BountyGlobalGrowthRadio.SetText("Global bounty growth")
	BountyGlobalGrowthRadio.SetIsChecked(mode == BOUNTY_REWARD_MODE_GLOBAL_GROWTH)

	BountyKillCountRadio = UI.CreateRadioButton(modeGroup)
	BountyKillCountRadio.SetGroup(modeGroup)
	BountyKillCountRadio.SetText("Kill-count bounty growth")
	BountyKillCountRadio.SetIsChecked(mode == BOUNTY_REWARD_MODE_KILL_COUNT)

	BountyInheritanceRadio = UI.CreateRadioButton(modeGroup)
	BountyInheritanceRadio.SetGroup(modeGroup)
	BountyInheritanceRadio.SetText("Stacking bounty")
	BountyInheritanceRadio.SetIsChecked(mode == BOUNTY_REWARD_MODE_INHERITANCE)

	local row = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(row).SetText("Starting bounty (armies):").SetPreferredWidth(220)
	BountyRewardInput = UI.CreateNumberInputField(row)
	MakeNumberInputLookLikeTextBox(BountyRewardInput)
	BountyRewardInput.SetSliderMinValue(0)
	BountyRewardInput.SetSliderMaxValue(250)
	BountyRewardInput.SetValue(reward)

	UI.CreateLabel(rootParent).SetText("Growth type for global / kill-count modes:")
	local growthParent = UI.CreateVerticalLayoutGroup(rootParent)
	local growthGroup = UI.CreateRadioButtonGroup(growthParent)
	BountyFlatGrowthRadio = UI.CreateRadioButton(growthGroup)
	BountyFlatGrowthRadio.SetGroup(growthGroup)
	BountyFlatGrowthRadio.SetText("Flat armies per kill")
	BountyFlatGrowthRadio.SetIsChecked(growthType == BOUNTY_GROWTH_TYPE_FLAT)

	BountyPercentGrowthRadio = UI.CreateRadioButton(growthGroup)
	BountyPercentGrowthRadio.SetGroup(growthGroup)
	BountyPercentGrowthRadio.SetText("Percentage per kill")
	BountyPercentGrowthRadio.SetIsChecked(growthType == BOUNTY_GROWTH_TYPE_PERCENT)

	local flatRow = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(flatRow).SetText("Flat increase:").SetPreferredWidth(220)
	BountyGrowthFlatInput = UI.CreateNumberInputField(flatRow)
	MakeNumberInputLookLikeTextBox(BountyGrowthFlatInput)
	BountyGrowthFlatInput.SetSliderMinValue(0)
	BountyGrowthFlatInput.SetSliderMaxValue(250)
	BountyGrowthFlatInput.SetValue(flatAmount)
	UI.CreateLabel(flatRow).SetText("armies")

	local percentRow = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(percentRow).SetText("Percentage increase:").SetPreferredWidth(220)
	BountyGrowthPercentInput = UI.CreateNumberInputField(percentRow)
	MakeNumberInputLookLikeTextBox(BountyGrowthPercentInput)
	BountyGrowthPercentInput.SetSliderMinValue(0)
	BountyGrowthPercentInput.SetSliderMaxValue(100)
	BountyGrowthPercentInput.SetValue(percent)
	UI.CreateLabel(percentRow).SetText("%")

	local previewRow = UI.CreateHorizontalLayoutGroup(rootParent)
	BountyRewardPreviewLabel = UI.CreateLabel(previewRow).SetPreferredWidth(560)
	UI.CreateButton(previewRow).SetText("Update preview").SetOnClick(function()
		UpdateBountyPreview()
	end)

	SetRadioChangeHandler(BountyFixedRewardRadio, UpdateBountyPreview)
	SetRadioChangeHandler(BountyGlobalGrowthRadio, UpdateBountyPreview)
	SetRadioChangeHandler(BountyKillCountRadio, UpdateBountyPreview)
	SetRadioChangeHandler(BountyInheritanceRadio, UpdateBountyPreview)
	SetRadioChangeHandler(BountyFlatGrowthRadio, UpdateBountyPreview)
	SetRadioChangeHandler(BountyPercentGrowthRadio, UpdateBountyPreview)
	UpdateBountyPreview()
end
