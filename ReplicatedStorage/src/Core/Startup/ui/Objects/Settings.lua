-- @ScriptType: ModuleScript
--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Global

local Settings = {}
Settings.__index = Settings

local Player = game.Players.LocalPlayer

--// Modules

const Icon = require(ReplicatedStorage.src.Packages.Icon)
const UISlider = require(ReplicatedStorage.src.Core.ui.UISlider)
const networker = require(ReplicatedStorage.src.Shared.networker)
const RoundToDecimals = require(ReplicatedStorage.src.Core.ui.RoundToDecimals)

--// Main 

function Settings.init(GuiObject: Instance)
	local self = setmetatable({}, Settings)
	self.GuiObject = GuiObject :: Folder
	self.MainUI = self.GuiObject.Main
	
	-- icon
	self.SettingsIcon = Icon.new()
	self.SettingsIcon:setImage(7059346373)
	
	-- inputs
	self.SettingsIcon.selected:Connect(function()
		self:Open()
	end)

	self.SettingsIcon.deselected:Connect(function()
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