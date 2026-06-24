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
			if readIndex ~= writeIndex then
				changed = true
			end

			packedHotbar[writeIndex] = uuid
			state.LocationByUUID[uuid] = {
				Type = "Hotbar",
				Slot = writeIndex,
			}

			writeIndex += 1
		end
	end

	if changed then
		state.Hotbar = packedHotbar
	end

	return changed
end

-----------------------------
--MAIN--
-----------------------------

return Slots
