-- @ScriptType: ModuleScript
--[[

Usage:

local FormatTime = require(path.To.FormatTime)

print(FormatTime(45))       --> "45s"
print(FormatTime(90))       --> "1m 30s"
print(FormatTime(3661))     --> "1h 1m"
print(FormatTime(90061))    --> "1d 1h 1m"

]]


return function(t: number): string
	t = math.max(0, t)
	local days = t // 86400
	local hours = (t % 86400) // 3600
	local minutes = (t % 3600) // 60
	local seconds = t % 60
	local formatted = ""

	if days > 0 then
		formatted ..= `{days}d `
	end

	if hours > 0 then
		formatted ..= `{hours}h `
	end

	if minutes > 0 then
		formatted ..= `{minutes}m `
	end

	if seconds > 0 and days == 0 and hours == 0 then
		formatted ..= `{seconds}s`
	else
		formatted = formatted:sub(1, -2)
	end

	return formatted
end