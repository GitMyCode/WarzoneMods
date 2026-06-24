require("Util/CommunicationUtil")

CommunicationCardRecipientRadios = nil
CommunicationCardMessageInput = nil
CommunicationCardCloseDialog = nil

---@param game GameClientHook
---@return boolean
local function IsActivePlayer(game)
	return game ~= nil
		and game.Us ~= nil
		and game.Game ~= nil
		and game.Game.PlayingPlayers ~= nil
		and CommResolvePlayerID(game.Game.PlayingPlayers, game.Us.ID) ~= nil
end

---@return table | nil
local function SelectedRecipientRow()
	if CommunicationCardRecipientRadios == nil then
		return nil
	end
	for _, row in ipairs(CommunicationCardRecipientRadios) do
		if row.Radio ~= nil and row.Radio.GetIsChecked() then
			return row
		end
	end
	return nil
end

---@param parent UIObject
---@param height number
local function AddSpacer(parent, height)
	UI.CreateEmpty(parent).SetPreferredHeight(height)
end

---Client_PresentPlayCardUI hook
---@param game GameClientHook
---@param cardInstance CardInstance
---@param playCard fun(orderListMessage: string, modData: string, turnPhase: EnumTurnPhase, annotations: table<TerritoryID, TerritoryAnnotation>, viewSpot: RectangleVM)
---@param closeCardsDialog fun()
function Client_PresentPlayCardUI(game, cardInstance, playCard, closeCardsDialog)
	local settings = Mod.Settings or {}
	if settings.CommunicationCardID == nil or tostring(cardInstance.CardID) ~= tostring(settings.CommunicationCardID) then
		return
	end

	if not IsActivePlayer(game) then
		UI.Alert("You must be an active player to use a Communication Card.")
		return
	end

	if CommunicationCardCloseDialog ~= nil then
		CommunicationCardCloseDialog()
		CommunicationCardCloseDialog = nil
	end

	if closeCardsDialog ~= nil and (WL.IsVersionOrHigher == nil or WL.IsVersionOrHigher("5.34")) then
		closeCardsDialog()
	end

	game.CreateDialog(function(rootParent, setMaxSize, setScrollable, dialogGame, close)
		CommunicationCardCloseDialog = close
		setMaxSize(620, 520)
		setScrollable(false, true)

		local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1)
		UI.CreateLabel(vert).SetText("Communication Card").SetColor("#FFFFFF")
		UI.CreateLabel(vert).SetText("Choose one recipient and write your message.").SetColor("#E6E6E6")
		UI.CreateLabel(vert).SetText("Other players see who you messaged, but not what you wrote.").SetColor("#BFBFBF")
		AddSpacer(vert, 8)

		local recipients = CommSortedRecipients(game)
		if #recipients == 0 then
			UI.CreateLabel(vert).SetText("No active recipients are available.").SetColor("#FF6666")
			UI.CreateButton(vert).SetText("Close").SetOnClick(function()
				close()
			end)
			return
		end

		UI.CreateLabel(vert).SetText("Choose recipient:").SetColor("#BFBFBF")
		CommunicationCardRecipientRadios = {}
		local radioParent = UI.CreateVerticalLayoutGroup(vert)
		local radioGroup = UI.CreateRadioButtonGroup(radioParent)
		for index, recipient in ipairs(recipients) do
			local radio = UI.CreateRadioButton(radioGroup)
			radio.SetGroup(radioGroup)
			radio.SetText(recipient.Name)
			radio.SetIsChecked(index == 1)
			table.insert(CommunicationCardRecipientRadios, {
				ID = recipient.ID,
				Name = recipient.Name,
				Radio = radio,
			})
		end

		AddSpacer(vert, 8)
		local maxLength = CommGetMaxMessageLength(settings)
		UI.CreateLabel(vert).SetText("Private message (max " .. tostring(maxLength) .. " characters):").SetColor("#BFBFBF")
		CommunicationCardMessageInput = UI.CreateTextInputField(vert)
		CommunicationCardMessageInput.SetPlaceholderText("Example: Truce on the east for two turns?")
		CommunicationCardMessageInput.SetCharacterLimit(maxLength)
		CommunicationCardMessageInput.SetPreferredHeight(90)
		CommunicationCardMessageInput.SetFlexibleWidth(1)

		AddSpacer(vert, 8)
		local row = UI.CreateHorizontalLayoutGroup(vert)
		UI.CreateButton(row).SetText("Play Communication Card").SetColor("#70AD47").SetOnClick(function()
			local recipient = SelectedRecipientRow()
			if recipient == nil then
				UI.Alert("Choose a recipient first.")
				return
			end

			local message = ""
			if CommunicationCardMessageInput ~= nil then
				message = CommTrim(CommunicationCardMessageInput.GetText())
			end

			if message == "" then
				UI.Alert("Enter a message first.")
				return
			end
			if #message > maxLength then
				UI.Alert("Shorten the message to " .. tostring(maxLength) .. " characters or fewer.")
				return
			end

			local senderName = game.Us.DisplayName(nil, false)
			local orderText = senderName .. " sends a private diplomacy message to " .. recipient.Name
			local payload = CommCreatePayload(recipient.ID, message)
			local played = playCard(orderText, payload, WL.TurnPhase.CardsWearOff)
			if played ~= false then
				close()
			end
		end)
		UI.CreateButton(row).SetText("Cancel").SetColor("#A5A5A5").SetOnClick(function()
			close()
		end)
	end)
end
