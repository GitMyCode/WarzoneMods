require("Util/CommunicationUtil")

local publicLogInitialized = false
local lastSeenPublicEventID = 0
local lastAlertedPrivateMessageID = 0

---@param game GameClientHook
---@return boolean
local function IsActivePlayer(game)
	return game ~= nil
		and game.Us ~= nil
		and game.Game ~= nil
		and game.Game.PlayingPlayers ~= nil
		and CommResolvePlayerID(game.Game.PlayingPlayers, game.Us.ID) ~= nil
end

---@param game GameClientHook
local function AlertNewPublicEvents(game)
	local publicData = Mod.PublicGameData or {}
	local log = publicData.CommunicationLog or {}
	local maxID = CommMaxLogID(log)

	if not publicLogInitialized then
		publicLogInitialized = true
		lastSeenPublicEventID = maxID
		return
	end

	if maxID <= lastSeenPublicEventID then
		return
	end

	local newest = nil
	for _, event in ipairs(log) do
		local id = CommReadNonNegativeInt(event.ID, 0)
		if id > lastSeenPublicEventID and (newest == nil or id > CommReadNonNegativeInt(newest.ID, 0)) then
			newest = event
		end
	end

	lastSeenPublicEventID = maxID
	if newest ~= nil then
		UI.Alert("Diplomacy activity:\n\n" .. CommFormatPublicEvent(newest, game) .. "\n\nOnly sender and recipient can read the content.")
	end
end

---@param game GameClientHook
local function AlertUnreadPrivateMessage(game)
	if not IsActivePlayer(game) then
		return
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

	game.SendGameCustomMessage("Marking message read...", {
		action = "mark_read",
		messageID = maxUnreadID,
	}, function(_) end)
end

---Client_GameRefresh hook
---@param game GameClientHook
function Client_GameRefresh(game)
	AlertNewPublicEvents(game)
	AlertUnreadPrivateMessage(game)
end
