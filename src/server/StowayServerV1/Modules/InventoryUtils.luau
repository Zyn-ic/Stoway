-- src/server/StowayServerV1/Modules/InventoryUtils.luau
local InventoryUtils = {}

local HttpService = game:GetService("HttpService")

--// Generates a unique identifier for an item instance
function InventoryUtils.GenerateUUID(): string
	return HttpService:GenerateGUID(false)
end

--// Checks if two items can stack based on ID and Metadata
function InventoryUtils.CanStack(item1: any, item2: any, settings: any?): boolean
	if item1.Id ~= item2.Id then return false end
	
	local meta1 = item1.Metadata or {}
	local meta2 = item2.Metadata or {}

	-- STRICT CHECK: Name, Rarity, Type used for stacking
	-- If these exist, they MUST match
	if meta1.Name ~= meta2.Name then return false end
	if meta1.Rarity ~= meta2.Rarity then return false end
	if meta1.Type ~= meta2.Type then return false end

	-- Rarity Blacklist Check
	if settings and settings.RarityBlacklist then
		local rarity = meta1.Rarity
		if rarity and settings.RarityBlacklist[rarity] then
			return false -- Cannot stack this rarity
		end
	end

	-- General Metadata Equality Check (Deep compare for other fields?)
	-- For now, we still iterate to ensure other custom properties match if desired
	for k, v in pairs(meta1) do
		if meta2[k] ~= v then return false end
	end
	for k, v in pairs(meta2) do
		if meta1[k] ~= v then return false end
	end

	return true
end

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
