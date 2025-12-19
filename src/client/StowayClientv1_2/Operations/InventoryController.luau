-- src/client/Inventory/InventoryController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryActionRemote = ReplicatedStorage.Remotes.InventoryAction

local Store = require(script.Parent.Parent.CoreState.InventoryStore)
local Fusion = require(ReplicatedStorage.Packages.fusion)
local Settings = require(ReplicatedStorage.Shared.Settings)
local _peek = Fusion.peek

local Controller = {}

--// Helper to safely get data

function CreateSlotFrameName(slotnumber:number): string
    local numberstring = tostring(slotnumber) :: string
    local slotframeName = ""
    local len = numberstring:len()

    if len > 1 then
        for _= 1, (len - 1) do
            slotframeName ..= "_"
        end
    end

    slotframeName..= numberstring

    return slotframeName
end

--// Controller.Add(payload: { Slots: { {UUID, SlotType, Slot, Item} } })
function Controller.Add(payload)
    -- Get current state
    local items = table.clone(_peek(Store.Items))
    local hotbar = table.clone(_peek(Store.Hotbar))
    local storage = table.clone(_peek(Store.Storage))
    
    local weightChange = 0

    for _, data in ipairs(payload.Slots) do
        -- 1. Register the full item data in the central Items map
        items[data.UUID] = data.Item
        weightChange += data.Item.Amount or 1
        
        -- 2. Place it in the correct container
        if data.SlotType == "Hotbar" then
            -- For Hotbar, we target a specific index (1-9)
            hotbar[data.Slot] = data.UUID
        else
            -- For Storage, your state is a packed array {string}
            -- We insert it at the end (or specific slot if server dictates)
            if data.Slot > #storage then
                table.insert(storage, data.UUID)
            else
                table.insert(storage, data.Slot, data.UUID)
            end
        end
    end

    -- Update the State Objects (This triggers the Fusion UI automatically)
    Store.Items:set(items)
    Store.Hotbar:set(hotbar)
    Store.Storage:set(storage)
    
    -- Update weight
    Store.Weight:set(_peek(Store.Weight) + weightChange)
end

function Controller.AddToBackpack(fromType: string, fromIndex: number)
    local state = Store:GetState()
    local hotbar = table.clone(state.Hotbar)
    local storage = table.clone(state.Storage)
    
    -- 1. Get the UUID from the source
    local uuidToMove = hotbar[fromIndex]
    if not uuidToMove then return end

    -- 2. Logic Check: Only move if coming from Hotbar
    -- (If dragging Storage to Storage void, we usually do nothing or move to end)
    if fromType == "Hotbar" then
        -- Clear the source slot
        hotbar[fromIndex] = nil
        
        -- Append to the end of storage
        table.insert(storage, uuidToMove)
        
        -- Update State (Triggers Fusion UI)
        Store.Hotbar:set(hotbar)
        Store.Storage:set(storage)
        
        
        print("Moved item to backpack end")
    end
end

-- src/client/Inventory/InventoryController.luau

function Controller.Remove(slotType: string, slotIndex: number, Scope)
    local state = Store:GetState()
    local uuid = Store:GetUUidFromIndex(slotIndex, slotType)
    local uuidToRemove = nil

    if not Settings.Gameplay.Droppable or not _peek(Store.Settings).Droppable or not Store:GetDroppableStatus(uuid) then return uuidToRemove end
    
    --// MODE 1: HOTBAR (Soft Delete)
    -- We want the slot to stay, but the item to vanish.
    -- We do NOT use table.remove, because that would shift Hotbar Slot 2 to Slot 1.
    if slotType == "Hotbar" then
        local newHotbar = table.clone(state.Hotbar)
        local newItems = table.clone(state.Items)
        local newWeight = _peek(Store.Weight) - Store:GetWeightOfUuid(uuid)
        uuidToRemove = newHotbar[slotIndex]
        
        if uuidToRemove then
            newHotbar[slotIndex] = nil -- Just clear the value
            newItems[uuidToRemove] = nil
            Store.Items:set(newItems)
            Store.Hotbar:set(newHotbar)
            Store.Weight:set(newWeight)
        end
        
    --// MODE 2: STORAGE (Hard Delete)
    -- We want the slot frame to be destroyed.
    -- We USE table.remove. This shrinks the array size.
    elseif slotType == "Storage" then
        local newStorage = table.clone(state.Storage)
        local newItems = table.clone(state.Items)
        local newWeight = _peek(Store.Weight) - Store:GetWeightOfUuid(Store:GetUUidFromIndex(slotIndex, slotType))
        uuidToRemove = newStorage[slotIndex]
        Store.Weight:set(newWeight)
        
        if uuidToRemove then
            -- This shifts all items down. Index 5 becomes Index 4.
            -- The total count decreases by 1.
            table.remove(newStorage, slotIndex) 
            newItems[uuidToRemove] = nil
            Store.Items:set(newItems)
            Store.Storage:set(newStorage)
            Store.Weight:set(newWeight)
        end
    end

    --// CLEANUP: Unequip if holding that item
    if uuidToRemove and state.Equipped == uuidToRemove then
        Controller.SetUnequipped()
    end

    if slotType == "Storage" then
        task.defer( function()
            local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("StowayGui").Stoway
            local backpackframe = gui.Backpack.ScrollingFrame
            local frame = backpackframe:FindFirstChild(tostring(CreateSlotFrameName(slotIndex)))
            --print(gui, backpackframe, frame)
            if frame then
                Scope:doCleanup()
            end
        end)
    end

    return uuidToRemove
end

function Controller.Drop(slotType: string, slotIndex: number, Scope)
    local droppedUUID = Controller.Remove(slotType, slotIndex, Scope)
    if droppedUUID then
        warn("fired to server to drop")
        -- Fire Server to spawn the drop in the world
        -- InventoryActionRemote:FireServer("Drop", {UUID = droppedUUID}) 
    end
end

--// ACTION: SWAP
function Controller.Swap(fromType: string, fromSlot: number, toType: string, toSlot: number)
    local state = Store:GetState()
    local newHotbar = table.clone(state.Hotbar)
    local newStorage = table.clone(state.Storage)
    
    local function getRef(t) return t == "Hotbar" and newHotbar or newStorage end
    
    local ListA = getRef(fromType)
    local ListB = getRef(toType)

    local ListAValue = ListA[fromSlot]
    local ListBValue = ListB[toSlot]

    --// LOGIC: If moving from Storage to Hotbar
    if fromType == "Storage" and toType == "Hotbar" then
        -- 1. Put the storage item into the hotbar
        newHotbar[toSlot] = ListAValue
        -- 2. Remove the item from storage (shifting indices)
        table.remove(newStorage, fromSlot)
    
    --// LOGIC: If moving from Hotbar to Storage (Empty Slot)
    elseif fromType == "Hotbar" and toType == "Storage" and ListBValue == nil then
        newHotbar[fromSlot] = nil
        table.insert(newStorage, ListAValue)
        -- No cleanup needed for Hotbar source, it just becomes invisible
        
    else
        -- Standard swap for Hotbar <-> Hotbar or Storage <-> Storage
        ListA[fromSlot] = ListBValue
        ListB[toSlot] = ListAValue
    end

    -- Update Stores
    Store.Hotbar:set(newHotbar)
    Store.Storage:set(newStorage)
    
    InventoryActionRemote:FireServer("Swap", {
        From = {Type = fromType, Slot = fromSlot},
        To = {Type = toType, Slot = toSlot}
    })
end

--// ACTION: EQUIP
function Controller.HandleEquipped(uuid:string)
    if _peek(Store.EquippedUUID) == uuid then
        Controller.SetUnequipped()
    else
        Controller.SetEquipped(uuid)
    end
end

function Controller.SetEquipped(uuid: string?)
    -- Optimistic
    Store.EquippedUUID:set(uuid)
end

function Controller.SetUnequipped()
    Store.EquippedUUID:set(nil)
end

return Controller