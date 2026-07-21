-- @ScriptType: ModuleScript
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const SoundService = game:GetService("SoundService")

local MusicServiceClient = {}
MusicServiceClient.__index = MusicServiceClient

const DataService = require(ReplicatedStorage.src.Packages.DataService).client

const MusicFolder = script.Parent:WaitForChild("Songs")

function MusicServiceClient:PlayRandomSong()
	local Songs = MusicFolder:GetChildren()
	local NextSong = Songs[math.random(1, #Songs)]

	if #Songs > 1 then
		while NextSong == self.CurrentSong do
			NextSong = Songs[math.random(1, #Songs)]
		end
	end

	self.CurrentSong = NextSong
	self.Sound.SoundId = NextSong.SoundId
	self.Sound:Play()
end

function MusicServiceClient.init()
	local self = setmetatable({}, MusicServiceClient)
	self.MusicVolume = DataService:get({"settings", "MusicVolume"})
	self.CurrentSong = nil

	self.Sound = Instance.new("Sound")
	self.Sound.Name = "BackgroundMusic"
	self.Sound.Volume = self.MusicVolume
	self.Sound.Looped = false
	self.Sound.Parent = SoundService

	DataService:getChangedSignal({"settings", "MusicVolume"}):Connect(function(NewVolume)
		self.MusicVolume = NewVolume
		self.Sound.Volume = NewVolume
	end)

	self.Sound.Ended:Connect(function()
		self:PlayRandomSong()
	end)

	self:PlayRandomSong()

	return self
end

return MusicServiceClient