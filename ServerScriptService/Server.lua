-- @ScriptType: Script
--// Services

const ServerScriptService = game:GetService("ServerScriptService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerStorage = game:GetService("ServerStorage")

--// Global

--// Modules

const ButtonServiceServer = require(ReplicatedStorage.src.Core.Features.Button.ButtonServiceClient.ButtonServiceServer)
const SettingsServer = require(ReplicatedStorage.src.Core.Startup.ui.Objects.Settings.SettingsServer)
const DataTemplate = require(ReplicatedStorage.src.Packages.DataService.DataTemplate)
const DataService = require(ReplicatedStorage.src.Packages.DataService).server
const networker = require(ReplicatedStorage.src.Shared.networker)
const Console = require(ReplicatedStorage.src.Packages.Console)
const version = require(ReplicatedStorage.src.version)

--// Main

ButtonServiceServer.init()
SettingsServer.init()

function DataService:onPlayerInit(player, data)
	--print("Loading Data for: ".. player.Name.. "/".. player.DisplayName)
	--print(data)
	data.sessionStart = os.time()
end

DataService:addPlayerRemovingCallback(function(player, data)
	local playTime = os.time() - data.sessionStart
	data.stats.timePlayed += playTime
	--print("Saving Data for: ".. player.Name.. "/".. player.DisplayName)
	--print(data)
end)

DataService:init({
	template = DataTemplate,
	profileStoreIndex = "test",
	useMock = false,
	resetData = false,
	dontSave = false,
	--viewedUserId = 00000000,
	--overridenUserId = 000000000,
})

ReplicatedStorage:SetAttribute("ServerLoaded", true)
Console.Print(script, "Fully Created. | Version: ".. version)