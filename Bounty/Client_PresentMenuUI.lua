---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number)
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean)
---@param game GameClientHook
---@param close fun()
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
	setMaxSize(500, 280)
	setScrollable(false, true)

	local troopsReward = Mod.Settings and Mod.Settings.FixedTroopsReward or 10
	local goldReward = Mod.Settings and Mod.Settings.FixedGoldReward or 10

	local vert = UI.CreateVerticalLayoutGroup(rootParent)
	UI.CreateLabel(vert).SetText("Bounty Mode")
	UI.CreateLabel(vert).SetText("Eliminate players to earn rewards.")
	UI.CreateLabel(vert).SetText("Normal games reward troops: +" .. tostring(troopsReward))
	UI.CreateLabel(vert).SetText("Commerce games reward gold: +" .. tostring(goldReward))

	UI.CreateLabel(vert).SetText("Trap kills from blockade/abandon are credited to the trap owner.")
	UI.CreateLabel(vert).SetText("Trap attribution is removed once the territory is conquered.")

	UI.CreateButton(vert).SetText("Close").SetOnClick(function()
		close()
	end)
end
