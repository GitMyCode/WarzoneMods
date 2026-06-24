require("Util/CommunicationUtil")

local lastAlertedPrivateMessageID = 0
local lastGameID = nil

---@param game GameClientHook
---@return boolean
local function CanSendCustomMessage(game)
	return game ~= nil
		and game.Us ~= nil
		and game.Game ~= nil
		and game.Game.PlayingPlayers ~= nil
		and CommResolvePlayerID(game.Game.PlayingPlayers, game.Us.ID) ~= nil
end

---@param game GameClientHook
local function AlertUnreadPrivateMessage(game)
	if game == nil or game.Us == nil then
		return
	end

	local gameID = game.Game and game.Game.ID or nil
	if gameID ~= lastGameID then
		lastGameID = gameID
		lastAlertedPrivateMessageID = 0
	end

	local playerData = Mod.PlayerGameData or {}
	local inbox = playerData.CommunicationInbox or {}
	local readUpTo = CommReadNonNegativeInt(playerData.CommunicationReadUpTo, 0)
	local newest = nil
	local maxUnreadID = 0

	for _, message in ipairs(inbox) do
		local id = CommReadNonNegativeInt(message.ID, 0)
		if id > readUpTo then
			if id > maxUnreadID then
				maxUnreadID = id
			end
			if id > lastAlertedPrivateMessageID and (newest == nil or id > CommReadNonNegativeInt(newest.ID, 0)) then
				newest = message
			end
		end
	end

	-- If read state was not persisted yet, still show the newest unread message
	-- once after a reload/new game even when message IDs restart from 1.
	if newest == nil and maxUnreadID > readUpTo and lastAlertedPrivateMessageID == 0 then
		for _, message in ipairs(inbox) do
			local id = CommReadNonNegativeInt(message.ID, 0)
			if id == maxUnreadID then
				newest = message
				break
			end
		end
	end

	if newest == nil then
		return
	end

	lastAlertedPrivateMessageID = CommReadNonNegativeInt(newest.ID, 0)
	UI.Alert(
		"New Communication Card message from "
			.. tostring(newest.SenderName or CommPlayerName(game, newest.SenderID))
			.. ":\n\n"
			.. tostring(newest.Message or "")
			.. "\n\nOpen the Mod menu to reread it."
	)

	-- Spectators and non-playing users cannot send custom messages. The popup still
	-- shows from PlayerGameData, but only active players persist read state.
	if CanSendCustomMessage(game) then
		game.SendGameCustomMessage("Marking message read...", {
			action = "mark_read",
			messageID = maxUnreadID,
		}, function(_) end)
	end
end

---Client_GameRefresh hook
---@param game GameClientHook
function Client_GameRefresh(game)
	AlertUnreadPrivateMessage(game)
end
