-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Console = {}
Console.__index = Console

function Console.Print(script: Instance, Message: string)
	if ReplicatedStorage.DEBUG_MODE.Value == false then return end
	print("[".. script.Name.. "]: ".. Message)
end

function Console.Warn(script: Instance, Message: string)
	if ReplicatedStorage.DEBUG_MODE.Value == false then return end
	warn("[".. script.Name.. "]: ".. Message)
end

return Console