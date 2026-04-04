---Server_GameCustomMessage hook
---@param game GameServerHook
---@param playerID PlayerID
---@param payload table
---@param setReturn fun(payload: table)
function Server_GameCustomMessage(game, playerID, payload, setReturn)
	setReturn({ success = true })
end
