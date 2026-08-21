--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Pure queries over the client inventory mirror. No Fusion or Instances.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require(script.Parent.Types)
local Colors = require(game:GetService("ReplicatedStorage").Shared.Stoway.Colors)

local Query = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Query.getItem(items: { [string]: Types.Item }, uuid: string?): Types.Item?
	if not uuid then
		return nil
	end
	return items[uuid]
end

function Query.getHotbarUUID(hotbar: { [number]: string? }, slot: number): string?
	return hotbar[slot]
end

function Query.getStorageUUID(storage: { string }, index: number): string?
	return storage[index]
end

function Query.isEquipped(equippedUUID: string?, uuid: string?): boolean
	return equippedUUID ~= nil and uuid ~= nil and equippedUUID == uuid
end

-- Linear scan over hotbar and storage.
function Query.findSlotByUUID(
	hotbar: { [number]: string? },
	storage: { string },
	uuid: string
): (Types.SlotType?, number?)
	for slot, hotbarUUID in hotbar do
		if hotbarUUID == uuid then
			return "Hotbar", slot
		end
	end
	for index, storageUUID in storage do
		if storageUUID == uuid then
			return "Storage", index
		end
	end
	return nil, nil
end

function Query.isDynamicHotbar(settings: Types.Settings?): boolean
	return settings ~= nil and settings.HotbarType == "Dynamic"
end

-- Packed position for Dynamic hotbars; holes map past the end.
function Query.packedHotbarOrder(
	hotbar: { [number]: string? },
	items: { [string]: Types.Item },
	slot: number,
	isDynamic: boolean
): number
	if not isDynamic then
		return slot
	end
	local visible = 0
	for i = 1, slot do
		local uuid = hotbar[i]
		if uuid and items[uuid] then
			visible += 1
		end
	end
	if visible == 0 then
		return 1000 + slot
	end
	return visible
end

function Query.isHotbarSlotVisible(
	hotbar: { [number]: string? },
	items: { [string]: Types.Item },
	slot: number,
	isDynamic: boolean
): boolean
	if not isDynamic then
		return true
	end
	local uuid = hotbar[slot]
	return uuid ~= nil and items[uuid] ~= nil
end

-- Groups Storage by item type for display; original order preserved.
Query.UNGROUPED_KEY = ""

function Query.groupStorageByType(
	storage: { string },
	items: { [string]: Types.Item },
	groupByCategory: boolean
): Types.GroupedStorage
	if not groupByCategory then
		local flat: { Types.ItemRecord } = {}
		for index, uuid in storage do
			table.insert(flat, { index = index, uuid = uuid })
		end
		return { [Query.UNGROUPED_KEY] = flat }
	end

	local groups: Types.GroupedStorage = {}
	for index, uuid in storage do
		local item = items[uuid]
		local itemType = if item and item.Metadata and item.Metadata.Type then item.Metadata.Type else "Other"
		local group = groups[itemType]
		if not group then
			group = {}
			groups[itemType] = group
		end
		table.insert(group, { index = index, uuid = uuid })
	end
	return groups
end

-- Group order by category Order, then alphabetically.
function Query.orderedGroupKeys(
	groups: Types.GroupedStorage,
	categories: { [string]: Types.CategoryDef }?
): { string }
	local keys: { string } = {}
	for itemType in groups do
		table.insert(keys, itemType)
	end
	table.sort(keys, function(a, b)
		local ca = categories and categories[a]
		local cb = categories and categories[b]
		local oa = if ca then ca.Order else math.huge
		local ob = if cb then cb.Order else math.huge
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	return keys
end

function Query.formatWeight(weight: number, limit: number): string
	if limit <= 0 then
		return tostring(weight)
	end
	return `{weight}/{limit}`
end

-- Abbreviated stack count (e.g. 1.3k, 2m).
function Query.formatAmount(amount: number): string
	if amount < 1000 then
		return tostring(amount) .. "x"
	end
	local units = {
		{ threshold = 1e9, suffix = "b" },
		{ threshold = 1e6, suffix = "m" },
		{ threshold = 1e3, suffix = "k" },
	}
	for _, unit in units do
		if amount >= unit.threshold then
			local scaled = math.floor(amount / unit.threshold * 10 + 0.5) / 10
			if scaled >= 1000 then
				if unit.suffix == "k" then
					return "1m"
				elseif unit.suffix == "m" then
					return "1b"
				end
				return string.format("%.0f", scaled) .. unit.suffix
			end
			if scaled == math.floor(scaled) then
				return string.format("%.0f", scaled) .. unit.suffix
			end
			return string.format("%.1f", scaled) .. unit.suffix
		end
	end
	return tostring(amount)
end

-- Case-insensitive match on Id and Description.
function Query.matchesSearch(item: Types.Item?, searchText: string): boolean
	if searchText == "" then
		return true
	end
	if not item then
		return false
	end
	local needle = string.lower(searchText)
	if string.find(string.lower(item.Id), needle, 1, true) then
		return true
	end
	local description = item.Metadata and item.Metadata.Description
	if description and string.find(string.lower(description), needle, 1, true) then
		return true
	end
	return false
end

function Query.filterRecordsBySearch(
	records: { Types.ItemRecord },
	items: { [string]: Types.Item },
	searchText: string
): { Types.ItemRecord }
	if searchText == "" then
		return records
	end
	local filtered: { Types.ItemRecord } = {}
	for _, record in records do
		if Query.matchesSearch(items[record.uuid], searchText) then
			table.insert(filtered, record)
		end
	end
	return filtered
end

-- Sorts records by SortOrder; stable by original index.
function Query.sortRecords(
	records: { Types.ItemRecord },
	items: { [string]: Types.Item },
	sortOrder: Types.SortOrder
): { Types.ItemRecord }
	if sortOrder == "None" then
		return records
	end
	local sorted = table.clone(records)
	table.sort(sorted, function(a, b)
		local itemA = items[a.uuid]
		local itemB = items[b.uuid]
		if sortOrder == "Name" then
			local nameA = if itemA then itemA.Id else ""
			local nameB = if itemB then itemB.Id else ""
			if nameA ~= nameB then
				return nameA < nameB
			end
		elseif sortOrder == "Rarity" then
			local rankA = Colors.getRarityRank(itemA and itemA.Metadata and itemA.Metadata.Rarity)
			local rankB = Colors.getRarityRank(itemB and itemB.Metadata and itemB.Metadata.Rarity)
			if rankA ~= rankB then
				return rankA > rankB -- highest rarity first
			end
		elseif sortOrder == "ItemType" then
			local typeA = if itemA and itemA.Metadata and itemA.Metadata.Type then itemA.Metadata.Type else "Other"
			local typeB = if itemB and itemB.Metadata and itemB.Metadata.Type then itemB.Metadata.Type else "Other"
			if typeA ~= typeB then
				return typeA < typeB
			end
		end
		return a.index < b.index
	end)
	return sorted
end

-----------------------------
-- MAIN --
-----------------------------

return Query
