-- @ScriptType: ModuleScript
--[[

Usage:

local FormatNumber = require(path.To.FormatNumber)

print(FormatNumber(123))             --> "123"
print(FormatNumber(1234))            --> "1.23K"
print(FormatNumber(1234567))         --> "1.23M"
print(FormatNumber(9876543210))      --> "9.87B"

-- Optional: Specify how many digits to show.
print(FormatNumber(1234567, 4))      --> "1.234M"

TextLabel.Text = FormatNumber(123, 3)

]]

local Suffixes = require(script.Parent.Suffixes)
local DEFAULT_SHOWN_DIGITS = 3

return function(n: number, numShownDigits: number?)
	local prefix = ""
	numShownDigits = numShownDigits or DEFAULT_SHOWN_DIGITS

	if n < 0 then
		n = math.abs(n)
		prefix = "-"
	end

	--string formatted integer
	local int = ("%.0f"):format(n)
	local numDigits = #int

	if numDigits <= 3 then
		return prefix .. int
	end

	local suffix: string? = Suffixes[math.ceil(numDigits / 3)]
	local decimalPosition = (numDigits - 1) % 3 + 1

	if not suffix then
		suffix = "e" .. math.ceil((numDigits - 3) / 3) * 3
	end

	-- construct the abbreviated number
	local abbreviatedNumber = string.sub(int, 1, decimalPosition)
	if decimalPosition < numShownDigits then
		abbreviatedNumber ..= "." .. string.sub(int, decimalPosition + 1, numShownDigits)
	end

	return prefix .. abbreviatedNumber .. suffix
end