-- src/server/StowayServerV1/Modules/InventoryUtils.luau
local InventoryUtils = {}

local HttpService = game:GetService("HttpService")

--// Generates a unique identifier for an item instance
function InventoryUtils.GenerateUUID(): string
	return HttpService:GenerateGUID(false)
end

--// Checks if two items can stack based on ID and Metadata
function InventoryUtils.CanStack(item1: any, item2: any, checkRarity: boolean): boolean
	if item1.Id ~= item2.Id then return false end
	
	-- Check metadata equality (simplified)
	-- In a real scenario, you might want deep comparison or specific field checks
	if item1.Metadata and item2.Metadata then
		-- For now, assume if metadata exists, they might not stack unless identical
		-- This is a placeholder for deep comparison
		for k, v in pairs(item1.Metadata) do
			if item2.Metadata[k] ~= v then return false end
		end
		for k, v in pairs(item2.Metadata) do
			if item1.Metadata[k] ~= v then return false end
		end
	elseif item1.Metadata ~= item2.Metadata then
		return false
	end

	-- Rarity check if enabled
	if checkRarity then
		local r1 = item1.Metadata and item1.Metadata.Rarity
		local r2 = item2.Metadata and item2.Metadata.Rarity
		if r1 ~= r2 then return false end
	end

	return true
end

--// Finds the first empty slot in a dictionary of slots
function InventoryUtils.FindEmptySlot(slots: { [number]: any }, maxSlots: number): number?
	for i = 1, maxSlots do
		if not slots[i] then
			return i
		end
	end
	return nil
end

--// Parses metadata from a Tool's attributes
function InventoryUtils.ParseToolMetadata(tool: Tool): any
	if not tool or not tool:IsA("Tool") then
		return nil
	end
	
	local attributes = tool:GetAttributes()
	
	-- Return nil if no attributes found, otherwise return a copy of the attributes table
	return next(attributes) and table.clone(attributes) or nil
end

return InventoryUtils
