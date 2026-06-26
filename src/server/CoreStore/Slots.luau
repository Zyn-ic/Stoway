--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Slot management - hotbar and storage slot operations
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("../CoreStore/Types")

local Slots = {}

-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

-- PUBLIC FUNCTIONS --
-----------------------------

function Slots.setHotbarSlot(state: Types.InventoryState, slot: number, uuid: string)
	state.Hotbar[slot] = uuid
	state.LocationByUUID[uuid] = {
		Type = "Hotbar",
		Slot = slot,
	}
end

function Slots.clearHotbarSlot(state: Types.InventoryState, slot: number)
	local uuid = state.Hotbar[slot]

	if uuid then
		state.LocationByUUID[uuid] = nil
	end

	state.Hotbar[slot] = nil
end

function Slots.findEmptyHotbarSlot(state: Types.InventoryState): number?
	for slot = 1, state.Settings.MaxHotbarSlots do
		if not state.Hotbar[slot] then
			return slot
		end
	end

	return nil
end

function Slots.appendStorage(state: Types.InventoryState, uuid: string): number
	table.insert(state.Storage, uuid)

	local slot = #state.Storage

	state.LocationByUUID[uuid] = {
		Type = "Storage",
		Slot = slot,
	}

	return slot
end

function Slots.removeStorageAt(state: Types.InventoryState, index: number)
	local uuid = state.Storage[index]

	if uuid then
		state.LocationByUUID[uuid] = nil
	end

	table.remove(state.Storage, index)

	for shiftedIndex = index, #state.Storage do
		local shiftedUUID = state.Storage[shiftedIndex]

		state.LocationByUUID[shiftedUUID] = {
			Type = "Storage",
			Slot = shiftedIndex,
		}
	end
end

function Slots.getUUIDFromSlot(state: Types.InventoryState, slotType: Types.SlotType, slot: number): string?
	if slotType == "Hotbar" then
		return state.Hotbar[slot]
	end

	return state.Storage[slot]
end

function Slots.getLocation(state: Types.InventoryState, uuid: string): Types.SlotRef?
	return state.LocationByUUID[uuid]
end

function Slots.findSlotByUUID(state: Types.InventoryState, uuid: string): (Types.SlotType?, number?)
	local location = state.LocationByUUID[uuid]

	if not location then
		return nil, nil
	end

	return location.Type, location.Slot
end

function Slots.isValidHotbarSlot(state: Types.InventoryState, slot: number): boolean
	return slot >= 1 and slot <= state.Settings.MaxHotbarSlots
end

function Slots.isValidStorageSlot(state: Types.InventoryState, slot: number): boolean
	return slot >= 1 and slot <= #state.Storage
end

function Slots.getHotbarItemCount(state: Types.InventoryState): number
	local count = 0

	for slot = 1, state.Settings.MaxHotbarSlots do
		if state.Hotbar[slot] then
			count += 1
		end
	end

	return count
end

function Slots.getStorageItemCount(state: Types.InventoryState): number
	return #state.Storage
end

function Slots.compactHotbar(state: Types.InventoryState): boolean
	if state.Settings.HotbarType ~= "Dynamic" then
		return false
	end

	local packedHotbar: { string? } = {}
	local writeIndex = 1
	local changed = false

	for readIndex = 1, state.Settings.MaxHotbarSlots do
		local uuid = state.Hotbar[readIndex]

		if uuid then
			packedHotbar[writeIndex] = uuid

			if readIndex ~= writeIndex then
				changed = true
				state.LocationByUUID[uuid] = {
					Type = "Hotbar",
					Slot = writeIndex,
				}
			end

			writeIndex += 1
		end
	end

	if changed then
		state.Hotbar = packedHotbar
	end

	return changed
end

function Slots.swapSlots(state: Types.InventoryState, fromRef: Types.SlotRef, toRef: Types.SlotRef): boolean
	local fromUUID = Slots.getUUIDFromSlot(state, fromRef.Type, fromRef.Slot)
	local toUUID = Slots.getUUIDFromSlot(state, toRef.Type, toRef.Slot)

	if fromRef.Type == "Hotbar" and toRef.Type == "Hotbar" then
		state.Hotbar[fromRef.Slot] = toUUID
		state.Hotbar[toRef.Slot] = fromUUID

		if toUUID then
			state.LocationByUUID[toUUID] = { Type = "Hotbar", Slot = fromRef.Slot }
		end
		if fromUUID then
			state.LocationByUUID[fromUUID] = { Type = "Hotbar", Slot = toRef.Slot }
		end

		return false
	end

	if fromRef.Type == "Storage" and toRef.Type == "Storage" then
		state.Storage[fromRef.Slot] = toUUID
		state.Storage[toRef.Slot] = fromUUID

		if toUUID then
			state.LocationByUUID[toUUID] = { Type = "Storage", Slot = fromRef.Slot }
		end
		if fromUUID then
			state.LocationByUUID[fromUUID] = { Type = "Storage", Slot = toRef.Slot }
		end

		return false
	end

	if fromRef.Type == "Hotbar" and toRef.Type == "Storage" then
		state.Hotbar[fromRef.Slot] = toUUID
		state.Storage[toRef.Slot] = fromUUID

		if toUUID then
			state.LocationByUUID[toUUID] = { Type = "Hotbar", Slot = fromRef.Slot }
		end
		if fromUUID then
			state.LocationByUUID[fromUUID] = { Type = "Storage", Slot = toRef.Slot }
		end

		return false
	end

	if fromRef.Type == "Storage" and toRef.Type == "Hotbar" then
		state.Storage[fromRef.Slot] = toUUID
		state.Hotbar[toRef.Slot] = fromUUID

		if toUUID then
			state.LocationByUUID[toUUID] = { Type = "Storage", Slot = fromRef.Slot }
		end
		if fromUUID then
			state.LocationByUUID[fromUUID] = { Type = "Hotbar", Slot = toRef.Slot }
		end

		return false
	end

	return false
end

function Slots.moveWithinStorage(state: Types.InventoryState, fromIndex: number, toIndex: number)
	local uuid = state.Storage[fromIndex]

	table.remove(state.Storage, fromIndex)
	table.insert(state.Storage, toIndex, uuid)

	local start = math.min(fromIndex, toIndex)
	local finish = math.max(fromIndex, toIndex)

	for i = start, finish do
		local movedUUID = state.Storage[i]
		state.LocationByUUID[movedUUID] = {
			Type = "Storage",
			Slot = i,
		}
	end
end

function Slots.moveToStorage(state: Types.InventoryState, uuid: string, toIndex: number)
	table.insert(state.Storage, toIndex, uuid)
	state.LocationByUUID[uuid] = {
		Type = "Storage",
		Slot = toIndex,
	}

	for i = toIndex + 1, #state.Storage do
		local shiftedUUID = state.Storage[i]
		state.LocationByUUID[shiftedUUID] = {
			Type = "Storage",
			Slot = i,
		}
	end
end

local RARITY_RANK: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Special = 7,
}

function Slots.sortStorage(state: Types.InventoryState, sortOrder: Types.SortOrder): boolean
	if sortOrder == "None" or #state.Storage <= 1 then
		return false
	end

	local items: { { uuid: string, key: string, rarityRank: number } } = {}

	for _, uuid in ipairs(state.Storage) do
		local item = state.Items[uuid]
		if item then
			table.insert(items, {
				uuid = uuid,
				key = if sortOrder == "Name" then item.Id
					elseif sortOrder == "Rarity" then item.Metadata.Rarity or ""
					else item.Metadata.Type or "",
				rarityRank = if sortOrder == "Rarity" then (RARITY_RANK[item.Metadata.Rarity or ""] or 99)
					else 0,
			})
		end
	end

	if sortOrder == "Rarity" then
		table.sort(items, function(a, b)
			if a.rarityRank ~= b.rarityRank then
				return a.rarityRank > b.rarityRank
			end
			return a.key < b.key
		end)
	else
		table.sort(items, function(a, b)
			return a.key < b.key
		end)
	end

	local newOrder: { string } = {}
	local changed = false

	for i, entry in ipairs(items) do
		newOrder[i] = entry.uuid
		if state.Storage[i] ~= entry.uuid then
			changed = true
		end
	end

	if changed then
		state.Storage = newOrder

		for i, uuid in ipairs(state.Storage) do
			state.LocationByUUID[uuid] = {
				Type = "Storage",
				Slot = i,
			}
		end
	end

	return changed
end

function Slots.sortHotbar(state: Types.InventoryState, sortOrder: Types.SortOrder): boolean
	if sortOrder == "None" or state.Settings.HotbarType ~= "Dynamic" then
		return false
	end

	local items: { { uuid: string, key: string, rarityRank: number } } = {}

	for slot = 1, state.Settings.MaxHotbarSlots do
		local uuid = state.Hotbar[slot]
		if uuid then
			local item = state.Items[uuid]
			if item then
				table.insert(items, {
					uuid = uuid,
					key = if sortOrder == "Name" then item.Id
						elseif sortOrder == "Rarity" then item.Metadata.Rarity or ""
						else item.Metadata.Type or "",
					rarityRank = if sortOrder == "Rarity" then (RARITY_RANK[item.Metadata.Rarity or ""] or 99)
						else 0,
				})
			end
		end
	end

	if #items <= 1 then
		return false
	end

	if sortOrder == "Rarity" then
		table.sort(items, function(a, b)
			if a.rarityRank ~= b.rarityRank then
				return a.rarityRank > b.rarityRank
			end
			return a.key < b.key
		end)
	else
		table.sort(items, function(a, b)
			return a.key < b.key
		end)
	end

	local newHotbar: { string? } = {}
	local changed = false

	for i, entry in ipairs(items) do
		newHotbar[i] = entry.uuid
		if state.Hotbar[i] ~= entry.uuid then
			changed = true
		end
	end

	for i = #items + 1, state.Settings.MaxHotbarSlots do
		if state.Hotbar[i] then
			changed = true
		end
		newHotbar[i] = nil
	end

	if changed then
		state.Hotbar = newHotbar

		for i, uuid in ipairs(items) do
			state.LocationByUUID[uuid] = {
				Type = "Hotbar",
				Slot = i,
			}
		end
	end

	return changed
end

-----------------------------
--MAIN--
-----------------------------

return Slots
