require("Util/AssassinUtil")

---Server_GameCustomMessage
---@param game GameServerHook
---@param playerID PlayerID
---@param payload table
---@param setReturn fun(payload: table) # Sets the table that will be returned to the client when the custom message has been processed
function Server_GameCustomMessage(game, playerID, payload, setReturn)
	if payload.action == "popup_shown" then
		-- Mark that player has seen the target popup
		local data = Mod.PlayerGameData
		if data and data[playerID] then
			data[playerID].PopupShown = true
			Mod.PlayerGameData = data
			print("[Assassin] Popup marked as shown for player " .. tostring(playerID))
		end
		setReturn({ success = true })
		return
	end

	if payload.action == "get_target" then
		local data = Mod.PlayerGameData
		local targetID = nil
		local popupShown = false
		if data and data[playerID] then
			targetID = data[playerID].Target
			popupShown = data[playerID].PopupShown == true
		end
		if data ~= nil then
			Mod.PlayerGameData = data
		end
		setReturn({ success = true, targetID = targetID, popupShown = popupShown })
		return
	end
	-- elseif payload.action == "reassign" then
	-- 	-- Reassign targets for testing
	-- 	local targets = AssignTargets(game)

	-- 	-- Debug: log what we're about to save
	-- 	print("=== REASSIGN DEBUG ===")
	-- 	print("Targets generated:")
	-- 	for pid, tid in pairs(targets) do
	-- 		print("  Player " .. tostring(pid) .. " -> Target " .. tostring(tid))
	-- 	end

	-- 	SaveTargets(targets)

	-- 	-- Debug: verify what was saved
	-- 	print("Mod.PlayerGameData after save:")
	-- 	if Mod.PlayerGameData then
	-- 		for pid, data in pairs(Mod.PlayerGameData) do
	-- 			print("  PlayerID " .. tostring(pid) .. ":")
	-- 			if type(data) == "table" then
	-- 				for k, v in pairs(data) do
	-- 					print("    " .. tostring(k) .. " = " .. tostring(v))
	-- 				end
	-- 			else
	-- 				print("    data is " .. type(data))
	-- 			end
	-- 		end
	-- 	else
	-- 		print("  Mod.PlayerGameData is nil!")
	-- 	end
	-- 	print("=== END DEBUG ===")

	-- 	setReturn({ success = true, numTargets = getTableSize(targets) })
	-- end
end

function getTableSize(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end
