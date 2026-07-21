-- @ScriptType: LocalScript
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const ButtonServiceClient = require(ReplicatedStorage.src.Core.Features.Button.ButtonServiceClient)
const MusicServiceClient = require(ReplicatedStorage.src.Core.Features.Music.MusicServiceClient)

const networker = require(ReplicatedStorage.src.Shared.networker)
const DataService = require(ReplicatedStorage.src.Packages.DataService).client
const Console = require(ReplicatedStorage.src.Packages.Console)

DataService:init()
MusicServiceClient.init()
ButtonServiceClient.init()

Console.Print(script, "Fully Created.")