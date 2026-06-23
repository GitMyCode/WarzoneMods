require("Util/CommunicationUtil")

---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings
---@param alert fun(message: string)
function Client_CreateGame(settings, alert)
	-- GameTemplate is read-only in this client hook.
	-- Built-in private messaging is disabled in Server_Created, where settings are writable.
end
