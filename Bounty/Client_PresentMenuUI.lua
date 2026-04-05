---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number)
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean)
---@param game GameClientHook
---@param close fun()
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
	setMaxSize(500, 250)
	setScrollable(false, true)

	local reward = Mod.Settings and Mod.Settings.BountyReward or 10

	local vert = UI.CreateVerticalLayoutGroup(rootParent)
	UI.CreateLabel(vert).SetText("Bounty Mode")
	UI.CreateLabel(vert).SetText("Eliminate a player to earn +" .. tostring(reward) .. " bonus armies.")
	UI.CreateLabel(vert).SetText("Trap kills from blockade/abandon are credited to the trap owner.")
	UI.CreateLabel(vert).SetText("Trap attribution is removed once the territory is conquered.")

	UI.CreateButton(vert).SetText("Close").SetOnClick(function()
		close()
	end)
end
