local Types = require(script.Parent.Types)

type InventoryState = Types.InventoryState
type SlotRef = Types.SlotRef
type SlotType = Types.SlotType

local Slots = {}

function Slots.setHotbarSlot(state: InventoryState, slot: number, uuid: string)
    state.Hotbar[slot] = uuid
    state.LocationByUUID[uuid] = {
        Type = "Hotbar",
        Slot = slot,
    }
end

function Slots.clearHotbarSlot(state: InventoryState, slot: number)
    local uuid = state.Hotbar[slot]

    if uuid then
        state.LocationByUUID[uuid] = nil
    end

    state.Hotbar[slot] = nil
end

function Slots.findEmptyHotbarSlot(state: InventoryState): number?
    for slot = 1, state.Settings.MaxHotbarSlots do
        if not state.Hotbar[slot] then
            return slot
        end
    end

    return nil
end

function Slots.appendStorage(state: InventoryState, uuid: string): number
    table.insert(state.Storage, uuid)

    local slot = #state.Storage

    state.LocationByUUID[uuid] = {
        Type = "Storage",
        Slot = slot,
    }

    return slot
end

function Slots.removeStorageAt(state: InventoryState, index: number)
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

function Slots.getUUIDFromSlot(state: InventoryState, slotType: SlotType, slot: number): string?
    if slotType == "Hotbar" then
        return state.Hotbar[slot]
    end

    return state.Storage[slot]
end

function Slots.getLocation(state: InventoryState, uuid: string): SlotRef?
    return state.LocationByUUID[uuid]
end

function Slots.findSlotByUUID(state: InventoryState, uuid: string): (SlotType?, number?)
    local location = state.LocationByUUID[uuid]

    if not location then
        return nil, nil
    end

    return location.Type, location.Slot
end

function Slots.isValidHotbarSlot(state: InventoryState, slot: number): boolean
    return slot >= 1 and slot <= state.Settings.MaxHotbarSlots
end

function Slots.isValidStorageSlot(state: InventoryState, slot: number): boolean
    return slot >= 1 and slot <= #state.Storage
end

function Slots.compactHotbar(state: InventoryState): boolean
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

return Slots