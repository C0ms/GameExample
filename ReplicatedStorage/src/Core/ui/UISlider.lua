-- @ScriptType: ModuleScript
--!strict
--[[
	V1.0.1 (Added proper Mobile support)
	Author - RobloxJrTrainer
	
	Converts relative gui into a slider, that allows interacting of the 'thumb' (GuiButton).
	Needs 3 UI elements, a slider track frame, a slider fill frame, and a slider
	thumb button.
	
	When interacting with the thumb, it positions the button on the X axis, based on mouse movement and
	relative to the slider track frame . It also adjusts the slider fill frame as well.
	
	__Note:__ Only works for Keyboard + Mouse and Mobile devices. Does not support gamepad's.

	GUI Criteria Hierarchy:
	
	- SliderTrackFrame (Frame)
	Acts as the holder, or the maximum and minimum the slider can fill to the right and left
	
		- SliderFillFrame (Frame) (AnchorPoint.X: 0 or 1)
		How much the SliderTrackFrame is 'filled'. Note, __must__ have an AnchorPoint.X
		of 0 or 1, or else it will not size correct

		- SliderThumbButton (GuiButton)
		The button that can be interacted with, to slide the slider
	
]]
-- SERVICES --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- IMPORTS --
local Filter = require(script.Filter)
local Nexus = require(script.Nexus)

-- TYPES --
export type UISliderConfig = {
	sliderTrackFrame: Frame,
	sliderFillFrame: Frame,
	sliderThumbButton: GuiButton,
	stepSize: number?,
	interactable: boolean?,
	initialSliderValue: number?
}

export type UISliderInternals = {
	config: UISliderConfig,
	onSliderValueChanged: Nexus.Nexus,
	onSliderPressed: Nexus.Nexus,
	onSliderReleased: Nexus.Nexus,
	onSliderHovered: RBXScriptSignal,
	onSliderUnhovered: RBXScriptSignal,
	connections: {RBXScriptConnection},
	interactableConnectionIndex: number?,
	currentSliderValue: number
}

export type UISlider = {
	SetInteractable: (self: UISlider) -> (),
	SetUninteractable: (self: UISlider) -> (),
	IsInteractable: (self: UISlider) -> boolean,
	SetValue: (self: UISlider, value: number) -> (),
	GetValue: (self: UISlider) -> number,
	OnSliderValueChanged: (self: UISlider) -> Nexus.Nexus,
	OnSliderPressed: (self: UISlider) -> Nexus.Nexus,
	OnSliderReleased: (self: UISlider) -> Nexus.Nexus,
	OnSliderHovered: (self: UISlider) -> RBXScriptSignal,
	OnSliderUnhovered: (self: UISlider) -> RBXScriptSignal,
	SetStepSize: (self: UISlider, step: number) -> (),
	Destroy: (self: UISlider) -> ()
}

-- VARIABLES --

local UISlider = {}
local UISliderMt = {}
UISliderMt.__index = UISliderMt
UISliderMt.__newindex = function()
	error("Cannot add new keys to 'UISlider' object.")
end

local filter = Filter.new()

local privateData: {[UISlider]: UISliderInternals} = {}

local Field = Filter.Field


-- Setup a configuration schema
local CONFIG_SCHEMA = {
	sliderTrackFrame = Field("Instance"):Required(),
	sliderFillFrame = Field("Instance"):Validator(function(value: Frame)
		return value.AnchorPoint.X == 0 or value.AnchorPoint.X == 1 -- Anchor point must be 0 or 1
	end, `Expected 'AnchorPoint.X' to be 0 or 1`):Required(), -- Required
	sliderThumbButton = Field("Instance"):Required(), -- Required
	stepSize = Field("number"):Min(0):Max(0.25):Optional(0.05),
	interactable = Field("boolean"):Optional(false),
	initialSliderValue = Field("number"):Min(0):Max(1):Optional(0.5)
}
-- Define schema
filter:DefineSchema("UI_SLIDER_CONFIG", CONFIG_SCHEMA)

local PRESSED_RELEASED_INPUT_TYPES = {
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.MouseButton1] = true,
}

local MIN_VALUE, MAX_VALUE = 0, 1

-- CONSTANTS --


-- PRIVATE FUNCTIONS --

local function connectToAndStoreConnection(self: UISliderInternals, signal: any, func: (...any) -> ())
	local index = #self.connections + 1
	self.connections[index] = signal:Connect(func)
	return index
end

local function disconnectAndRemoveStoredConnection(self: UISliderInternals, index: number)
	local connection = self.connections[index]
	if connection and connection.Connected then
		connection:Disconnect()
		self.connections[index] = nil
	end
end

local function updateSliderTo(self: UISliderInternals, newValue: number)
	local sliderThumb = self.config.sliderThumbButton
	local sliderTrack = self.config.sliderTrackFrame
	local fillFrame = self.config.sliderFillFrame
	-- Make sure to clamp the value
	newValue = math.clamp(newValue, MIN_VALUE, MAX_VALUE)
	-- Invert thumb position if AnchorPoint.X == 1
	local thumbXPos = newValue
	if fillFrame.AnchorPoint.X == 1 then
		thumbXPos = 1 - newValue
	end
	sliderThumb.Position = UDim2.fromScale(thumbXPos, sliderThumb.Position.Y.Scale)
	-- Set currentSliderValue if the newValue is different from the current
	if self.currentSliderValue ~= newValue then
		local oldValue = self.currentSliderValue
		self.currentSliderValue = newValue
		-- Fire onSliderValueChanged signal
		self.onSliderValueChanged:Fire(oldValue, newValue)
	end
	-- Update fill frame to match
	fillFrame.Size = UDim2.fromScale(newValue, fillFrame.Size.Y.Scale)
	return newValue
end

local function checkAndStartInteractableSlider(self: UISliderInternals)
	-- Store the initial mouse position and thumb position when drag begins
	local initialMouseLocation = UIS:GetMouseLocation()
	local initialThumbPosition = self.config.sliderThumbButton.Position.X.Scale
	local fillFrame = self.config.sliderFillFrame
	self.interactableConnectionIndex = connectToAndStoreConnection(
		self,
		RunService.Heartbeat,
		function()
			if self.config.interactable then
				local currentMousePos = UIS:GetMouseLocation()
				local stepSize = self.config.stepSize :: number
				-- Calculate total movement from the initial press position
				local totalDelta = currentMousePos - initialMouseLocation
				local trackPixelWidth = self.config.sliderTrackFrame.AbsoluteSize.X
				local deltaX = totalDelta.X
				local valueMovement = deltaX / trackPixelWidth
				local newThumbPos = initialThumbPosition + valueMovement
				local newValue = fillFrame.AnchorPoint.X == 1 and 1 - newThumbPos or newThumbPos
				-- Prevent bad division
				if self.config.stepSize > 0 then
					newValue = math.round(newValue / stepSize) * stepSize
				end
				updateSliderTo(self, newValue)
			end
		end
	)
end

function isPositionInUIZone(position: Vector2, uiElement: GuiObject): boolean
	-- Get the absolute position and size of the UI element
	local absolutePosition = uiElement.AbsolutePosition
	local absoluteSize = uiElement.AbsoluteSize
	-- Get the bounds
	local leftBound = absolutePosition.X
	local rightBound = absolutePosition.X + absoluteSize.X
	local topBound = absolutePosition.Y
	local bottomBound = absolutePosition.Y + absoluteSize.Y
	-- Return true or false
	return position.X >= leftBound and position.X <= rightBound and
		position.Y >= topBound and position.Y <= bottomBound
end

local function onSliderThumbPressed(self: UISliderInternals, input: InputObject)
	local vector2Pos = Vector2.new(input.Position.X, input.Position.Y)
	if not isPositionInUIZone(vector2Pos, self.config.sliderThumbButton) then
		return
	end
	if PRESSED_RELEASED_INPUT_TYPES[input.UserInputType] then
		checkAndStartInteractableSlider(self)
		-- Fire onSliderPressed
		self.onSliderPressed:Fire(input)
	end
end

local function onSliderThumbReleased(self: UISliderInternals, input: InputObject)
	if PRESSED_RELEASED_INPUT_TYPES[input.UserInputType] then
		-- Check and disconnect interactable connection
		if self.interactableConnectionIndex ~= nil then
			disconnectAndRemoveStoredConnection(self, self.interactableConnectionIndex)
		end
		-- Fire onSliderReleased
		self.onSliderReleased:Fire(input)
	end
end

local function setupConnectionsAndSignals(self: UISliderInternals)
	local sliderThumb = self.config.sliderThumbButton
	-- Connect to InputBegan of our thumb button
	connectToAndStoreConnection(self, UIS.InputBegan, function(...)
		onSliderThumbPressed(self, ...)
	end)
	-- Connect to InputEnded as well
	connectToAndStoreConnection(self, UIS.InputEnded, function(...)
		onSliderThumbReleased(self, ...)
	end)
end

local function init(self: UISliderInternals)
	-- Setup connecions and signals
	setupConnectionsAndSignals(self)
	-- Initial slider update
	updateSliderTo(self, self.currentSliderValue)
end

-- CONSTRUCTOR --

--[[
	Creates a new UISlider instance from the provided configuration.
	
	The UISlider class provides an interactive slider component that can be controlled
	via mouse or touch input. It requires three UI elements: a track frame, fill frame,
	and thumb button to create a complete slider interface.
	
	@param config UISliderConfig -- Configuration object containing required UI elements and optional settings
	@return UISlider -- A new UISlider instance
	
	Example:
	```lua
	local slider = UISlider.new({
		sliderTrackFrame = trackFrame,
		sliderFillFrame = fillFrame,
		sliderThumbButton = thumbButton,
		stepSize = 0.1,
		interactable = true,
		initialSliderValue = 0.5
	})
	```
]]
function UISlider.new(config: UISliderConfig): UISlider
	-- Validate the config
	config = filter:ValidateStrict(config, "UI_SLIDER_CONFIG")
	-- Ensure
	local self: any = setmetatable({}, UISliderMt)
	local private: UISliderInternals = {
		config = config,
		-- Create some signals
		onSliderValueChanged = Nexus.new(),
		-- Use built-in events/signals if applicable
		onSliderPressed = Nexus.new(),
		onSliderReleased = Nexus.new(),
		onSliderHovered = config.sliderThumbButton.MouseEnter,
		onSliderUnhovered = config.sliderThumbButton.MouseLeave,
		connections = {},
		interactableConnectionIndex = nil,
		currentSliderValue = (config.initialSliderValue :: number)
	}
	privateData[self] = private
	init(privateData[self])
	return self
end

--[[
	Creates multiple UISlider instances from an array of configurations.
	
	This method accepts an array of UISliderConfig objects and creates a UISlider
	instance for each configuration by calling .new() internally. This is more
	convenient than manually creating multiple sliders when you have many to set up.
	
	@param configs {UISliderConfig} -- Array of configuration objects to create sliders from
	@return {UISlider} -- Array of UISlider instances that were created
	
	Example:
	```lua
	local sliders = UISlider.fromAll({
		{sliderTrackFrame = track1, sliderFillFrame = fill1, sliderThumbButton = thumb1},
		{sliderTrackFrame = track2, sliderFillFrame = fill2, sliderThumbButton = thumb2}
	})
	```
]]
function UISlider.fromAll(configs: {UISliderConfig}): {UISlider}
	assert(type(configs) == "table", `Expected a table, got '{configs}'`)
	local built = {}
	for _, config in ipairs(configs) do
		-- Call .new() for all
		-- Validation is done in the constructor
		local obj = UISlider.new(config)
		table.insert(built, obj)
	end
	return built
end

-- PUBLIC METHODS --

--[[
	Enables slider interaction.
	
	This method sets the slider to be interactable, allowing users to drag the thumb
	button to change the slider value. Interaction will begin on the next thumb button press.
	
	Example:
	```lua
	slider:SetInteractable() -- Slider can now be dragged
	```
]]
function UISliderMt:SetInteractable()
	privateData[self].config.interactable = true
end

--[[
	Disables slider interaction.
	
	This method prevents the slider from responding to user input. The thumb button
	will no longer be draggable and the slider value cannot be changed through interaction.
	
	Example:
	```lua
	slider:SetUninteractable() -- Slider is now read-only
	```
]]
function UISliderMt:SetUninteractable()
	privateData[self].config.interactable = false
end

--[[
	Checks whether the slider is currently interactable.
	
	This method returns the current interactable state of the slider, indicating
	whether users can drag the thumb button to change the slider value.
	
	@return boolean -- True if the slider is interactable, false otherwise
	
	Example:
	```lua
	if slider:IsInteractable() then
		print("Slider can be dragged")
	end
	```
]]
function UISliderMt:IsInteractable()
	return privateData[self].config.interactable
end

--[[
	Manually sets the slider to a specific value.
	
	This method programmatically updates the slider position and fill to represent
	the specified value. The value is clamped between 0 and 1, where 0 represents
	empty and 1 represents full. This will trigger the OnSliderValueChanged signal.
	
	@param value number -- The new slider value (0-1 range)
	
	Example:
	```lua
	slider:SetValue(0.75) -- Set slider to 75%
	```
]]
function UISliderMt:SetValue(value: number)
	assert(type(value) == "number", `Expected a number, got '{value}'`)
	updateSliderTo(privateData[self], value)
end

--[[
	Gets the current value of the slider.
	
	This method returns the slider's current value as a number between 0 and 1,
	where 0 represents the minimum value (empty) and 1 represents the maximum value (full).
	
	@return number -- The current slider value (0-1 range)
	
	Example:
	```lua
	local currentValue = slider:GetValue()
	print("Slider is at", currentValue * 100, "percent")
	```
]]
function UISliderMt:GetValue()
	return privateData[self].currentSliderValue
end

--[[
	Returns a signal that fires when the slider value changes.
	
	This method provides access to the signal that is fired whenever the slider's
	value is modified, either through user interaction or programmatic changes.
	The signal passes the old value and new value as parameters.
	
	@return Nexus.Nexus -- Signal that fires with (oldValue: number, newValue: number)
	
	Example:
	```lua
	slider:OnSliderValueChanged():Connect(function(oldValue, newValue)
		print("Slider changed from", oldValue, "to", newValue)
	end)
	```
]]
function UISliderMt:OnSliderValueChanged()
	return privateData[self].onSliderValueChanged
end

--[[
	Returns a signal that fires when the slider thumb is pressed down.
	
	This method provides access to the signal that is fired when the user begins
	pressing the slider thumb button. The signal passes the InputObject as a parameter.
	
	@return Nexus.Nexus -- Signal that fires with (input: InputObject)
	
	Example:
	```lua
	slider:OnSliderPressed():Connect(function(input)
		print("Slider thumb pressed with", input.UserInputType)
	end)
	```
]]
function UISliderMt:OnSliderPressed()
	return privateData[self].onSliderPressed
end

--[[
	Returns a signal that fires when the slider thumb is released.
	
	This method provides access to the signal that is fired when the user releases
	the slider thumb button after pressing it. The signal passes the InputObject as a parameter.
	
	@return Nexus.Nexus -- Signal that fires with (input: InputObject)
	
	Example:
	```lua
	slider:OnSliderReleased():Connect(function(input)
		print("Slider thumb released")
	end)
	```
]]
function UISliderMt:OnSliderReleased()
	return privateData[self].onSliderReleased
end

--[[
	Returns a signal that fires when the slider thumb is hovered.
	
	This method provides access to the built-in MouseEnter signal of the thumb button,
	which fires when the user's mouse cursor enters the thumb button area.
	
	@return RBXScriptSignal -- The MouseEnter signal of the thumb button
	
	Example:
	```lua
	slider:OnSliderHovered():Connect(function()
		print("Mouse is hovering over slider thumb")
	end)
	```
]]
function UISliderMt:OnSliderHovered()
	return privateData[self].onSliderHovered
end

--[[
	Returns a signal that fires when the slider thumb is no longer hovered.
	
	This method provides access to the built-in MouseLeave signal of the thumb button,
	which fires when the user's mouse cursor leaves the thumb button area.
	
	@return RBXScriptSignal -- The MouseLeave signal of the thumb button
	
	Example:
	```lua
	slider:OnSliderUnhovered():Connect(function()
		print("Mouse is no longer hovering over slider thumb")
	end)
	```
]]
function UISliderMt:OnSliderUnhovered()
	return privateData[self].onSliderUnhovered
end

--[[
	Sets the step size for slider value increments.
	
	This method configures how the slider value changes when dragged. A step size
	of 0 allows continuous movement, while larger values create discrete steps.
	For example, a step size of 0.1 would snap the slider to increments of 10%.
	
	@param step number -- The step size for value increments (0 for continuous movement)
	
	Example:
	```lua
	slider:SetStepSize(0.25) -- Slider snaps to 25% increments
	slider:SetStepSize(0) -- Slider moves continuously
	```
]]
function UISliderMt:SetStepSize(step: number)
	assert(type(step) == "number", `Expected a number, got '{step}'`)
	privateData[self].config.stepSize = step
end

--[[
	Completely destroys the UISlider instance.
	
	This method disconnects all registered connections, cleans up all signals,
	clears all private data, and removes the metatable. After calling this method,
	the instance should not be used anymore as it will no longer function properly.
	
	Example:
	```lua
	slider:Destroy() -- Instance is now unusable
	slider = nil -- Good practice to nil the reference
	```
]]
function UISliderMt:Destroy()
	while #privateData[self].connections > 0 do
		local index = #privateData[self].connections
		disconnectAndRemoveStoredConnection(privateData[self], index)
	end
	for k, v in pairs(privateData[self]) do
		-- Check if this value has a destroyable method
		if type(v) == "table" and type(v.Destroy) == "function" then
			v:Destroy()
		end
		privateData[self][k] = nil
	end
	privateData[self] = nil
	setmetatable(self, nil)
end

return UISlider