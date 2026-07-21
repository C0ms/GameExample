-- @ScriptType: ModuleScript
--@param n -> Number
--@param d -> Decimals
return function(n, d)
	local Mult = 10 ^ d
	return math.round(n * Mult) / Mult
end