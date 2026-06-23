require("Util/CommunicationUtil")

CommunicationPiecesForWholeCardInput = nil
CommunicationMinimumPiecesPerTurnInput = nil
CommunicationInitialPiecesInput = nil
CommunicationCardWeightInput = nil
CommunicationMaxMessageLengthInput = nil
CommunicationRequirePrivateMessagingDisabledCheckbox = nil

---@param input NumberInputField
---@param wholeNumbers boolean
local function MakeNumberInputLookLikeTextBox(input, wholeNumbers)
	input.SetWholeNumbers(wholeNumbers)
	input.SetBoxPreferredWidth(80)
	input.SetSliderPreferredWidth(0)
end

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
	if Mod.Settings == nil then
		Mod.Settings = {}
	end

	UI.CreateLabel(rootParent).SetText("Limited Private Diplomacy")
	UI.CreateLabel(rootParent).SetText("Adds a Communication Card for scarce private messages.")
	UI.CreateLabel(rootParent).SetText("Everyone sees sender and recipient; only those two see the content.")
	UI.CreateLabel(rootParent).SetText(" ")

	local row = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(row).SetText("Pieces needed for one card:").SetPreferredWidth(260)
	CommunicationPiecesForWholeCardInput = UI.CreateNumberInputField(row)
	MakeNumberInputLookLikeTextBox(CommunicationPiecesForWholeCardInput, true)
	CommunicationPiecesForWholeCardInput.SetSliderMinValue(1)
	CommunicationPiecesForWholeCardInput.SetSliderMaxValue(COMM_MAX_CONFIG_CARD_PIECES)
	CommunicationPiecesForWholeCardInput.SetValue(CommGetCardPiecesForWhole(Mod.Settings))

	row = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(row).SetText("Pieces awarded per turn:").SetPreferredWidth(260)
	CommunicationMinimumPiecesPerTurnInput = UI.CreateNumberInputField(row)
	MakeNumberInputLookLikeTextBox(CommunicationMinimumPiecesPerTurnInput, true)
	CommunicationMinimumPiecesPerTurnInput.SetSliderMinValue(0)
	CommunicationMinimumPiecesPerTurnInput.SetSliderMaxValue(COMM_MAX_CONFIG_CARD_PIECES)
	CommunicationMinimumPiecesPerTurnInput.SetValue(CommGetCardMinimumPiecesPerTurn(Mod.Settings))

	row = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(row).SetText("Starting pieces:").SetPreferredWidth(260)
	CommunicationInitialPiecesInput = UI.CreateNumberInputField(row)
	MakeNumberInputLookLikeTextBox(CommunicationInitialPiecesInput, true)
	CommunicationInitialPiecesInput.SetSliderMinValue(0)
	CommunicationInitialPiecesInput.SetSliderMaxValue(COMM_MAX_CONFIG_INITIAL_PIECES)
	CommunicationInitialPiecesInput.SetValue(CommGetCardInitialPieces(Mod.Settings))

	row = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(row).SetText("Card draw weight:").SetPreferredWidth(260)
	CommunicationCardWeightInput = UI.CreateNumberInputField(row)
	MakeNumberInputLookLikeTextBox(CommunicationCardWeightInput, false)
	CommunicationCardWeightInput.SetSliderMinValue(0)
	CommunicationCardWeightInput.SetSliderMaxValue(COMM_MAX_CONFIG_CARD_WEIGHT)
	CommunicationCardWeightInput.SetValue(CommGetCardWeight(Mod.Settings))

	row = UI.CreateHorizontalLayoutGroup(rootParent)
	UI.CreateLabel(row).SetText("Max message length:").SetPreferredWidth(260)
	CommunicationMaxMessageLengthInput = UI.CreateNumberInputField(row)
	MakeNumberInputLookLikeTextBox(CommunicationMaxMessageLengthInput, true)
	CommunicationMaxMessageLengthInput.SetSliderMinValue(COMM_MIN_CONFIG_MESSAGE_LENGTH)
	CommunicationMaxMessageLengthInput.SetSliderMaxValue(COMM_MAX_CONFIG_MESSAGE_LENGTH)
	CommunicationMaxMessageLengthInput.SetValue(CommGetMaxMessageLength(Mod.Settings))

	UI.CreateLabel(rootParent).SetText(" ")
	CommunicationRequirePrivateMessagingDisabledCheckbox = UI.CreateCheckBox(rootParent)
	CommunicationRequirePrivateMessagingDisabledCheckbox.SetText("Disable built-in private messaging when the game is created")
	CommunicationRequirePrivateMessagingDisabledCheckbox.SetIsChecked(CommRequireBuiltInPrivateMessagingDisabled(Mod.Settings))

	UI.CreateLabel(rootParent).SetText(" ")
	UI.CreateLabel(rootParent).SetText("Built-in private messaging is disabled when the game is created.")
end
