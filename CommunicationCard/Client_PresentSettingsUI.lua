require("Util/CommunicationUtil")

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
	local settings = Mod.Settings or {}

	UI.CreateLabel(rootParent).SetText("Limited Private Diplomacy")
	UI.CreateLabel(rootParent).SetText("Pieces needed for one card: " .. tostring(CommGetCardPiecesForWhole(settings)))
	UI.CreateLabel(rootParent).SetText("Pieces awarded per turn: " .. tostring(CommGetCardMinimumPiecesPerTurn(settings)))
	UI.CreateLabel(rootParent).SetText("Starting pieces: " .. tostring(CommGetCardInitialPieces(settings)))
	UI.CreateLabel(rootParent).SetText("Card draw weight: " .. tostring(CommGetCardWeight(settings)))
	UI.CreateLabel(rootParent).SetText("Max message length: " .. tostring(CommGetMaxMessageLength(settings)) .. " characters")
	UI.CreateLabel(rootParent).SetText(" ")
	UI.CreateLabel(rootParent).SetText("Play a Communication Card to write one private message to one player.")
	UI.CreateLabel(rootParent).SetText("Everyone sees sender and recipient; only those two see the content.")

	if CommRequireBuiltInPrivateMessagingDisabled(settings) then
		UI.CreateLabel(rootParent).SetText("Built-in private messaging: disabled at game creation.")
	else
		UI.CreateLabel(rootParent).SetText("Built-in private messaging: unchanged by this mod.")
	end
end
