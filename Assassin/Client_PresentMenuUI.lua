require("Annotations")

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number) # Sets the max size of the dialog
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean) # Set whether the dialog is scrollable both horizontal and vertically
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
	setMaxSize(500, 300)
	setScrollable(false, true)

	local vert = UI.CreateVerticalLayoutGroup(rootParent)

	UI.CreateLabel(vert).SetText("🎯 Assassin Mode").SetColor("#FF4444")
	UI.CreateLabel(vert).SetText(" ")

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
		UI.CreateLabel(vert).SetText("Eliminate them to win the game!")
	else
		UI.CreateLabel(vert).SetText("No target assigned yet...")
		UI.CreateLabel(vert).SetText(" ")
		UI.CreateLabel(vert).SetText("Your target will be assigned at game start.")
	end

	UI.CreateLabel(vert).SetText(" ")
	local closeButton = UI.CreateButton(vert).SetText("Close")
	closeButton.SetOnClick(function()
		close()
	end)
end
