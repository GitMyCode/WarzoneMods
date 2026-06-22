require("Util/CommunicationUtil")

---@param game GameServerHook
local function InitializeCommunicationState(game)
	local publicData = CommEnsurePublicData(Mod.PublicGameData)
	local playerData = Mod.PlayerGameData or {}

	for playerID, _ in pairs(game.Game.PlayingPlayers) do
		CommEnsureOnePlayerData(playerData, playerID)
	end

	publicData.CommunicationInitialized = true
	Mod.PlayerGameData = playerData
	Mod.PublicGameData = publicData
end

---Server_StartDistribution hook
---@param game GameServerHook
---@param standing GameStanding
function Server_StartDistribution(game, standing)
	InitializeCommunicationState(game)
end
