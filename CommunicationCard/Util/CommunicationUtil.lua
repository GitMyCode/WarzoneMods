COMM_PAYLOAD_PREFIX = "LimitedPrivateDiplomacy|v1|"

COMM_DEFAULT_CARD_PIECES_FOR_WHOLE = 4
COMM_DEFAULT_CARD_MINIMUM_PIECES_PER_TURN = 1
COMM_DEFAULT_CARD_INITIAL_PIECES = 0
COMM_DEFAULT_CARD_WEIGHT = 1
COMM_DEFAULT_MAX_MESSAGE_LENGTH = 500

COMM_PUBLIC_LOG_LIMIT = 100
COMM_PRIVATE_HISTORY_LIMIT = 100
COMM_MENU_LOG_LIMIT = 12

COMM_MAX_CONFIG_CARD_PIECES = 100
COMM_MAX_CONFIG_INITIAL_PIECES = 500
COMM_MAX_CONFIG_CARD_WEIGHT = 1000
COMM_MAX_CONFIG_MESSAGE_LENGTH = 2000
COMM_MIN_CONFIG_MESSAGE_LENGTH = 20

---@param value any
---@param fallback number
---@return number
function CommReadNonNegativeNumber(value, fallback)
	if type(value) ~= "number" then
		return fallback
	end
	if value < 0 then
		return fallback
	end
	return value
end

---@param value any
---@param fallback integer
---@return integer
function CommReadNonNegativeInt(value, fallback)
	return math.floor(CommReadNonNegativeNumber(value, fallback))
end

---@param settings table | nil
---@return integer
function CommGetCardPiecesForWhole(settings)
	local pieces = CommReadNonNegativeInt(settings and settings.CommunicationPiecesForWholeCard or nil, COMM_DEFAULT_CARD_PIECES_FOR_WHOLE)
	if pieces < 1 then
		return 1
	end
	return pieces
end

---@param settings table | nil
---@return integer
function CommGetCardMinimumPiecesPerTurn(settings)
	return CommReadNonNegativeInt(settings and settings.CommunicationMinimumPiecesPerTurn or nil, COMM_DEFAULT_CARD_MINIMUM_PIECES_PER_TURN)
end

---@param settings table | nil
---@return integer
function CommGetCardInitialPieces(settings)
	return CommReadNonNegativeInt(settings and settings.CommunicationInitialPieces or nil, COMM_DEFAULT_CARD_INITIAL_PIECES)
end

---@param settings table | nil
---@return number
function CommGetCardWeight(settings)
	return CommReadNonNegativeNumber(settings and settings.CommunicationCardWeight or nil, COMM_DEFAULT_CARD_WEIGHT)
end

---@param settings table | nil
---@return integer
function CommGetMaxMessageLength(settings)
	local maxLength = CommReadNonNegativeInt(settings and settings.CommunicationMaxMessageLength or nil, COMM_DEFAULT_MAX_MESSAGE_LENGTH)
	if maxLength < COMM_MIN_CONFIG_MESSAGE_LENGTH then
		return COMM_MIN_CONFIG_MESSAGE_LENGTH
	end
	if maxLength > COMM_MAX_CONFIG_MESSAGE_LENGTH then
		return COMM_MAX_CONFIG_MESSAGE_LENGTH
	end
	return maxLength
end

---@param settings table | nil
---@return boolean
function CommRequireBuiltInPrivateMessagingDisabled(settings)
	if settings ~= nil and settings.CommunicationRequirePrivateMessagingDisabled == false then
		return false
	end
	return true
end

---@param recipientID PlayerID
---@param message string
---@return string
function CommCreatePayload(recipientID, message)
	message = message or ""
	return COMM_PAYLOAD_PREFIX .. tostring(recipientID) .. "|" .. tostring(#message) .. "|" .. message
end

---@param payload string | nil
---@return table | nil
function CommParsePayload(payload)
	if type(payload) ~= "string" then
		return nil
	end
	if string.sub(payload, 1, #COMM_PAYLOAD_PREFIX) ~= COMM_PAYLOAD_PREFIX then
		return nil
	end

	local body = string.sub(payload, #COMM_PAYLOAD_PREFIX + 1)
	local recipientID, lengthText, message = string.match(body, "^([^|]+)|(%d+)|(.*)$")
	if recipientID == nil or message == nil then
		return nil
	end

	local expectedLength = tonumber(lengthText)
	if expectedLength ~= nil and expectedLength >= 0 and #message > expectedLength then
		message = string.sub(message, 1, expectedLength)
	end

	return {
		RecipientID = recipientID,
		Message = message,
	}
end

---@param publicData table | nil
---@return table
function CommEnsurePublicData(publicData)
	publicData = publicData or {}
	publicData.CommunicationLog = publicData.CommunicationLog or {}
	publicData.CommunicationNextMessageID = CommReadNonNegativeInt(publicData.CommunicationNextMessageID, 1)
	if publicData.CommunicationNextMessageID < 1 then
		publicData.CommunicationNextMessageID = 1
	end
	return publicData
end

---@param playerData table
---@param playerID PlayerID
---@return table
function CommEnsureOnePlayerData(playerData, playerID)
	playerData[playerID] = playerData[playerID] or {}
	local data = playerData[playerID]
	data.CommunicationInbox = data.CommunicationInbox or {}
	data.CommunicationSent = data.CommunicationSent or {}
	data.CommunicationReadUpTo = CommReadNonNegativeInt(data.CommunicationReadUpTo, 0)
	return data
end

---@param value string | nil
---@return string
function CommTrim(value)
	if type(value) ~= "string" then
		return ""
	end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

---@param value string | nil
---@param maxLength integer
---@return string
function CommTruncate(value, maxLength)
	value = value or ""
	if #value <= maxLength then
		return value
	end
	if maxLength <= 3 then
		return string.sub(value, 1, maxLength)
	end
	return string.sub(value, 1, maxLength - 3) .. "..."
end

---@param a PlayerID | nil
---@param b PlayerID | nil
---@return boolean
function CommSamePlayerID(a, b)
	if a == nil or b == nil then
		return false
	end
	if a == b then
		return true
	end
	return tostring(a) == tostring(b)
end

---@param players table<PlayerID, GamePlayer> | nil
---@param value any
---@return PlayerID | nil
function CommResolvePlayerID(players, value)
	if players == nil or value == nil then
		return nil
	end
	if players[value] ~= nil then
		return value
	end

	local str = tostring(value)
	for playerID, _ in pairs(players) do
		if tostring(playerID) == str then
			return playerID
		end
	end

	local asNumber = tonumber(str)
	if asNumber ~= nil and players[asNumber] ~= nil then
		return asNumber
	end

	return nil
end

---@param game GameClientHook | GameServerHook
---@param playerID PlayerID | nil
---@return string
function CommPlayerName(game, playerID)
	if playerID == nil then
		return "Unknown"
	end
	if playerID == WL.PlayerID.Neutral then
		return "Neutral"
	end
	if game ~= nil and game.Game ~= nil and game.Game.Players ~= nil then
		local resolved = CommResolvePlayerID(game.Game.Players, playerID)
		if resolved ~= nil and game.Game.Players[resolved] ~= nil then
			return game.Game.Players[resolved].DisplayName(nil, false)
		end
	end
	return tostring(playerID)
end

---@param list table | nil
---@param item table
---@param limit integer
---@return table
function CommAppendLimited(list, item, limit)
	list = list or {}
	table.insert(list, item)
	while #list > limit do
		table.remove(list, 1)
	end
	return list
end

---@param log table | nil
---@return integer
function CommMaxLogID(log)
	local maxID = 0
	if log == nil then
		return maxID
	end
	for _, event in ipairs(log) do
		local id = CommReadNonNegativeInt(event and event.ID or nil, 0)
		if id > maxID then
			maxID = id
		end
	end
	return maxID
end

---@param event table
---@param game GameClientHook | GameServerHook
---@return string
function CommFormatPublicEvent(event, game)
	local senderName = event.SenderName or CommPlayerName(game, event.SenderID)
	local recipientName = event.RecipientName or CommPlayerName(game, event.RecipientID)
	local turnText = "Turn " .. tostring(event.Turn or "?")
	return turnText .. ": " .. senderName .. " sent a private message to " .. recipientName
end

---@param game GameClientHook | GameServerHook
---@return table[]
function CommSortedRecipients(game)
	local recipients = {}
	if game == nil or game.Game == nil or game.Game.PlayingPlayers == nil or game.Us == nil then
		return recipients
	end

	for playerID, player in pairs(game.Game.PlayingPlayers) do
		if not CommSamePlayerID(playerID, game.Us.ID) then
			table.insert(recipients, {
				ID = playerID,
				Name = player.DisplayName(nil, false),
			})
		end
	end

	table.sort(recipients, function(a, b)
		return tostring(a.Name) < tostring(b.Name)
	end)

	return recipients
end
