require("Util/BountyReward")

BountyRewardInput = nil
BountyEscalationPercentInput = nil
BountyFixedRewardRadio = nil
BountyEscalatingRewardRadio = nil
BountyRewardPreviewLabel = nil

---@return string
local function SelectedRewardMode()
	if BountyEscalatingRewardRadio ~= nil and BountyEscalatingRewardRadio.GetIsChecked() then
		return BOUNTY_REWARD_MODE_ESCALATING
	end
	return BOUNTY_REWARD_MODE_FIXED
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
	local reward = ReadInputInt(BountyRewardInput, BOUNTY_DEFAULT_REWARD)
	local percent = ReadInputInt(BountyEscalationPercentInput, BOUNTY_DEFAULT_ESCALATION_PERCENT)
	local sequence = BountyFormatPreviewSequence(mode, reward, percent, 0, BOUNTY_PREVIEW_REWARD_COUNT)

	if BountyEscalationPercentInput ~= nil then
		BountyEscalationPercentInput.SetInteractable(mode == BOUNTY_REWARD_MODE_ESCALATING)
	end

	if mode == BOUNTY_REWARD_MODE_ESCALATING then
		BountyRewardPreviewLabel.SetText("Example escalating bounties: " .. sequence)
	else
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
	local reward = BountyGetBaseReward(Mod.Settings)
	local percent = BountyGetEscalationPercent(Mod.Settings)

	UI.CreateLabel(rootParent).SetText("Bounty Mode settings")
	UI.CreateLabel(rootParent).SetText("Players earn bonus armies for eliminating another player.")

	UI.CreateLabel(rootParent).SetText("Reward mode:")
	local modeGroup = UI.CreateRadioButtonGroup(rootParent)
	BountyFixedRewardRadio = UI.CreateRadioButton(modeGroup)
	BountyFixedRewardRadio.SetGroup(modeGroup)
	BountyFixedRewardRadio.SetText("Fixed bounty")
	BountyFixedRewardRadio.SetIsChecked(mode == BOUNTY_REWARD_MODE_FIXED)

	BountyEscalatingRewardRadio = UI.CreateRadioButton(modeGroup)
	BountyEscalatingRewardRadio.SetGroup(modeGroup)
	BountyEscalatingRewardRadio.SetText("Escalating bounty")
	BountyEscalatingRewardRadio.SetIsChecked(mode == BOUNTY_REWARD_MODE_ESCALATING)

	local row = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(row).SetText("Starting bounty (armies):").SetPreferredWidth(170)
	BountyRewardInput = UI.CreateNumberInputField(row)
	MakeNumberInputLookLikeTextBox(BountyRewardInput)
	BountyRewardInput.SetSliderMinValue(0)
	BountyRewardInput.SetSliderMaxValue(250)
	BountyRewardInput.SetValue(reward)

	local percentRow = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(percentRow).SetText("Increase after each kill:").SetPreferredWidth(170)
	BountyEscalationPercentInput = UI.CreateNumberInputField(percentRow)
	MakeNumberInputLookLikeTextBox(BountyEscalationPercentInput)
	BountyEscalationPercentInput.SetSliderMinValue(0)
	BountyEscalationPercentInput.SetSliderMaxValue(100)
	BountyEscalationPercentInput.SetValue(percent)
	UI.CreateLabel(percentRow).SetText("%")

	local previewRow = UI.CreateHorizontalLayoutGroup(rootParent)
	BountyRewardPreviewLabel = UI.CreateLabel(previewRow).SetPreferredWidth(430)
	UI.CreateButton(previewRow).SetText("Update preview").SetOnClick(function()
		UpdateBountyPreview()
	end)

	SetRadioChangeHandler(BountyFixedRewardRadio, UpdateBountyPreview)
	SetRadioChangeHandler(BountyEscalatingRewardRadio, UpdateBountyPreview)
	UpdateBountyPreview()
end
