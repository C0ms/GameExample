-- @ScriptType: ModuleScript
local SuperTween = {}
SuperTween.__index = SuperTween

local TweenService = game:GetService("TweenService")

function SuperTween.new(Object: Instance, Time: number, EasingStyle: Enum.EasingStyle, EasingDirection: Enum.EasingDirection, Properties: {[string]: any})
	local self = setmetatable({}, SuperTween)
	self.Object = Object
	self.Time = Time
	self.EasingStyle = EasingStyle
	self.EasingDirection = EasingDirection
	self.Properties = Properties
	self.TweenInfo = TweenInfo.new(Time, EasingStyle, EasingDirection)

	if Object:IsA("UIStroke") then
		if Properties.Transpareny then
			Properties.Transparency = Properties.Transpareny
			Properties.Transpareny = nil
		end
	end

	self.Tween = TweenService:Create(Object, self.TweenInfo, Properties)
	self.CompletedCallback = nil

	self.Tween.Completed:Connect(function()
		if self.CompletedCallback then
			self.CompletedCallback()
		end
	end)

	return self
end

function SuperTween:Play()
	if self.Tween then
		self.Tween:Play()
	end
end

function SuperTween:Pause()
	if self.Tween then
		self.Tween:Pause()
	end
end

function SuperTween:Cancel()
	if self.Tween then
		self.Tween:Cancel()
	end
end

function SuperTween:Destroy()
	if self.Tween then
		self.Tween:Cancel()
		self.Tween:Destroy()
		self.Tween = nil
	end
	setmetatable(self, nil)
end

function SuperTween:OnCompleted(callback)
	if typeof(callback) == "function" then
		self.CompletedCallback = callback
	end
end

return SuperTween