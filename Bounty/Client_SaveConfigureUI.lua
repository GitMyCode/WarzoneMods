local DEFAULT_REWARD = 10

---@param value number
---@return integer
local function ToInt(value)
	return math.floor(value)
end

---Client_SaveConfigureUI hook
---@param alert fun(message: string)
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
	if Mod.Settings == nil then
		Mod.Settings = {}
	end

	if BountyRewardInput == nil then
		alert("Could not read settings inputs. Please reopen the settings and try again.")
		return
	end

	local reward = ToInt(BountyRewardInput.GetValue())

	if reward < 0 then
		alert("Bounty reward must be 0 or greater")
		return
	end
	if reward > 100000 then
		alert("Bounty reward is too high")
		return
	end

	Mod.Settings.BountyReward = reward

	if Mod.Settings.BountyReward == nil then
		Mod.Settings.BountyReward = DEFAULT_REWARD
	end
end
