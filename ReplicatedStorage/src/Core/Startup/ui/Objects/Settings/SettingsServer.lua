-- @ScriptType: ModuleScript
local SettingsServer = {}
SettingsServer.__index = SettingsServer

function SettingsServer.init()
	local self = setmetatable({}, SettingsServer)
	
	
	return self
end

return SettingsServer