--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Slot management - hotbar and storage slot operations
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("./Types")

local Slots = {}

-----------------------------
-- CONSTANTS --
-----------------------------

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- PUBLIC FUNCTIONS --
-----------------------------

-- Sets a hotbar slot and updates LocationByUUID.
-- Example: setHotbarSlot(state, 3, "uuid-abc")
--   state.Hotbar[3] = "uuid-abc"
--   state.LocationByUUID["uuid-abc"] = { Type = "Hotbar", Slot = 3 }
function Slots.setHotbarSlot(state: Types.InventoryState, slot: number, uuid: string)
	state.Hotbar[slot] = uuid
	state.LocationByUUID[uuid] = {
		Type = "Hotbar",
		Slot = slot,
	}
end

-- Clears a hotbar slot and removes its LocationByUUID entry.
-- Does nothing if the slot is already nil.
function Slots.clearHotbarSlot(state: Types.InventoryState, slot: number)
	local uuid = state.Hotbar[slot]

	if uuid then
		state.LocationByUUID[uuid] = nil
	end

	state.Hotbar[slot] = nil
end

-- Scans hotbar left-to-right for the first nil slot.
-- In Static mode, this fills holes. In Dynamic mode, this is the append position.
function Slots.findEmptyHotbarSlot(state: Types.InventoryState): number?
	for slot = 1, state.Settings.MaxHotbarSlots do
		if not state.Hotbar[slot] then
			return slot
		end
	end

	return nil
end

-- Appends a UUID to the end of Storage.
-- Returns the new slot index (1-based).
-- Example: appendStorage(state, "uuid-abc")
--   state.Storage = [..., "uuid-abc"]
--   state.LocationByUUID["uuid-abc"] = { Type = "Storage", Slot = #Storage }
function Slots.appendStorage(state: Types.InventoryState, uuid: string): number
	table.insert(state.Storage, uuid)

	local slot = #state.Storage

	state.LocationByUUID[uuid] = {
		Type = "Storage",
		Slot = slot,
	}

	return slot
end

-- Removes an item from Storage at a given index and shifts all items after it left.
-- Updates LocationByUUID for every shifted item.
-- Example: removeStorageAt(state, 2) with Storage = ["A", "B", "C"]
--   Removes "B", shifts "C" to index 2
--   state.Storage = ["A", "C"]
--   state.LocationByUUID["C"] = { Type = "Storage", Slot = 2 }
function Slots.removeStorageAt(state: Types.InventoryState, index: number)
	local uuid = state.Storage[index]

	if uuid then
		state.LocationByUUID[uuid] = nil
	end

	table.remove(state.Storage, index)

	-- Update LocationByUUID for all items that shifted left
	for shiftedIndex = index, #state.Storage do
		local shiftedUUID = state.Storage[shiftedIndex]

		state.LocationByUUID[shiftedUUID] = {
			Type = "Storage",
			Slot = shiftedIndex,
		}
	end
end

-- Returns the UUID at a given slot reference (Hotbar or Storage).
-- Note: Storage is 1-indexed in the API, so we access state.Storage[slot] directly.
function Slots.getUUIDFromSlot(state: Types.InventoryState, slotType: Types.SlotType, slot: number): string?
	if slotType == "Hotbar" then
		return state.Hotbar[slot]
	end

	return state.Storage[slot]
end

-- Returns the SlotRef for a UUID, or nil if not placed.
function Slots.getLocation(state: Types.InventoryState, uuid: string): Types.SlotRef?
	return state.LocationByUUID[uuid]
end

-- Returns (SlotType, Slot number) for a UUID, or (nil, nil) if not found.
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

-- Compacts the hotbar by packing all non-nil slots left.
-- Only runs in Dynamic mode. No-op in Static mode.
--
-- Uses a read/write pointer algorithm:
--   readIndex scans all slots 1..MaxHotbarSlots
--   writeIndex tracks where the next item goes
--   If readIndex != writeIndex, the item moved and LocationByUUID updates
--
-- Example: Hotbar = { "A", nil, "B", nil, "C" }
--   readIndex=1: writeIndex=1, no move, writeIndex -> 2
--   readIndex=2: nil, skip
--   readIndex=3: writeIndex=2, "B" moves from slot 3 to 2, writeIndex -> 3
--   readIndex=4: nil, skip
--   readIndex=5: writeIndex=3, "C" moves from slot 5 to 3, writeIndex -> 4
--   Result: Hotbar = { "A", "B", "C", nil, nil }
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

-- Swaps two slots by exchanging their UUIDs and updating LocationByUUID.
-- Handles all 4 container combos: HH, SS, HS, SH.
-- Returns false always (compaction is handled by the caller in Operations).
function Slots.swapSlots(state: Types.InventoryState, fromRef: Types.SlotRef, toRef: Types.SlotRef): boolean
	local fromUUID = Slots.getUUIDFromSlot(state, fromRef.Type, fromRef.Slot)
	local toUUID = Slots.getUUIDFromSlot(state, toRef.Type, toRef.Slot)

	-- Hotbar <-> Hotbar: swap UUIDs in the Hotbar table
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

	-- Storage <-> Storage: swap UUIDs in the Storage array
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

	-- Hotbar -> Storage: hotbar slot gets dest UUID, storage slot gets source UUID
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

	-- Storage -> Hotbar: storage slot gets dest UUID, hotbar slot gets source UUID
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

-- Reorders within Storage by removing from one index and inserting at another.
-- Updates LocationByUUID for all items in the affected range.
-- Example: moveWithinStorage(state, 1, 3) with Storage = ["A", "B", "C", "D"]
--   Removes "A" from index 1, inserts at index 3
--   state.Storage = ["B", "C", "A", "D"]
--   All items in range 1..3 get updated LocationByUUID
function Slots.moveWithinStorage(state: Types.InventoryState, fromIndex: number, toIndex: number)
	local uuid = state.Storage[fromIndex]

	table.remove(state.Storage, fromIndex)
	-- After removal the array is one shorter; clamp to the valid insert range
	-- (1..#Storage+1). Luau's table.insert does NOT clamp the position, so an
	-- unclamped append on a shortened array would leave a hole at index 1.
	local insertAt = math.min(toIndex, #state.Storage + 1)
	table.insert(state.Storage, insertAt, uuid)

	-- Update LocationByUUID for all items that shifted during the move
	local start = math.min(fromIndex, insertAt)
	local finish = math.min(math.max(fromIndex, insertAt), #state.Storage)

	for i = start, finish do
		local movedUUID = state.Storage[i]
		state.LocationByUUID[movedUUID] = {
			Type = "Storage",
			Slot = i,
		}
	end
end

-- Inserts a UUID into Storage at a given index, shifting subsequent items right.
-- Used when moving an item from hotbar to a specific storage position.
-- Example: moveToStorage(state, "uuid-abc", 2) with Storage = ["A", "C"]
--   state.Storage = ["A", "uuid-abc", "C"]
--   All items from index 2 onward get updated LocationByUUID
function Slots.moveToStorage(state: Types.InventoryState, uuid: string, toIndex: number)
	table.insert(state.Storage, toIndex, uuid)
	state.LocationByUUID[uuid] = {
		Type = "Storage",
		Slot = toIndex,
	}

	-- Update LocationByUUID for items that shifted right
	for i = toIndex + 1, #state.Storage do
		local shiftedUUID = state.Storage[i]
		state.LocationByUUID[shiftedUUID] = {
			Type = "Storage",
			Slot = i,
		}
	end
end

-- Rarity rank table for sort ordering. Higher number = higher rarity.
-- Sort is descending: Special (7) first, Common (1) last.
local RARITY_RANK: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Special = 7,
}

-- Sorts Storage by the given SortOrder.
-- Algorithm: extract key tuples -> sort -> rebuild Storage array.
-- Rarity sorts descending (highest first). Name and ItemType sort ascending.
-- Only sorts if Storage has 2+ items. Returns true if order changed.
function Slots.sortStorage(state: Types.InventoryState, sortOrder: Types.SortOrder): boolean
	if sortOrder == "None" or #state.Storage <= 1 then
		return false
	end

	-- Extract sort keys for each item
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

	-- Sort: rarity descending, everything else ascending
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

	-- Rebuild Storage array and check if anything changed
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

		-- Update LocationByUUID for all items at their new positions
		for i, uuid in ipairs(state.Storage) do
			state.LocationByUUID[uuid] = {
				Type = "Storage",
				Slot = i,
			}
		end
	end

	return changed
end

-- Sorts Hotbar by the given SortOrder. Only works in Dynamic mode.
-- No-op in Static mode (hotbar order is user-controlled).
-- Uses the same algorithm as sortStorage but rebuilds the Hotbar table.
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

	-- Rebuild hotbar. Packed items go first, rest becomes nil.
	local newHotbar: { string? } = {}
	local changed = false

	for i, entry in ipairs(items) do
		newHotbar[i] = entry.uuid
		if state.Hotbar[i] ~= entry.uuid then
			changed = true
		end
	end

	-- Clear remaining slots (they were occupied before but items got packed)
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
