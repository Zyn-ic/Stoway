-- src/server/StowayServerV1.2/Utils/StackChecker.luau
-- Validates if items can stack and attempts stacking
-- Uses state.Settings for CanStack and MaxStackSize (per-player)
-- Uses global Settings.Stacking for item-level rules (RequiredFields, Blacklist)

local StackChecker = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage.Shared.Settings) -- For Stacking rules
local LimitChecker = require(script.Parent.Parent.Core.LimitChecker)

--// Check if two items can stack based on ID and metadata
function StackChecker.CanStack(item1: any, item2: any): boolean
	-- Must have same ID
	if item1.Id ~= item2.Id then 
		return false 
	end
	
	local meta1 = item1.Metadata or {}
	local meta2 = item2.Metadata or {}
	
	-- Check required fields match (global rule)
	for _, field in ipairs(Settings.Stacking.RequiredFields) do
		if meta1[field] ~= meta2[field] then
			return false
		end
	end
	
	-- Check blacklist (certain rarities cannot stack) (global rule)
	local rarity = meta1.Rarity
	if rarity and Settings.Stacking.Blacklist[rarity] then
		return false
	end
	
	-- Deep equality check on remaining metadata
	for k, v in pairs(meta1) do
		if meta2[k] ~= v then 
			return false 
		end
	end
	for k, v in pairs(meta2) do
		if meta1[k] ~= v then 
			return false 
		end
	end
	
	return true
end

--// Attempt to stack amount into existing items, returns amount stacked and updated items
function StackChecker.TryStack(state: any, itemId: string, amount: number, metadata: any?): (number, {[string]: number})
	-- Check per-player CanStack setting
	if not state.Settings.CanStack then
		return 0, {}
	end
	
	local totalStacked = 0
	local updatedItems = {}
	local existingUUIDs = state.ItemsByID[itemId]
	
	if not existingUUIDs then
		return 0, {}
	end
	
	local newItemProxy = { Id = itemId, Metadata = metadata or {} }
	local maxStackSize = state.Settings.MaxStackSize
	
	for _, uuid in ipairs(existingUUIDs) do
		if amount <= 0 then break end
		
		local existingItem = state.Items[uuid]
		if existingItem and StackChecker.CanStack(newItemProxy, existingItem) then
			local space = maxStackSize - existingItem.Amount
			if space > 0 then
				local toAdd = math.min(amount, space)
				existingItem.Amount += toAdd
				amount -= toAdd
				totalStacked += toAdd
				updatedItems[uuid] = existingItem.Amount
				
				-- Update weight for stacked amount
				LimitChecker.AddWeight(state, toAdd)
			end
		end
	end
	
	return totalStacked, updatedItems
end

return StackChecker


