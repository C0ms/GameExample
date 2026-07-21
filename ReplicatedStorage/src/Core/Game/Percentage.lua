-- @ScriptType: ModuleScript
-- Conversion.lua

local Conversion = {}

-- Returns a decimal percentage.
-- Example:
-- GetPercentage(100, 0.001) = 0.10 (10%)
-- GetPercentage(50, 0.002) = 0.10 (10%)x
function Conversion.GetPercentage(value: number, rate: number): number
	return value * rate
end

-- Returns a multiplier.
-- Example:
-- GetMultiplier(100, 0.001) = 1.10
function Conversion.GetMultiplier(value: number, rate: number): number
	return 1 + Conversion.GetPercentage(value, rate)
end

-- Applies the multiplier to a base value.
-- Example:
-- Apply(50, 100, 0.001) = 55
function Conversion.Apply(base: number, value: number, rate: number): number
	return base * Conversion.GetMultiplier(value, rate)
end

-- Returns just the bonus amount.
-- Example:
-- GetBonus(50, 100, 0.001) = 5
function Conversion.GetBonus(base: number, value: number, rate: number): number
	return base * Conversion.GetPercentage(value, rate)
end

return Conversion