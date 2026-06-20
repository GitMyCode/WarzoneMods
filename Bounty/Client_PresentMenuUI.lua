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
	UI.CreateLabel(row).SetText(label).SetColor(COLOR_MUTED).SetPreferredWidth(220)
	local valueLabel = UI.CreateLabel(row).SetText(value)
	if accentValue then
		valueLabel.SetColor(COLOR_ACCENT)
	else
		valueLabel.SetColor(COLOR_TEXT)
	end
end

---@param parent UIObject
---@param reward integer
---@param title string
local function AddBonus(parent, reward, title)
	AddSectionTitle(parent, title)
	local row = UI.CreateHorizontalLayoutGroup(parent)
	UI.CreateLabel(row).SetText("+" .. tostring(reward)).SetColor(COLOR_ACCENT).SetPreferredWidth(140)
	UI.CreateLabel(row).SetText("armies").SetColor(COLOR_TEXT)
end

---@param game GameClientHook
---@return PlayerID | nil
local function LocalPlayerID(game)
	if game == nil or game.Us == nil then
		return nil
	end
	return game.Us.ID or game.Us.PlayerID
end

---@param player GamePlayer | nil
---@param playerID PlayerID
---@return string
local function PlayerName(player, playerID)
	if player == nil then
		return tostring(playerID)
	end
	return player.DisplayName(nil, false)
end

---@param game GameClientHook
---@param settings table
---@param publicData table
---@param localPlayerID PlayerID | nil
---@return table[]
local function BuildBountyRows(game, settings, publicData, localPlayerID)
	local rows = {}
	local gameWL = game and game.Game or nil
	local players = gameWL and (gameWL.PlayingPlayers or gameWL.Players) or {}
	for playerID, player in pairs(players) do
		local kills = BountyGetPlayerKillCount(publicData, playerID)
		local bounty = BountyPlayerBounty(settings, publicData, playerID)
		table.insert(rows, {
			Name = PlayerName(player, playerID),
			PlayerID = playerID,
			Kills = kills,
			Bounty = bounty,
			IsUs = localPlayerID ~= nil and tostring(localPlayerID) == tostring(playerID),
		})
	end

	table.sort(rows, function(a, b)
		if a.Bounty ~= b.Bounty then
			return a.Bounty > b.Bounty
		end
		return a.Name < b.Name
	end)

	return rows
end

---@param parent UIObject
---@param rows table[]
local function AddCurrentBounties(parent, rows)
	AddSectionTitle(parent, "CURRENT PLAYER BOUNTIES")
	if #rows == 0 then
		UI.CreateLabel(parent).SetText("No active player bounties to show.").SetColor(COLOR_TEXT)
		return
	end

	for _, row in ipairs(rows) do
		local name = row.Name
		if row.IsUs then
			name = name .. " (you)"
		end

		local value = "+" .. tostring(row.Bounty) .. " armies"
		if row.Kills > 0 then
			value = value .. " (" .. tostring(row.Kills) .. " kills)"
		end

		AddKeyValue(parent, name, value, row.IsUs)
	end
end

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number)
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean)
---@param game GameClientHook
---@param close fun()
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
	setMaxSize(720, 520)
	setScrollable(false, true)

	local settings = Mod.Settings or {}
	local publicData = Mod.PublicGameData or {}
	local mode = BountyGetRewardMode(settings)
	local reward = BountyGetBaseReward(settings)
	local localPlayerID = LocalPlayerID(game)

	local vert = UI.CreateVerticalLayoutGroup(rootParent)
	UI.CreateLabel(vert).SetText("Bounty Mode").SetColor(COLOR_TITLE)
	AddSpacer(vert, 8)

	if mode == BOUNTY_REWARD_MODE_GLOBAL_GROWTH then
		local currentReward = BountyNextReward(settings, publicData, nil)
		AddBonus(vert, currentReward, "CURRENT GLOBAL BOUNTY")
		AddKeyValue(vert, "Starting bounty", "+" .. tostring(reward) .. " armies")
		AddKeyValue(vert, "Growth", BountyGrowthDescription(settings) .. " after each credited elimination", true)
		AddKeyValue(vert, "Credited eliminations", tostring(BountyGetGlobalBountyCount(publicData)))
		UI.CreateLabel(vert).SetText("Every player's bounty is the same and grows globally after each credited kill.").SetColor(COLOR_TEXT)
	elseif BountyRewardModeUsesPlayerBounties(mode) then
		local ownBounty = localPlayerID ~= nil and BountyPlayerBounty(settings, publicData, localPlayerID) or nil

		if ownBounty ~= nil then
			AddBonus(vert, ownBounty, "YOUR CURRENT BOUNTY")
			AddKeyValue(vert, "Your credited kills", tostring(BountyGetPlayerKillCount(publicData, localPlayerID)), true)
		else
			AddSectionTitle(vert, "PLAYER BOUNTIES")
			UI.CreateLabel(vert).SetText("Killing a player pays that player's current bounty.").SetColor(COLOR_TEXT)
		end

		AddKeyValue(vert, "Starting bounty", "+" .. tostring(reward) .. " armies")
		if mode == BOUNTY_REWARD_MODE_KILL_COUNT then
			AddKeyValue(vert, "Growth", BountyGrowthDescription(settings) .. " per credited kill", true)
			UI.CreateLabel(vert).SetText("Players with the same number of kills have the same bounty.").SetColor(COLOR_TEXT)
		else
			AddKeyValue(vert, "Stacking rule", "Eliminated player's bounty is added to the killer's bounty", true)
			UI.CreateLabel(vert).SetText("Big bounties can stack onto the player who takes them down.").SetColor(COLOR_TEXT)
		end

		AddSpacer(vert, 10)
		AddCurrentBounties(vert, BuildBountyRows(game, settings, publicData, localPlayerID))
	else
		AddBonus(vert, reward, "ELIMINATION BONUS")
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
