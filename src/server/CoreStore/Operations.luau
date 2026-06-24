local Types = require(script.Parent.Types)
local Metadata = require(script.Parent.Metadata)
local Slots = require(script.Parent.Slots)
local Stack = require(script.Parent.Stack)
local State = require(script.Parent.State)
local Utils = require(script.Parent.Utils)

type InventoryState = Types.InventoryState
type Item = Types.Item
type ItemInput = Types.ItemInput
type ItemMetadata = Types.ItemMetadata
type AddOptions = Types.AddOptions
type AddResult = Types.AddResult
type RemoveResult = Types.RemoveResult
type SlotType = Types.SlotType

local Operations = {}

local function addToIndex(state: InventoryState, itemId: string, uuid: string)
    if not state.ItemsByID[itemId] then
        state.ItemsByID[itemId] = {}
    end

    table.insert(state.ItemsByID[itemId], uuid)
end

local function removeFromIndex(state: InventoryState, itemId: string, uuid: string)
    local uuids = state.ItemsByID[itemId]

    if not uuids then
        return
    end

    for index, indexedUUID in ipairs(uuids) do
        if indexedUUID == uuid then
            table.remove(uuids, index)
            break
        end
    end

    if #uuids == 0 then
        state.ItemsByID[itemId] = nil
    end
end

local function createItem(
    state: InventoryState,
    itemId: string,
    amount: number,
    metadata: ItemMetadata
): Item
    local uuid = Utils.generateUUID()
    local finalAmount = math.min(amount, state.Settings.MaxStackSize)

    local item: Item = {
        UUID = uuid,
        Id = itemId,
        Amount = finalAmount,
        Metadata = Utils.deepCopy(metadata) :: ItemMetadata,
    }

    state.Items[uuid] = item
    addToIndex(state, itemId, uuid)
    State.addWeight(state, finalAmount)

    return item
end

local function destroyUnplacedItem(state: InventoryState, item: Item)
    state.Items[item.UUID] = nil
    state.LocationByUUID[item.UUID] = nil

    removeFromIndex(state, item.Id, item.UUID)
    State.removeWeight(state, item.Amount)
end

local function placeItemInHotbar(
    state: InventoryState,
    item: Item,
    preferredSlot: number?
): (number?, string?)
    if preferredSlot then
        if not Slots.isValidHotbarSlot(state, preferredSlot) then
            return nil, "INVALID_HOTBAR_SLOT"
        end

        if state.Hotbar[preferredSlot] then
            return nil, "HOTBAR_SLOT_OCCUPIED"
        end

        Slots.setHotbarSlot(state, preferredSlot, item.UUID)
        return preferredSlot, nil
    end

    local slot = Slots.findEmptyHotbarSlot(state)

    if not slot then
        return nil, "HOTBAR_FULL"
    end

    Slots.setHotbarSlot(state, slot, item.UUID)
    return slot, nil
end

local function placeItemInStorage(state: InventoryState, item: Item): (number?, string?)
    if not state.Settings.BackpackEnabled then
        return nil, "BACKPACK_DISABLED"
    end

    local slot = Slots.appendStorage(state, item.UUID)
    return slot, nil
end

local function addNewStacks(
    state: InventoryState,
    itemId: string,
    amount: number,
    metadata: ItemMetadata,
    options: AddOptions
): ({ Types.AddedSlot }, number, string?)
    local addedItems: { Types.AddedSlot } = {}
    local remaining = amount

    while remaining > 0 do
        local item = createItem(state, itemId, remaining, metadata)

        local placed = false
        local slotType: SlotType? = nil
        local slot: number? = nil
        local reason: string? = nil

        local placement = options.Placement or "Auto"

        if placement == "Backpack" then
            slot, reason = placeItemInStorage(state, item)

            if slot then
                slotType = "Storage"
                placed = true
            end
        elseif placement == "Hotbar" then
            slot, reason = placeItemInHotbar(state, item, options.Slot)

            if slot then
                slotType = "Hotbar"
                placed = true
            end
        elseif placement == "Auto" then
            slot, reason = placeItemInHotbar(state, item, nil)

            if slot then
                slotType = "Hotbar"
                placed = true
            else
                slot, reason = placeItemInStorage(state, item)

                if slot then
                    slotType = "Storage"
                    placed = true
                end
            end
        else
            reason = "INVALID_PLACEMENT"
        end

        if not placed or not slotType or not slot then
            destroyUnplacedItem(state, item)
            return addedItems, remaining, reason
        end

        table.insert(addedItems, {
            uuid = item.UUID,
            slotType = slotType,
            slot = slot,
        })

        remaining -= item.Amount
    end

    return addedItems, 0, nil
end

function Operations.add(
    state: InventoryState,
    itemData: ItemInput,
    options: AddOptions?
): AddResult
    options = options or {}

    local itemId, amount, metadata, normalizeError = Metadata.normalize(itemData)

    if normalizeError or not itemId or not amount or not metadata then
        return {
            success = false,
            reason = normalizeError or "INVALID_ITEM_DATA",
            addedAmount = 0,
            overflow = 0,
        }
    end

    local originalAmount = amount
    local remainingCapacity = State.getRemainingCapacity(state)

    if remainingCapacity <= 0 then
        return {
            success = false,
            reason = "FULL",
            addedAmount = 0,
            overflow = amount,
        }
    end

    local amountToAdd = math.min(amount, remainingCapacity)
    local amountLeft = amountToAdd

    local updatedItems: { number } = {}

    if state.Settings.CanStack then
        local stackedAmount, updates = Stack.tryStack(state, itemId, amountLeft, metadata)

        amountLeft -= stackedAmount
        updatedItems = updates
    end

    local addedItems: { Types.AddedSlot } = {}

    if amountLeft > 0 then
        local createdItems, leftover, placeReason = addNewStacks(
            state,
            itemId,
            amountLeft,
            metadata,
            options
        )

        addedItems = createdItems
        amountLeft = leftover

        if #addedItems == 0 and next(updatedItems) == nil then
            return {
                success = false,
                reason = placeReason or "ADD_FAILED",
                addedItems = addedItems,
                updatedItems = updatedItems,
                addedAmount = 0,
                overflow = originalAmount,
            }
        end
    end

    local addedAmount = amountToAdd - amountLeft
    local overflow = originalAmount - addedAmount

    return {
        success = addedAmount > 0,
        reason = overflow > 0 and "PARTIAL" or nil,
        addedItems = addedItems,
        updatedItems = updatedItems,
        addedAmount = addedAmount,
        overflow = overflow,
    }
end

function Operations.remove(
    state: InventoryState,
    uuid: string,
    amount: number?
): RemoveResult
    local item = state.Items[uuid]

    if not item then
        return {
            success = false,
            reason = "ITEM_NOT_FOUND",
        }
    end

    local amountToRemove = amount or item.Amount

    if not Utils.isPositiveNumber(amountToRemove) then
        return {
            success = false,
            reason = "INVALID_AMOUNT",
        }
    end

    amountToRemove = math.min(amountToRemove, item.Amount)

    local location = Slots.getLocation(state, uuid)
    local slotType = if location then location.Type else nil
    local slot = if location then location.Slot else nil

    local removedItem: Item = {
        UUID = item.UUID,
        Id = item.Id,
        Amount = amountToRemove,
        Metadata = Utils.deepCopy(item.Metadata) :: ItemMetadata,
    }

    if item.Amount > amountToRemove then
        item.Amount -= amountToRemove
        State.removeWeight(state, amountToRemove)

        return {
            success = true,
            removedItem = removedItem,
            remaining = item.Amount,
            slotType = slotType,
            slot = slot,
        }
    end

    State.removeWeight(state, item.Amount)

    state.Items[uuid] = nil
    state.LocationByUUID[uuid] = nil
    removeFromIndex(state, item.Id, uuid)

    if state.EquippedItemUUID == uuid then
        state.EquippedItemUUID = nil
    end

    if slotType == "Hotbar" and slot then
        Slots.clearHotbarSlot(state, slot)
        Slots.compactHotbar(state)
    elseif slotType == "Storage" and slot then
        Slots.removeStorageAt(state, slot)
    end

    return {
        success = true,
        removedItem = removedItem,
        remaining = 0,
        slotType = slotType,
        slot = slot,
    }
end

return Operations