-- @ScriptType: Script
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Console = require(ReplicatedStorage.src.Packages.Console)

game.Loaded:Connect(function()
	for _, GuiObjects in game.Players.LocalPlayer.PlayerGui:WaitForChild("Main"):WaitForChild("Top"):WaitForChild("GuiObjects"):GetChildren() do
		if GuiObjects:IsA("Folder") then
			local moduleobj = ReplicatedStorage.src.Core.Startup.ui.Objects:FindFirstChild(GuiObjects.Name) :: ModuleScript
			if not moduleobj then warn("err : ".. GuiObjects.Name, " not found") return end
			local RequiredModule = require(moduleobj)
			RequiredModule.init(GuiObjects)
		end
	end

	Console.Print(script, "all ui loaded")
end)
