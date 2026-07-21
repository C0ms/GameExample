-- @ScriptType: ModuleScript
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const DataServiceServer = require(ReplicatedStorage.src.Packages.DataService).server
const DataServiceClient = require(ReplicatedStorage.src.Packages.DataService).client

const Percentage = require(ReplicatedStorage.src.Core.Game.Percentage)

return function(player: Player)
	local combo = player:GetAttribute("Combo") or 0
	--local comboMultiplier = Percentage.GetMultiplier(combo, 0.01)

	if RunService:IsServer() then
		local base = DataServiceServer:get(player, {"upgrades", "BaseClickValue"})
		local multi = DataServiceServer:get(player, {"upgrades", "BaseMultiplier"})

		return base * multi
	else
		local base = DataServiceClient:get({"upgrades", "BaseClickValue"})
		local multi = DataServiceClient:get({"upgrades", "BaseMultiplier"})

		return base * multi
	end
end