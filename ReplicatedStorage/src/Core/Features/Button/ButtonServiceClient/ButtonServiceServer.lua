-- @ScriptType: ModuleScript
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerStorage = game:GetService("ServerStorage")

local ButtonServiceServer = {}
ButtonServiceServer.__index = ButtonServiceServer

const networker = require(ReplicatedStorage.src.Shared.networker)
const DataService = require(ReplicatedStorage.src.Packages.DataService).server
const CalculateValue = require(ReplicatedStorage.src.Core.Game.CalculateValue)
const Console = require(ReplicatedStorage.src.Packages.Console)

function ButtonServiceServer.init()
	local self = setmetatable({}, ButtonServiceServer)
	self.Button = workspace.Main.Button.Hitbox.ClickDetector
	self.Combos = {}

	self.Button.MouseClick:Connect(function(player)
		local CalculatedValue = CalculateValue(player)
		networker.ReplicateClick:FireClient(player, CalculatedValue)

		DataService:update(player, {"currency"}, function(CurrentValue)
			return CurrentValue + CalculatedValue
		end)

		self:AddCombo(player)
	end)

	Console.Print(script, " Initialized")

	return self
end

function ButtonServiceServer:AddCombo(player)
	local data = self.Combos[player]

	if not data then
		data = {Value = 0, LastClick = 0, Thread = nil}
		self.Combos[player] = data

		networker.UpdateCombo:FireClient(player, "create", 0)
	end

	data.Value += 1
	data.LastClick = os.clock()
	
	player:SetAttribute("Combo", data.Value)

	networker.UpdateCombo:FireClient(player, "update", data.Value)

	if data.Thread then
		task.cancel(data.Thread)
	end

	data.Thread = task.delay(1.5, function()
		if os.clock() - data.LastClick >= 1 then
			data.Value = 0
			self.Combos[player] = nil
			networker.UpdateCombo:FireClient(player, "reset", 0)
		end
	end)
end

return ButtonServiceServer