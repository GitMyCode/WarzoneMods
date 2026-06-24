require("Util/CommunicationUtil")

---@param message string
local function Log(message)
	print("[CommunicationCard] " .. message)
end

---@param game GameServerHook
---@param senderID PlayerID
---@param reason string
---@param addNewOrder fun(order: GameOrder)
local function AddPrivateFailureEvent(game, senderID, reason, addNewOrder)
	addNewOrder(WL.GameOrderEvent.Create(senderID, "Communication Card failed: " .. reason, { senderID }, nil, nil, nil))
end

---@param order GameOrder
---@return boolean
local function IsCommunicationCardOrder(order)
	if order == nil or order.proxyType ~= "GameOrderPlayCardCustom" then
		return false
	end

	local settings = Mod.Settings or {}
	if settings.CommunicationCardID ~= nil and tostring(order.CustomCardID) == tostring(settings.CommunicationCardID) then
		return true
	end

	return false
end

---@param game GameServerHook
---@param order GameOrderPlayCardCustom
---@param addNewOrder fun(order: GameOrder)
local function DeliverCommunicationCardMessage(game, order, addNewOrder)
	local parsed = CommParsePayload(order.ModData)
	if parsed == nil then
		AddPrivateFailureEvent(game, order.PlayerID, "invalid message payload", addNewOrder)
		return
	end

	local recipientID = CommResolvePlayerID(game.Game.Players, parsed.RecipientID)
	if recipientID == nil then
		AddPrivateFailureEvent(game, order.PlayerID, "recipient not found", addNewOrder)
		return
	end
	if CommSamePlayerID(order.PlayerID, recipientID) then
		AddPrivateFailureEvent(game, order.PlayerID, "cannot send to yourself", addNewOrder)
		return
	end

	local settings = Mod.Settings or {}
	local maxLength = CommGetMaxMessageLength(settings)
	local message = CommTrim(parsed.Message)
	if message == "" then
		AddPrivateFailureEvent(game, order.PlayerID, "empty message", addNewOrder)
		return
	end
	if #message > maxLength then
		message = string.sub(message, 1, maxLength)
	end

	local publicData = CommEnsurePublicData(Mod.PublicGameData)
	local playerData = Mod.PlayerGameData or {}
	local senderData = CommEnsureOnePlayerData(playerData, order.PlayerID)
	local recipientData = CommEnsureOnePlayerData(playerData, recipientID)

	local messageID = publicData.CommunicationNextMessageID
	publicData.CommunicationNextMessageID = messageID + 1

	local senderName = CommPlayerName(game, order.PlayerID)
	local recipientName = CommPlayerName(game, recipientID)
	local turnNumber = game.Game.TurnNumber or game.Game.NumberOfTurns or 0
	local publicEvent = {
		ID = messageID,
		Turn = turnNumber,
		SenderID = order.PlayerID,
		RecipientID = recipientID,
		SenderName = senderName,
		RecipientName = recipientName,
	}
	local privateMessage = {
		ID = messageID,
		Turn = turnNumber,
		SenderID = order.PlayerID,
		RecipientID = recipientID,
		SenderName = senderName,
		RecipientName = recipientName,
		Message = message,
	}

	-- PublicGameData intentionally stores only metadata. Message content stays in per-player data.
	publicData.CommunicationLog = CommAppendLimited(publicData.CommunicationLog, publicEvent, COMM_PUBLIC_LOG_LIMIT)
	recipientData.CommunicationInbox = CommAppendLimited(recipientData.CommunicationInbox, privateMessage, COMM_PRIVATE_HISTORY_LIMIT)
	senderData.CommunicationSent = CommAppendLimited(senderData.CommunicationSent, privateMessage, COMM_PRIVATE_HISTORY_LIMIT)

	Mod.PlayerGameData = playerData
	Mod.PublicGameData = publicData

	local publicText = "Diplomacy: " .. senderName .. " sent a private message to " .. recipientName
	-- Do not add another normal turn event here. The original custom-card order
	-- already shows the public metadata to everyone, while the recipient gets the
	-- actual content through PlayerGameData + Client_GameRefresh.
	Log(publicText .. " (message " .. tostring(messageID) .. ")")
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Start(game, addNewOrder)
	Mod.PublicGameData = CommEnsurePublicData(Mod.PublicGameData)
end

---@param game GameServerHook
---@param order GameOrder
---@param orderResult GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_Order(game, order, orderResult, skipThisOrder, addNewOrder)
	if IsCommunicationCardOrder(order) then
		---@cast order GameOrderPlayCardCustom
		DeliverCommunicationCardMessage(game, order, addNewOrder)
	end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function Server_AdvanceTurn_End(game, addNewOrder)
end
