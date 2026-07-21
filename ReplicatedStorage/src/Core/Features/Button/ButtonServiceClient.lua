-- @ScriptType: ModuleScript
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

local ButtonServiceClient = {}
ButtonServiceClient.__index = ButtonServiceClient

const Spring = require(ReplicatedStorage.src.Packages.Spring)
const networker = require(ReplicatedStorage.src.Shared.networker)
const Console = require(ReplicatedStorage.src.Packages.Console)
const FormatCurrency = require(ReplicatedStorage.src.Core.ui.FormatCurrency)
const DataService = require(ReplicatedStorage.src.Packages.DataService).client
const SuperTween = require(ReplicatedStorage.src.Core.ui.SuperTween)

const Constants = require(ReplicatedStorage.src.Core.Features.Button.Util.Constants)

function ButtonServiceClient.init()
	local self = setmetatable({}, ButtonServiceClient)
	local Main = game.Workspace:WaitForChild("Main")
	self.ButtonFolder = Main:WaitForChild("Button")
	self.ButtonTop = self.ButtonFolder:WaitForChild("Top")
	self.ButtonOutline = self.ButtonTop:WaitForChild("Outline")

	self.ButtonBottom = self.ButtonFolder:WaitForChild("Bottom")
	self.ButtonBottomOutline = self.ButtonBottom:WaitForChild("BottomOutline")

	self.TopBasePosition = self.ButtonTop.Position
	self.ButtonOutlineBasePosition = self.ButtonOutline.Position
	self.ButtonBottomOutlineBasePosition = self.ButtonBottomOutline.Position
	self.BottomBasePosition = self.ButtonBottom.Position
	self.BottomBaseSize = self.ButtonBottom.Size
	self.BottomOutlineBaseSize = self.ButtonBottomOutline.Size

	self.VfxDisplay = self.ButtonFolder:WaitForChild("Center")
	self.StatDisplay = self.ButtonFolder:WaitForChild("Display")

	self.StatBaseSize = self.StatDisplay.Size

	self.Center = self.ButtonFolder:WaitForChild("Center")
	self.Display = self.ButtonFolder:WaitForChild("Display")
	self.HasPositionedDisplay = false

	self.Player = game.Players.LocalPlayer
	self.Character = self.Player.Character or self.Player.CharacterAdded:Wait()
	self.Camera = game.Workspace.CurrentCamera

	local SurfaceGui = self.Display:WaitForChild("SurfaceGui")
	local DropShadow = SurfaceGui:WaitForChild("DropShadow")
	self.TextDisplay = DropShadow:WaitForChild("Display")
	self.DropShadowDisplay = DropShadow

	local StreakDropShadow = SurfaceGui:WaitForChild("StreakDropShadow")
	self.ComboDisplay = StreakDropShadow:WaitForChild("Display")
	self.ComboShadowDisplay = StreakDropShadow
	self.ComboBaseSize = self.ComboShadowDisplay.Size

	self.Spring = Spring.new(2.55, 0.6)
	self.ScaleSpring = Spring.new(2, 0.6)
	self.StatScaleSpring = Spring.new(4, 0.7)

	self.FOVSpring = Spring.new(2, 0.6)
	self.FOVSpring.Position = Vector3.new(Constants.DEFAULT_FOV, 0, 0)
	self.FOVSpring.Target = Vector3.new(Constants.DEFAULT_FOV, 0, 0)

	self.ScaleSpring.Position = Vector3.one
	self.ScaleSpring.Target = Vector3.one

	self.StatScaleSpring.Position = Vector3.one
	self.StatScaleSpring.Target = Vector3.one

	RunService.RenderStepped:Connect(function(dt)
		local offset = self.Spring:update(dt)
		local fov = self.FOVSpring:update(dt).X
		self.Camera.FieldOfView = fov

		self.ButtonTop.Position = self.TopBasePosition + offset
		self.ButtonOutline.Position = self.ButtonOutlineBasePosition + offset
		self.ButtonBottom.Position = self.BottomBasePosition + offset * 0.05 + Constants.BOTTOM_OFFSET * (-offset.Y / -Constants.PRESS_OFFSET.Y)
		self.ButtonBottomOutline.Position = self.BottomBasePosition + offset * 0.05 + Constants.BOTTOM_OFFSET * (-offset.Y / -Constants.PRESS_OFFSET.Y)

		local scale = self.ScaleSpring:update(dt).X

		self.ButtonBottom.Size = self.BottomBaseSize * scale
		self.ButtonBottomOutline.Size = self.BottomOutlineBaseSize * scale

		local statScale = self.StatScaleSpring:update(dt).X

		self.StatDisplay.Size = self.StatBaseSize * statScale

		self:UpdateDisplay(dt)
	end)

	DataService:getChangedSignal({"currency"}):Connect(function(newValue)
		self.TextDisplay.Text = FormatCurrency(newValue)
		self.DropShadowDisplay.Text = FormatCurrency(newValue)
	end)

	local currency = DataService:get({"currency"})
	self.TextDisplay.Text = FormatCurrency(currency)
	self.DropShadowDisplay.Text = FormatCurrency(currency)

	networker.ReplicateClick.OnClientEvent:Connect(function()
		self:EmitVFX()
		self:PlaySound()
		
		if DataService:get({"settings", "ClickFov"}) == true then
			self.FOVSpring.Target = Vector3.new(Constants.CLICK_FOV, 0, 0)
			
			task.delay(0.09, function()
				self.FOVSpring.Target = Vector3.new(Constants.DEFAULT_FOV, 0, 0)
			end)
		end

		self.Spring.Target = Constants.PRESS_OFFSET
		self.ScaleSpring.Target = Vector3.new(Constants.MAX_SCALE, Constants.MAX_SCALE, Constants.MAX_SCALE)
		self.StatScaleSpring.Target = Vector3.new(Constants.STAT_MAX_SCALE, Constants.STAT_MAX_SCALE, Constants.STAT_MAX_SCALE)

		task.delay(0.09, function()
			self.Spring.Target = Vector3.zero
			self.ScaleSpring.Target = Vector3.one
			self.StatScaleSpring.Target = Vector3.one
		end)
	end)

	networker.UpdateCombo.OnClientEvent:Connect(function(event, amount)
		self:UpdateStreak(event, amount)
	end)

	Console.Print(script, " Initialized")

	return self
end

function ButtonServiceClient:UpdateStreak(event: string, new: number)
	if event == "create" then
		self.ComboDisplay.Visible = false
		self.ComboShadowDisplay.Visible = false
		self.ComboShadowDisplay.Size = UDim2.fromScale(0.02, 0.02)
	elseif event == "update" then
		self.Combo = new

		if self.Combo > 2 then
			if not self.ComboDisplay.Visible then
				self.ComboDisplay.Visible = true
				self.ComboShadowDisplay.Visible = true

				self.ComboShadowDisplay.Size = UDim2.fromScale(0.02, 0.02)

				self.ComboDisplay.TextTransparency = 1
				self.ComboShadowDisplay.TextTransparency = 1

				self.ComboDisplay.UIStroke.Transparency = 1
				self.ComboShadowDisplay.UIStroke.Transparency = 1

				SuperTween.new(self.ComboShadowDisplay, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {Size = self.ComboBaseSize}):Play()

				SuperTween.new(self.ComboDisplay, 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, {TextTransparency = 0}):Play()
				SuperTween.new(self.ComboShadowDisplay, 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, {TextTransparency = 0}):Play()

				SuperTween.new(self.ComboDisplay.UIStroke, 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, {Transparency = 0}):Play()
				SuperTween.new(self.ComboShadowDisplay.UIStroke, 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, {Transparency = 0}):Play()
			end

			self.ComboDisplay.Text = "Combo " .. self.Combo .. "x"
			self.ComboShadowDisplay.Text = "Combo " .. self.Combo .. "x"
		end

	elseif event == "reset" then
		self.Combo = 0

		SuperTween.new(self.ComboShadowDisplay, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In, {Size = UDim2.fromScale(0.02, 0.02)}):Play()

		SuperTween.new(self.ComboDisplay, 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In, {TextTransparency = 1}):Play()
		SuperTween.new(self.ComboShadowDisplay, 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In, {TextTransparency = 1}):Play()

		SuperTween.new(self.ComboDisplay.UIStroke, 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In, {Transparency = 1}):Play()
		SuperTween.new(self.ComboShadowDisplay.UIStroke, 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In, {Transparency = 1}):Play()

		task.delay(0.35, function()
			self.ComboDisplay.Visible = false
			self.ComboShadowDisplay.Visible = false

			self.ComboShadowDisplay.Size = self.ComboBaseSize

			self.ComboDisplay.TextTransparency = 0
			self.ComboShadowDisplay.TextTransparency = 0
			self.ComboDisplay.UIStroke.Transparency = 0
			self.ComboShadowDisplay.UIStroke.Transparency = 0
		end)
	end
end

function ButtonServiceClient:UpdateDisplay(dt)
	self.Character = self.Player.Character or self.Character

	local HRP = self.Character:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	local centerPos = self.Center.Position
	local playerPos = HRP.Position

	local direction = Vector3.new(playerPos.X - centerPos.X,0,playerPos.Z - centerPos.Z)
	if direction.Magnitude <= 0.01 then return end

	direction = direction.Unit

	local currentY = self.Display:GetPivot().Position.Y
	local targetPos = Vector3.new(centerPos.X + direction.X * Constants.DISPLAY_OFFSET,currentY,centerPos.Z + direction.Z * Constants.DISPLAY_OFFSET)

	local targetCF =CFrame.lookAt(targetPos, targetPos + direction)* CFrame.Angles(Constants.DISPLAY_TILT, 0, 0)

	if not self.HasPositionedDisplay then
		self.Display:PivotTo(targetCF)
		self.HasPositionedDisplay = true
		return
	end

	self.Display:PivotTo(self.Display:GetPivot():Lerp(targetCF, Constants.DISPLAY_SMOOTHNESS))
end

function ButtonServiceClient:PlaySound()
	local Sound = Instance.new("Sound")
	Sound.SoundId = "rbxassetid://139719503904449"
	Sound.Volume = 5
	Sound.Parent = self.VfxDisplay
	Sound.RollOffMaxDistance = 250

	Sound:Play()

	Sound.Ended:Connect(function()
		Sound:Destroy()
	end)
end

function ButtonServiceClient:EmitVFX()
	local randomAttachments = {}

	for _, attachment in self.VfxDisplay:GetChildren() do
		if attachment:IsA("Attachment") then
			if attachment.Name == "Splash" then
				for _, particle in attachment:GetChildren() do
					if particle:IsA("ParticleEmitter") then
						particle:Emit(particle:GetAttribute("EmitCount") or 10)
					end
				end
			else
				table.insert(randomAttachments, attachment)
			end
		end
	end

	if #randomAttachments == 0 then
		return
	end

	local attachment = randomAttachments[math.random(1, #randomAttachments)]

	for _, particle in attachment:GetChildren() do
		if particle:IsA("ParticleEmitter") then
			particle:Emit(particle:GetAttribute("EmitCount") or 10)
		end
	end
end

return ButtonServiceClient