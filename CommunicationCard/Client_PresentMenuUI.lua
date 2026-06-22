require("Util/CommunicationUtil")

local COLOR_TITLE = "#FFFFFF"
local COLOR_ACCENT = "#FFD966"
local COLOR_MUTED = "#BFBFBF"
local COLOR_TEXT = "#E6E6E6"
local COLOR_GOOD = "#70AD47"

---@param parent UIObject
---@param height number
local function AddSpacer(parent, height)
	UI.CreateEmpty(parent).SetPreferredHeight(height)
end

---@param parent UIObject
---@param text string
local function AddSectionTitle(parent, text)
	UI.CreateLabel(parent).SetText(text).SetColor(COLOR_TITLE)
end

---@param message table
---@param game GameClientHook
---@param incoming boolean
---@return string
local function FormatPrivateMessage(message, game, incoming)
	local otherName = message.SenderName or CommPlayerName(game, message.SenderID)
	if not incoming then
		otherName = message.RecipientName or CommPlayerName(game, message.RecipientID)
	end

	local direction = incoming and "From " or "To "
	return "Turn " .. tostring(message.Turn or "?") .. " — " .. direction .. otherName .. ": " .. tostring(message.Message or "")
end

---@param parent UIObject
---@param list table | nil
---@param game GameClientHook
---@param incoming boolean
local function AddPrivateMessages(parent, list, game, incoming)
	if list == nil or #list == 0 then
		UI.CreateLabel(parent).SetText("No messages yet.").SetColor(COLOR_MUTED)
		return
	end

	local first = #list - COMM_MENU_LOG_LIMIT + 1
	if first < 1 then
		first = 1
	end
	for i = #list, first, -1 do
		UI.CreateLabel(parent).SetText(FormatPrivateMessage(list[i], game, incoming)).SetColor(COLOR_TEXT).SetFlexibleWidth(1)
	end
end

---@param parent UIObject
---@param publicLog table | nil
---@param game GameClientHook
local function AddPublicLog(parent, publicLog, game)
	if publicLog == nil or #publicLog == 0 then
		UI.CreateLabel(parent).SetText("No public diplomacy activity yet.").SetColor(COLOR_MUTED)
		return
	end

	local first = #publicLog - COMM_MENU_LOG_LIMIT + 1
	if first < 1 then
		first = 1
	end
	for i = #publicLog, first, -1 do
		UI.CreateLabel(parent).SetText(CommFormatPublicEvent(publicLog[i], game)).SetColor(COLOR_TEXT)
	end
end

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number)
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean)
---@param game GameClientHook
---@param close fun()
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
	setMaxSize(760, 620)
	setScrollable(false, true)

	local publicData = Mod.PublicGameData or {}
	local playerData = Mod.PlayerGameData or {}
	local vert = UI.CreateVerticalLayoutGroup(rootParent)

	UI.CreateLabel(vert).SetText("Limited Private Diplomacy").SetColor(COLOR_TITLE)
	UI.CreateLabel(vert).SetText("To send a message, play a Communication Card from the Cards UI.").SetColor(COLOR_ACCENT)
	UI.CreateLabel(vert).SetText("Choose one recipient, write the message, then commit your orders.").SetColor(COLOR_TEXT)
	UI.CreateLabel(vert).SetText("Built-in private messaging is disabled when the game is created.").SetColor(COLOR_MUTED)
	AddSpacer(vert, 12)

	AddSectionTitle(vert, "YOUR INBOX")
	AddPrivateMessages(vert, playerData.CommunicationInbox, game, true)

	AddSpacer(vert, 12)
	AddSectionTitle(vert, "YOUR SENT MESSAGES")
	AddPrivateMessages(vert, playerData.CommunicationSent, game, false)

	AddSpacer(vert, 12)
	AddSectionTitle(vert, "PUBLIC DIPLOMACY LOG")
	AddPublicLog(vert, publicData.CommunicationLog, game)

	AddSpacer(vert, 12)
	UI.CreateButton(vert).SetText("Close").SetColor(COLOR_GOOD).SetOnClick(function()
		close()
	end)
end
