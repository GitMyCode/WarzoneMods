local DEFAULT_TROOPS_REWARD = 10
local DEFAULT_GOLD_REWARD = 10

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

	if FixedTroopsRewardInput == nil or FixedGoldRewardInput == nil then
		alert("Could not read settings inputs. Please reopen the settings and try again.")
		return
	end

	local troopsReward = ToInt(FixedTroopsRewardInput.GetValue())
	local goldReward = ToInt(FixedGoldRewardInput.GetValue())

	if troopsReward < 0 then
		alert("Fixed troops reward must be 0 or greater")
		return
	end
	if goldReward < 0 then
		alert("Fixed gold reward must be 0 or greater")
		return
	end
	if troopsReward > 100000 then
		alert("Fixed troops reward is too high")
		return
	end
	if goldReward > 100000 then
		alert("Fixed gold reward is too high")
		return
	end

	Mod.Settings.FixedTroopsReward = troopsReward
	Mod.Settings.FixedGoldReward = goldReward

	if Mod.Settings.FixedTroopsReward == nil then
		Mod.Settings.FixedTroopsReward = DEFAULT_TROOPS_REWARD
	end
	if Mod.Settings.FixedGoldReward == nil then
		Mod.Settings.FixedGoldReward = DEFAULT_GOLD_REWARD
	end
end
