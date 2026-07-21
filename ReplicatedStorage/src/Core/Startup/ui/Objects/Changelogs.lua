-- @ScriptType: ModuleScript
--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Global

local Settings = {}
Settings.__index = Settings

local Player = game.Players.LocalPlayer

--// Modules

const Icon = require(ReplicatedStorage.src.Packages.Icon)
const networker = require(ReplicatedStorage.src.Shared.networker)

--// Main 

function Settings.init(GuiObject: Instance)
	local self = setmetatable({}, Settings)
	self.GuiObject = GuiObject :: Folder
	self.MainUI = self.GuiObject.Main
	
	self.Changelogs = Icon.new()
	self.Changelogs:setImage(133824470118301)
	self.Changelogs:align("Right")
	
	self.Changelogs.selected:Connect(function()
		self:Open()
	end)

	self.Changelogs.deselected:Connect(function()
		self:Close()
	end)
	
	return self
end

function Settings:Open()
	self.MainUI.Visible = true
end

function Settings:Close()
	self.MainUI.Visible = false
end

return Settings