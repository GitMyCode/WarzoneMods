require("Util/BountyReward")

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
	local settings = Mod.Settings or {}
	local mode = BountyGetRewardMode(settings)
	local reward = BountyGetBaseReward(settings)

	UI.CreateLabel(rootParent).SetText("Bounty Mode")
	if mode == BOUNTY_REWARD_MODE_GLOBAL_GROWTH then
		UI.CreateLabel(rootParent)
			.SetText(
				"Global bounty growth: everyone starts worth "
					.. tostring(reward)
					.. " armies; every credited elimination increases everyone's bounty by "
					.. BountyGrowthDescription(settings)
			)
	elseif mode == BOUNTY_REWARD_MODE_KILL_COUNT then
		UI.CreateLabel(rootParent)
			.SetText(
				"Kill-count bounty growth: everyone starts worth "
					.. tostring(reward)
					.. " armies; each player's own bounty increases by "
					.. BountyGrowthDescription(settings)
					.. " per credited kill"
			)
	elseif mode == BOUNTY_REWARD_MODE_INHERITANCE then
		UI.CreateLabel(rootParent)
			.SetText(
				"Stacking bounty: everyone starts worth "
					.. tostring(reward)
					.. " armies; when a player eliminates someone, that player's bounty is added to the killer's own bounty"
			)
	else
		UI.CreateLabel(rootParent).SetText("Fixed bounty: " .. tostring(reward) .. " armies per elimination")
	end
end
