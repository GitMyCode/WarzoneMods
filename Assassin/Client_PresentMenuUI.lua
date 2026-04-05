---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number) # Sets the max size of the dialog
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean) # Set whether the dialog is scrollable both horizontal and vertically
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
	setMaxSize(500, 400)
	setScrollable(false, true)

	local vert = UI.CreateVerticalLayoutGroup(rootParent)

	UI.CreateLabel(vert).SetText("Assassin Mode").SetColor("#FF4444")
	UI.CreateLabel(vert).SetText(" ")

	local publicData = Mod.PublicGameData or {}
	local gameEnded = publicData.AssassinGameEnded == true

	if gameEnded then
		ShowPostGameUI(vert, game, publicData)
	elseif game.Us == nil then
		ShowSpectatorUI(vert)
	else
		ShowActiveGameUI(vert, game)
	end

	UI.CreateLabel(vert).SetText(" ")
	local closeButton = UI.CreateButton(vert).SetText("Close")
	closeButton.SetOnClick(function()
		close()
	end)
end

---Show the post-game target reveal with winner and all assignments
---@param vert VerticalLayoutGroup
---@param game GameClientHook
---@param publicData table
function ShowPostGameUI(vert, game, publicData)
	local winnerID = publicData.AssassinWinnerID
	local targetID = publicData.AssassinWinnerTargetID

	-- Winner announcement
	if winnerID and game.Game.Players[winnerID] then
		local winnerName = game.Game.Players[winnerID].DisplayName(nil, false)
		local targetName = "their target"
		if targetID and game.Game.Players[targetID] then
			targetName = game.Game.Players[targetID].DisplayName(nil, false)
		end

		UI.CreateLabel(vert).SetText("Game Over!").SetColor("#FFAA00")
		UI.CreateLabel(vert).SetText(" ")
		UI.CreateLabel(vert).SetText(winnerName .. " won by eliminating " .. targetName .. "!").SetColor("#00FF00")
	else
		UI.CreateLabel(vert).SetText("Game Over!").SetColor("#FFAA00")
	end

	-- All target assignments
	local allTargets = publicData.AllTargets
	if allTargets then
		UI.CreateLabel(vert).SetText(" ")
		UI.CreateLabel(vert).SetText("All Target Assignments:").SetColor("#AAAAFF")
		UI.CreateLabel(vert).SetText(" ")

		for pid, tid in pairs(allTargets) do
			local assassinName = "Unknown"
			local tName = "Unknown"
			if game.Game.Players[pid] then
				assassinName = game.Game.Players[pid].DisplayName(nil, false)
			end
			if tid and game.Game.Players[tid] then
				tName = game.Game.Players[tid].DisplayName(nil, false)
			end

			local marker = ""
			if winnerID and pid == winnerID then
				marker = " (WINNER)"
			end

			UI.CreateLabel(vert).SetText(assassinName .. " -> " .. tName .. marker)
		end
	end
end

---Show a message for spectators during an active game
---@param vert VerticalLayoutGroup
function ShowSpectatorUI(vert)
	UI.CreateLabel(vert).SetText("You are spectating this game.")
	UI.CreateLabel(vert).SetText(" ")
	UI.CreateLabel(vert).SetText("Target assignments are secret until the game ends.")
	UI.CreateLabel(vert).SetText("Check back after the game to see all targets!")
end

---Show the current player's target during an active game
---@param vert VerticalLayoutGroup
---@param game GameClientHook
function ShowActiveGameUI(vert, game)
	local targetID = nil
	if Mod.PlayerGameData and Mod.PlayerGameData.Target then
		targetID = Mod.PlayerGameData.Target
	end

	if targetID and game.Game.Players[targetID] then
		local targetName = game.Game.Players[targetID].DisplayName(nil, false)

		UI.CreateLabel(vert).SetText("Your target is:")
		UI.CreateLabel(vert).SetText(" ")

		local targetLabel = UI.CreateLabel(vert)
		targetLabel.SetText(targetName)
		targetLabel.SetColor("#FFAA00")
		targetLabel.SetFlexibleWidth(1)

		UI.CreateLabel(vert).SetText(" ")
		UI.CreateLabel(vert).SetText("If your target is eliminated — by you")
		UI.CreateLabel(vert).SetText("or anyone else — you win!")
	else
		UI.CreateLabel(vert).SetText("No target assigned yet...")
		UI.CreateLabel(vert).SetText(" ")
		UI.CreateLabel(vert).SetText("Your target will be assigned at game start.")
	end
end
