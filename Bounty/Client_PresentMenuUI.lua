require("Util/BountyReward")

local COLOR_TITLE = "#FFFFFF"
local COLOR_ACCENT = "#FFD966"
local COLOR_MUTED = "#BFBFBF"
local COLOR_TEXT = "#E6E6E6"

---@param parent UIObject
---@param height number
local function AddSpacer(parent, height)
	UI.CreateEmpty(parent).SetPreferredHeight(height)
end

---@param parent UIObject
---@param text string
local function AddSectionTitle(parent, text)
	UI.CreateLabel(parent).SetText(text).SetColor(COLOR_TITLE)
end

---@param parent UIObject
---@param label string
---@param value string
---@param accentValue boolean | nil
local function AddKeyValue(parent, label, value, accentValue)
	local row = UI.CreateHorizontalLayoutGroup(parent)
	UI.CreateLabel(row).SetText(label).SetColor(COLOR_MUTED).SetPreferredWidth(190)
	local valueLabel = UI.CreateLabel(row).SetText(value)
	if accentValue then
		valueLabel.SetColor(COLOR_ACCENT)
	else
		valueLabel.SetColor(COLOR_TEXT)
	end
end

---@param parent UIObject
---@param reward integer
local function AddNextBonus(parent, reward)
	AddSectionTitle(parent, "NEXT BONUS")
	local row = UI.CreateHorizontalLayoutGroup(parent)
	UI.CreateLabel(row).SetText("+" .. tostring(reward)).SetColor(COLOR_ACCENT).SetPreferredWidth(140)
	UI.CreateLabel(row).SetText("armies").SetColor(COLOR_TEXT)
end

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number)
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean)
---@param game GameClientHook
---@param close fun()
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
	setMaxSize(650, 360)
	setScrollable(false, true)

	local settings = Mod.Settings or {}
	local publicData = Mod.PublicGameData or {}
	local mode = BountyGetRewardMode(settings)
	local reward = BountyGetBaseReward(settings)
	local nextReward = BountyNextReward(settings, publicData)

	local vert = UI.CreateVerticalLayoutGroup(rootParent)
	UI.CreateLabel(vert).SetText("Bounty Mode").SetColor(COLOR_TITLE)
	AddSpacer(vert, 8)

	AddNextBonus(vert, nextReward)
	AddSpacer(vert, 10)

	if mode == BOUNTY_REWARD_MODE_ESCALATING then
		local percent = BountyGetEscalationPercent(settings)
		local count = BountyGetEscalatingRewardCount(publicData)
		AddSectionTitle(vert, "Escalating bounty")
		AddKeyValue(vert, "Starts at", "+" .. tostring(reward) .. " armies")
		AddKeyValue(vert, "Increase", "+" .. tostring(percent) .. "% after each rewarded elimination", true)
		AddKeyValue(vert, "This reward", "#" .. tostring(count + 1), true)
		AddKeyValue(vert, "Rewards granted", tostring(count))
	else
		AddSectionTitle(vert, "Fixed bounty")
		AddKeyValue(vert, "Reward", "+" .. tostring(reward) .. " armies per elimination", true)
		UI.CreateLabel(vert).SetText("Every credited elimination grants the same bonus.").SetColor(COLOR_TEXT)
	end

	AddSpacer(vert, 10)
	AddSectionTitle(vert, "Attribution")
	UI.CreateLabel(vert).SetText("- Successful attack: attacker gets the reward").SetColor(COLOR_TEXT)
	UI.CreateLabel(vert).SetText("- Failed attack where attacker dies: defender gets the reward").SetColor(COLOR_TEXT)
	UI.CreateLabel(vert).SetText("- Blockade/Abandon trap kills: trap owner gets the reward").SetColor(COLOR_TEXT)
	UI.CreateLabel(vert).SetText("Trap credit is cleared once the territory is conquered.").SetColor(COLOR_MUTED)
end
