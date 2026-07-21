-- @ScriptType: ModuleScript
export type Tweak = {
	primaryColor: number,
	hue: number?,
	forcedhue: number?,
	saturation: number?,
	saturationBoost: number?,
	value: number?,
	range: number?,
	valueBoost: number?,
	pseudoRandom: boolean?,
}

type Tweaks = Tweak | { Tweak }

local DEFAULT_RANGE = 1 / 6

local ColorTweaker = {
	enums = {
		primaryColors = {
			red = 0,
			yellow = 1 / 6,
			green = 2 / 6,
			cyan = 3 / 6,
			blue = 4 / 6,
			magenta = 5 / 6,
			master = -1,
		},
	},
}

local function _pseudoRandomHue(_h: number): number
	return math.random()
	--local pseudoRandom = (math.sin(h * 2 * math.pi) * 43758.5453) % 1
	--return pseudoRandom
end

local function wrappedDistance(x: number, y: number): number
	local diff = math.abs(x - y)
	return math.min(diff, 1 - diff)
end

local function tweakColor(color: Color3, tweak: Tweak): Color3
	local h, s, v = Color3.toHSV(color)

	local shouldTweak = tweak.primaryColor == ColorTweaker.enums.primaryColors.master
		or wrappedDistance(h, tweak.primaryColor) < (tweak.range or DEFAULT_RANGE)

	if not shouldTweak then
		return color
	end

	h = if tweak.forcedhue then tweak.forcedhue else (h + (tweak.hue or 0)) % 1
	s = math.clamp((tweak.saturationBoost or 1) * (s + (tweak.saturation or 0)), 0, 1)
	v = math.clamp((tweak.valueBoost or 1) * (v + (tweak.value or 0)), 0, 1)

	return Color3.fromHSV(h, s, v)
end

function ColorTweaker.tweakColorSequence(colorSequence: ColorSequence, tweaks: Tweaks): ColorSequence
	local newKeypoints = {}
	for _, keypoint in ipairs(colorSequence.Keypoints) do
		local color = ColorTweaker.tweak(keypoint.Value, tweaks)
		table.insert(newKeypoints, ColorSequenceKeypoint.new(keypoint.Time, color))
	end

	return ColorSequence.new(newKeypoints)
end

function ColorTweaker.tweak(color: Color3, tweaks: Tweaks): Color3
	if tweaks[1] then
		for _, tweak in ipairs(tweaks) do
			color = tweakColor(color, tweak)
		end
	else
		color = tweakColor(color, tweaks :: Tweak)
	end

	return color
end

local ORIGINAL_COLOR_ATTRIBUTE_NAME = "OriginalColor"
function ColorTweaker.setInstanceOriginalColor(instance: any)
	if instance:IsA("BasePart") or instance:IsA("Light") or instance:IsA("ParticleEmitter") or instance:IsA("Beam") then
		instance:SetAttribute(ORIGINAL_COLOR_ATTRIBUTE_NAME, instance.Color)
	elseif instance:IsA("Decal") then
		instance:SetAttribute(ORIGINAL_COLOR_ATTRIBUTE_NAME, instance.Color3)
	elseif instance:IsA("SpecialMesh") then
		local vertexColor = instance.VertexColor
		local color = Color3.new(vertexColor.X, vertexColor.Y, vertexColor.Z)
		instance:SetAttribute(ORIGINAL_COLOR_ATTRIBUTE_NAME, color)
	end
end

function ColorTweaker.fromInstance(instance: any, tweaks: Tweaks, useOriginalColorAttribute: boolean?): ()
	local original = useOriginalColorAttribute and instance:GetAttribute(ORIGINAL_COLOR_ATTRIBUTE_NAME)
	if instance:IsA("BasePart") or instance:IsA("Light") then
		instance.Color = ColorTweaker.tweak(original or instance.Color, tweaks)
		if instance:IsA("UnionOperation") then
			instance.UsePartColor = true
		end
	elseif instance:IsA("Decal") then
		instance.Color3 = ColorTweaker.tweak(original or instance.Color3, tweaks)
	elseif instance:IsA("SpecialMesh") then
		local vertexColor = instance.VertexColor
		local color = original or Color3.new(vertexColor.X, vertexColor.Y, vertexColor.Z)
		color = ColorTweaker.tweak(color, tweaks)
		instance.VertexColor = Vector3.new(color.r, color.g, color.b)
	elseif instance:IsA("ParticleEmitter") or instance:IsA("Beam") then
		instance.Color = ColorTweaker.tweakColorSequence(original or instance.Color, tweaks)
	end
end

function ColorTweaker.fromContainer(container: Model | Folder, tweaks: Tweaks, useOriginalColorAttribute: boolean?): ()
	for _, instance in container:GetDescendants() do
		ColorTweaker.fromInstance(instance, tweaks, useOriginalColorAttribute)
	end
end

function ColorTweaker.setContainerOriginalColor(container: Model | Folder): ()
	for _, instance in container:GetDescendants() do
		ColorTweaker.setInstanceOriginalColor(instance)
	end
end

return ColorTweaker