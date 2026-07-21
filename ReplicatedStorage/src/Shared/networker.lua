-- @ScriptType: ModuleScript
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Packet = require(ReplicatedStorage.src.Packages.Packet)

return {
	ReplicateClick = Packet("ReplicateClick", Packet.NumberU16),
	UpdateCombo = Packet("UpdateCombo", Packet.String, Packet.NumberU16),
	
	UpdateSliderValue = Packet("UpdateSliderValue", Packet.String, Packet.Boolean8),
	UpdateSettingValue = Packet("UpdateSettingValue", Packet.String, Packet.NumberU8)
}