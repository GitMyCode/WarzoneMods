require("Util/CommunicationUtil")

---@param game GameServerHook
---@param playerID PlayerID
---@param payload table
---@param setReturn fun(payload: table)
local function HandleMarkRead(game, playerID, payload, setReturn)
	local messageID = CommReadNonNegativeInt(payload.messageID, 0)
	local playerData = Mod.PlayerGameData or {}
	local data = CommEnsureOnePlayerData(playerData, playerID)
	if messageID > data.CommunicationReadUpTo then
		data.CommunicationReadUpTo = messageID
	end
	Mod.PlayerGameData = playerData
	setReturn({ success = true })
end

---Server_GameCustomMessage hook
---@param game GameServerHook
---@param playerID PlayerID
---@param payload table
---@param setReturn fun(payload: table)
function Server_GameCustomMessage(game, playerID, payload, setReturn)
	if payload == nil or payload.action == nil then
		setReturn({ success = false, message = "Invalid diplomacy request." })
		return
	end

	if payload.action == "mark_read" then
		HandleMarkRead(game, playerID, payload, setReturn)
		return
	end

	setReturn({ success = false, message = "Unknown diplomacy action." })
end
