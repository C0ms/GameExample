-- @ScriptType: ModuleScript
local GroupService = game:GetService("GroupService")

return function(userid: number, groupId: number)
	local success, result = pcall(function()
		return GroupService:GetGroupsAsync(userid)
	end)

	if not success or not result then
		warn("Failed to get groups for user", userid, result)
		return false
	end

	for _, group in result do
		if group.Id == groupId then
			return true
		end
	end

	return false
end