require("Util/BountyReward")

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
	local settings = Mod.Settings or {}
	local mode = BountyGetRewardMode(settings)
	local reward = BountyGetBaseReward(settings)

	UI.CreateLabel(rootParent).SetText("Bounty Mode")
	if mode == BOUNTY_REWARD_MODE_ESCALATING then
		local percent = BountyGetEscalationPercent(settings)
		UI.CreateLabel(rootParent)
			.SetText(
				"Escalating bounty: starts at "
					.. tostring(reward)
					.. " armies, +"
					.. tostring(percent)
					.. "% per rewarded elimination, rounded to nearest"
			)
	else
		UI.CreateLabel(rootParent).SetText("Fixed bounty: " .. tostring(reward) .. " armies per elimination")
	end
end
