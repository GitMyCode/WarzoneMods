require("Util/CommunicationUtil")

---@param value number
---@return integer
local function ToInt(value)
	return math.floor(value)
end

---@param input NumberInputField | nil
---@param label string
---@param min integer
---@param max integer
---@param alert fun(message: string)
---@return integer | nil
local function ValidateWholeNumberInput(input, label, min, max, alert)
	if input == nil then
		alert("Could not read " .. label .. ". Please reopen the settings and try again.")
		return nil
	end

	local value = input.GetValue()
	local intValue = ToInt(value)
	if value ~= intValue then
		alert(label .. " must be a whole number")
		return nil
	end
	if intValue < min then
		alert(label .. " must be at least " .. tostring(min))
		return nil
	end
	if intValue > max then
		alert(label .. " must be at most " .. tostring(max))
		return nil
	end
	return intValue
end

---@param input NumberInputField | nil
---@param label string
---@param min number
---@param max number
---@param alert fun(message: string)
---@return number | nil
local function ValidateNumberInput(input, label, min, max, alert)
	if input == nil then
		alert("Could not read " .. label .. ". Please reopen the settings and try again.")
		return nil
	end

	local value = input.GetValue()
	if value < min then
		alert(label .. " must be at least " .. tostring(min))
		return nil
	end
	if value > max then
		alert(label .. " must be at most " .. tostring(max))
		return nil
	end
	return value
end

---Client_SaveConfigureUI hook
---@param alert fun(message: string)
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
	if Mod.Settings == nil then
		Mod.Settings = {}
	end

	local piecesForWholeCard = ValidateWholeNumberInput(CommunicationPiecesForWholeCardInput, "Pieces needed for one card", 1, COMM_MAX_CONFIG_CARD_PIECES, alert)
	if piecesForWholeCard == nil then
		return
	end

	local minimumPiecesPerTurn = ValidateWholeNumberInput(CommunicationMinimumPiecesPerTurnInput, "Pieces awarded per turn", 0, COMM_MAX_CONFIG_CARD_PIECES, alert)
	if minimumPiecesPerTurn == nil then
		return
	end

	local initialPieces = ValidateWholeNumberInput(CommunicationInitialPiecesInput, "Starting pieces", 0, COMM_MAX_CONFIG_INITIAL_PIECES, alert)
	if initialPieces == nil then
		return
	end

	local cardWeight = ValidateNumberInput(CommunicationCardWeightInput, "Card draw weight", 0, COMM_MAX_CONFIG_CARD_WEIGHT, alert)
	if cardWeight == nil then
		return
	end

	local maxLength = ValidateWholeNumberInput(CommunicationMaxMessageLengthInput, "Max message length", COMM_MIN_CONFIG_MESSAGE_LENGTH, COMM_MAX_CONFIG_MESSAGE_LENGTH, alert)
	if maxLength == nil then
		return
	end

	Mod.Settings.CommunicationPiecesForWholeCard = piecesForWholeCard
	Mod.Settings.CommunicationMinimumPiecesPerTurn = minimumPiecesPerTurn
	Mod.Settings.CommunicationInitialPieces = initialPieces
	Mod.Settings.CommunicationCardWeight = cardWeight
	Mod.Settings.CommunicationMaxMessageLength = maxLength
	Mod.Settings.CommunicationRequirePrivateMessagingDisabled = true
	if CommunicationRequirePrivateMessagingDisabledCheckbox ~= nil then
		Mod.Settings.CommunicationRequirePrivateMessagingDisabled = CommunicationRequirePrivateMessagingDisabledCheckbox.GetIsChecked()
	end

	Mod.Settings.CommunicationCardID = addCard(
		"Communication Card",
		"Send one private diplomacy message to one player. Everyone sees sender and recipient; only those two see the content.",
		"CommunicationCard.png",
		piecesForWholeCard,
		minimumPiecesPerTurn,
		initialPieces,
		cardWeight
	)
end
