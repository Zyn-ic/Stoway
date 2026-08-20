--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Pure query/derivation logic for the client inventory mirror. Every
	function takes plain data in and returns plain data out — no Fusion
	StateObjects, no Instances, no game/Roblox services. Same philosophy as
	the server's CoreStore/Query.luau: testable in isolation, reused by the
	reactive Controller layer through Fusion:Computed wrappers.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require(script.Parent.Types)

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

-- O(hotbarSize + storageSize) linear scan — fine at client-side UUID counts.
-- The server keeps the real O(1) LocationByUUID index; the client doesn't
-- need one until interactions (drag/move) land in a later phase.
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

-- Visible left-packed position of a Dynamic hotbar slot (1-indexed, among
-- occupied slots only). Static hotbars are identity-mapped (holes allowed).
-- Empty Dynamic slots resolve past the end (1000 + slot) so they stay
-- LayoutOrder-sortable without ever colliding with a real packed position.
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

-- Buckets Storage by Metadata.Type. Storage's own array order is preserved
-- within each bucket — this is a presentation-only grouping, never a resort
-- of the underlying data. Collapsing a group hides its slot frames; it never
-- moves anything out of Storage or changes what the server thinks is there.
--
-- groupByCategory = false collapses everything into one bucket keyed by
-- Query.UNGROUPED_KEY, in Storage order — the "pure" flat backpack list.
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

-- Deterministic group display order: known categories sorted by
-- Settings.Categories[type].Order ascending, then any unknown/uncategorized
-- types alphabetically after all known ones.
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

-- Compact stack count. Below 1000 keeps the "x" ("5x", "999x"); from 1k up
-- the "x" is dropped and the number is abbreviated ("1.3k", "2.3m",
-- "200m", "200.3k") so the badge never shows a long digit list. One
-- decimal is shown only when the fractional part is non-zero; rounding
-- across a unit boundary (999.95k -> 1m) escalates to the next suffix.
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

-- Case-insensitive substring match against Id and Metadata.Description. An
-- empty search always matches (so "no search" shows everything).
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

-----------------------------
-- MAIN --
-----------------------------

return Query
