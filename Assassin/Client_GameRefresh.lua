local popupShownThisSession = false
local requestedTargetThisSession = false

---@param game GameClientHook
---@param targetID PlayerID
local function ShowTargetPopupAndPersist(game, targetID)
	if popupShownThisSession then
		return
	end

	local targetPlayer = game.Game.Players[targetID]
	if targetPlayer == nil then
		return
	end

	local targetName = targetPlayer.DisplayName(nil, false)
	UI.Alert(
		"🎯 ASSASSIN MODE\n\nYour target is: "
			.. targetName
			.. "\n\nEliminate them to win the game!\n\n(You can check your target anytime from the Mod menu)"
	)
	popupShownThisSession = true

	game.SendGameCustomMessage("Marking popup as shown...", { action = "popup_shown" }, function(_) end)
end

---Client_GameRefresh hook
---@param game GameClientHook
function Client_GameRefresh(game)
	-- Spectators (and any non-playing users) cannot send game custom messages.
	-- This hook previously sent messages to fetch/persist target state, which causes
	-- a pcall failure when the game is opened in spectator mode.
	local us = game.Us
	if us == nil or game.Game == nil or game.Game.PlayingPlayers == nil or game.Game.PlayingPlayers[us.ID] == nil then
		return
	end

	if popupShownThisSession then
		return
	end

	-- Show target popup when player first enters the game (only once per game)
	if Mod.PlayerGameData and Mod.PlayerGameData.Target and not Mod.PlayerGameData.PopupShown then
		ShowTargetPopupAndPersist(game, Mod.PlayerGameData.Target)
	end

	-- If target hasn't arrived on the client yet, request it once so the popup can show immediately.
	if not requestedTargetThisSession then
		local playerData = Mod.PlayerGameData
		if playerData == nil or (playerData.Target == nil and playerData.PopupShown ~= true) then
			requestedTargetThisSession = true
			game.SendGameCustomMessage("Fetching target...", { action = "get_target" }, function(response)
				if response == nil or response.targetID == nil or response.popupShown == true then
					return
				end

				ShowTargetPopupAndPersist(game, response.targetID)
			end)
		end
	end
end
