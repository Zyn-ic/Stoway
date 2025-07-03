
-- src/server/StowayServer/stowayserver_modules/Actions.lua
local Actions = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

-- Dependencies
local PlayerStoways
local Settings
local Utils

function Actions.CreateHotbarValues(PlayerStowy)
	for i = 1, PlayerStowy.Settings.HotbarSettings.MaxSlots do
		local hotbarvalue = Instance.new("ObjectValue")
		hotbarvalue.Name = i
		hotbarvalue.Parent = PlayerStowy.HotBarFolder
	end
end

function Actions.Clear(PlayerStowy)
	for _, v in PlayerStowy.HotBarFolder:GetChildren() do
		v.Value = nil
	end
	for _, v in PlayerStowy.BackpackFolder:GetChildren() do
		v:Destroy()
	end
end

function Actions.ShiftBackpackValuesDown(StartingInventoryValue, Player)
	local PlayerStowy = PlayerStoways[Player]
	local currerntInventoryNum = tonumber(StartingInventoryValue.Name)
	if currerntInventoryNum then currerntInventoryNum += 1 end

	while PlayerStowy.BackpackFolder:FindFirstChild(currerntInventoryNum) do
		PlayerStowy.BackpackFolder[currerntInventoryNum - 1].Value = PlayerStowy.BackpackFolder[currerntInventoryNum].Value
		currerntInventoryNum += 1
	end
	PlayerStowy.BackpackFolder[currerntInventoryNum - 1]:Destroy()
end

function Actions.AddNewBackpackValue(Tool, Player)
	local PlayerStowy = PlayerStoways[Player]
	if not Utils.FindValueFromTool(Tool, Player) then
		local ToolWeight = Tool:GetAttribute("Weight")
		if not Utils.canAcceptWeight(PlayerStowy, ToolWeight) then
			Tool:Destroy()
			return
		end
		local PlayerTotalWeight = PlayerStowy.InventoryFolder:GetAttribute("TotalWeight")
		PlayerStowy.InventoryFolder:SetAttribute("TotalWeight", PlayerTotalWeight + ToolWeight)
	end

	local folder = PlayerStowy.HotBarFolder:GetChildren()
	for _, v in PlayerStowy.BackpackFolder:GetChildren() do
		table.insert(folder, v)
	end
	local newbackpackValue = Instance.new("ObjectValue")
	newbackpackValue.Name = #folder + 1
	newbackpackValue.Value = Tool
	newbackpackValue.Parent = PlayerStowy.BackpackFolder
end

function Actions.FindSuitableHotbarSlot(Tool, Player)
	local PlayerStowy = PlayerStoways[Player]
	if Tool and PlayerStowy.Settings.CanStack then
		local result = Utils.FindSameSlotType(PlayerStowy.HotBarFolder:GetChildren(), Tool)
		if result and result.Value then
			local ToolWeight = Tool:GetAttribute("Weight")
			local resultRarity = result.Value:GetAttribute("Rarity")
			local toolRarity = Tool:GetAttribute("Rarity")
			local canFit = ((ToolWeight + result.Value:GetAttribute("Weight")) <= PlayerStowy.Settings.MaxStackCount)
			if PlayerStowy.Settings.RarityCheck then
				if resultRarity == toolRarity and canFit then return result end
			elseif canFit then
				return result
			end
		end
	end
	return Utils.FindEmptySlot(PlayerStowy.HotBarFolder:GetChildren(), PlayerStowy.Settings.HotbarSettings.MaxSlots)
end

function Actions.UpdatePlayerTools(Player)
	local PlayerStowy = PlayerStoways[Player]
	local char = Player.Character
	local playerTools = Utils.getTools(Player.Backpack, char)
	local inventoryvalues = {}
	for _, v in PlayerStowy.BackpackFolder:GetChildren() do table.insert(inventoryvalues, v) end
	for _, v in PlayerStowy.HotBarFolder:GetChildren() do table.insert(inventoryvalues, v) end

	for _, value in inventoryvalues do
		local tool = value.Value
		if tool and not table.find(playerTools, tool) then
			local PlayerTotalWeight = PlayerStowy.InventoryFolder:GetAttribute("TotalWeight")
			PlayerStowy.InventoryFolder:SetAttribute("TotalWeight", PlayerTotalWeight - tool:GetAttribute("Weight"))
			value.Value = nil
			if value.Parent == PlayerStowy.BackpackFolder then Actions.ShiftBackpackValuesDown(value, Player) end
		end
	end

	for _, tool in playerTools do
		if not Utils.FindValueFromTool(tool, Player) then
			local ToolWeight = tool:GetAttribute("Weight")
			if not Utils.canAcceptWeight(PlayerStowy, ToolWeight) then
				tool:Destroy()
				continue
			end
			local freehotbarslot = Actions.FindSuitableHotbarSlot(tool, Player)
			if freehotbarslot then
				local PlayerTotalWeight = PlayerStowy.InventoryFolder:GetAttribute("TotalWeight")
				PlayerStowy.InventoryFolder:SetAttribute("TotalWeight", PlayerTotalWeight + ToolWeight)
				if freehotbarslot.Value ~= nil then
					local combindedweight = freehotbarslot.Value:GetAttribute("Weight") + ToolWeight
					freehotbarslot.Value:SetAttribute("Weight", combindedweight)
					tool:Destroy()
				else
					freehotbarslot.Value = tool
				end
			else
				Actions.AddNewBackpackValue(tool, Player)
			end
		end
	end
end

function Actions.SwapSlots(Player, Slot1, Slot2, stack)
	local PlayerStowy = PlayerStoways[Player]
	if not Utils.ValidateSlot(Slot1, PlayerStowy) or not Utils.ValidateSlot(Slot2, PlayerStowy) then return end
	if Slot1 == Slot2 then return end

	local performStackAction = false
	if stack and PlayerStowy.Settings.CanStack then
		local slotbeingswapped = Slot1.Value
		local targetslot = Slot2.Value
		if slotbeingswapped and targetslot then
			if slotbeingswapped:GetAttribute("ItemType") == targetslot:GetAttribute("ItemType") and slotbeingswapped.Name == targetslot.Name then
				local sourceWeight = slotbeingswapped:GetAttribute("Weight")
				local targetWeight = targetslot:GetAttribute("Weight")
				if sourceWeight < Settings.MaxStackCount and targetWeight < Settings.MaxStackCount then
					if PlayerStowy.Settings.RarityCheck then
						if slotbeingswapped:GetAttribute("Rarity") == targetslot:GetAttribute("Rarity") then
							performStackAction = true
						end
					else
						performStackAction = true
					end
				end
			end
		end
	end

	if performStackAction then
		local slotbeingswapped = Slot1.Value
		local targetslot = Slot2.Value
		local sourceWeight = slotbeingswapped:GetAttribute("Weight")
		local targetWeight = targetslot:GetAttribute("Weight")
		local spaceInTarget = Settings.MaxStackCount - targetWeight
		local amountToTransfer = math.min(sourceWeight, spaceInTarget)
		if amountToTransfer > 0 then
			targetslot:SetAttribute("Weight", targetWeight + amountToTransfer)
			slotbeingswapped:SetAttribute("Weight", sourceWeight - amountToTransfer)
			if slotbeingswapped:GetAttribute("Weight") <= 0 then
				slotbeingswapped:Destroy()
				Slot1.Value = nil
			end
		end
	else
		local oldslot1 = Slot1.Value
		Slot1.Value = Slot2.Value
		Slot2.Value = oldslot1
	end

	if Slot1.Parent == PlayerStowy.BackpackFolder and not Slot1.Value then
		Actions.ShiftBackpackValuesDown(Slot1, Player)
	elseif Slot2.Parent == PlayerStowy.BackpackFolder and not Slot2.Value then
		Actions.ShiftBackpackValuesDown(Slot2, Player)
	end
end

function Actions.MoveToEndofBackpack(Slot, Player)
	local PlayerStowy = PlayerStoways[Player]
	if not Utils.ValidateSlot(Slot, PlayerStowy) or not Slot.Value then return end
	local tool = Slot.Value
	Actions.AddNewBackpackValue(tool, Player)
	Slot.Value = nil
	if Slot.Parent == PlayerStowy.BackpackFolder then
		Actions.ShiftBackpackValuesDown(Slot, Player)
	end
end

function Actions:Init(context : Types.Context)
	PlayerStoways = context.PlayerStoways
	Settings = context.Settings
	Utils = context.Utils
end

return Actions