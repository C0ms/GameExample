-- @ScriptType: ModuleScript
--[[
Usage:

local FormatCurrency = require(path.To.FormatCurrency)

print(FormatCurrency(123))           --> "$123"
print(FormatCurrency(12345))         --> "$12,345"
print(FormatCurrency(1234567))       --> "$1,234,567"
print(FormatCurrency(123456789))     --> "$123.45M"
]]

local Abbreviate = require(script.Parent.Abbreviate)

return function(n: number): string
	if n >= 10e6 then
		return "x" .. Abbreviate(n, 5)
	end

	local str = tostring(math.round(n))

	-- Handle sign
	local sign = ""
	if string.sub(str, 1, 1) == "-" then
		sign = "-"
		str = string.sub(str, 2)
	end

	-- Insert commas
	while true do
		local newStr, count = str:gsub("^(%d+)(%d%d%d)", "%1,%2")
		str = newStr
		if count == 0 then
			break
		end
	end

	return sign .. "x" .. str
end