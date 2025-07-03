local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
-- src/server/StowayServer/stowayserver_modules/Utils.lua
local Utils = {}

-- Dependencies to be injected by the main script
local PlayerStoways

-- Helper Functions
function Utils.canAcceptWeight(PlayerStowy : Types.Stoway, weightToAdd: number)
	local PlayerLimit = PlayerStowy.Settings.BackpackSettings.Limit
	if PlayerLimit == 0 then return true end
	local PlayerTotalWeight = PlayerStowy.InventoryFolder:GetAttribute("TotalWeight")
	if (PlayerTotalWeight + weightToAdd) > PlayerLimit then return false end
	return true
end

function Utils.FindEmptySlot(folder, MaxSlots:number)
	for i = 1, MaxSlots do
		if not folder[i].Value then return folder[i] end
	end
	return nil
end

function Utils.FindSameSlotType(folder, Tool:Tool)
	for i = 1, #folder do
		local currentValue = folder[i]
		if currentValue and currentValue.Value then
			local itemValue = currentValue.Value
			if itemValue:GetAttribute("ItemType") == Tool:GetAttribute("ItemType") and itemValue.Name == Tool.Name then
				return currentValue
			end
		end
	end
	return nil
end

function Utils.ValidateTool(Player:Player, Tool:Tool)
	if typeof(Tool) ~= "Instance" or not Tool:IsA("Tool") then return false end
	if Tool.Parent ~= Player.Backpack and Tool.Parent ~= Player.Character then return false end
	return true
end

function Utils.ValidateSlot(Slot:ObjectValue, PlayerStowy:Types.Stoway)
	if typeof(Slot) ~= "Instance" or not Slot:IsA("ObjectValue") then return false end
	return Slot.Parent == PlayerStowy.HotBarFolder or Slot.Parent == PlayerStowy.BackpackFolder
end

function Utils.getTools(Backpack:Folder, character:Model)
	local tools = Backpack:GetChildren()
	if character then
		local charactertool = character:FindFirstChildWhichIsA("Tool")
		if charactertool then table.insert(tools, charactertool) end
	end
	return tools
end

function Utils.FindValueFromTool(Tool:Tool, Player:Player)
	local PlayerStowy = PlayerStoways[Player]
	if not PlayerStowy then return nil end
	for _, ObjectValue in PlayerStowy.HotBarFolder:GetChildren() do
		if ObjectValue.Value == Tool then return ObjectValue end
	end
	for _, ObjectValue in PlayerStowy.BackpackFolder:GetChildren() do
		if ObjectValue.Value == Tool then return ObjectValue end
	end
	return nil
end

function Utils:Init(context: Types.Context)
	PlayerStoways = context.PlayerStoways :: {Types.Stoway}
end

return Utils