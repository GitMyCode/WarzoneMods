---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
	UI.CreateLabel(rootParent).SetText("Bounty Mode")
	UI.CreateLabel(rootParent)
		.SetText("Bounty reward: " .. tostring(Mod.Settings.BountyReward) .. " armies per elimination")
end
