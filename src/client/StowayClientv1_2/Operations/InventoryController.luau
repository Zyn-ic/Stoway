-- src/client/Inventory/InventoryController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Store = require(script.Parent.Parent.CoreState.InventoryStore)
local NetworkHandler = require(script.Parent.Parent.NetworkFunctions.NetworkHandler)
local Fusion = require(ReplicatedStorage.Packages.fusion)
local GlobalSettings = require(ReplicatedStorage.Shared.Settings)
local _peek = Fusion.peek

local Controller = {}

--// Helper to safely get data

function _CreateSlotFrameName(slotnumber:number): string
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
    local items = table.clone(_peek(Store.Items))
    local hotbar = table.clone(_peek(Store.Hotbar))
    local storage = table.clone(_peek(Store.Storage))
    
    local weightChange = 0

    for _, data in ipairs(payload.Slots) do
        -- 1. Register the full item data in the central Items map
        if items[data.UUID] then return end
        items[data.UUID] = data.Item
        weightChange += data.Item.Amount or 1
        
        -- 2. Place it in the correct container
        if data.SlotType == "Hotbar" then
            -- For Hotbar, we target a specific index (1-9) e.g
            hotbar[data.Slot] = data.UUID
        else
            -- We insert it at the end (or specific slot if server dictates)
            if data.Slot > #storage then
                table.insert(storage, data.UUID)
            else
                table.insert(storage, data.Slot, data.UUID)
            end
        end
    end

    Store.Items:set(items)
    Store.Hotbar:set(hotbar)
    Store.Storage:set(storage)
    
    Store.Weight:set(_peek(Store.Weight) + weightChange)
end

function Controller.AddToBackpack(fromType: string, fromIndex: number, REPLICATE:boolean)
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
        
        if REPLICATE then
            NetworkHandler.Send("Swap", {
            fromType = fromType, fromSlot = fromIndex,
            toType = "Storage", toSlot = #storage
        })
        end
        print("Moved item to backpack end")
    end
end

function Controller.Remove(slotType: string, slotIndex: number, REPLICATE:boolean)
    local state = Store:GetState()
    local uuid = Store:GetUUidFromIndex(slotIndex, slotType)
    local uuidToRemove = nil

    -- Check Settings: First check per-player settings, fallback to global
    local playerSettings = _peek(Store.Settings)
    local isDroppable = playerSettings.Gameplay and playerSettings.Gameplay.Droppable
    if isDroppable == nil then isDroppable = GlobalSettings.Gameplay.Droppable end
    
    if not isDroppable then return uuidToRemove end
    if not Store:GetDroppableStatus(uuid) then return uuidToRemove end
    
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
        local newWeight = _peek(Store.Weight) - Store:GetWeightOfUuid(uuid)
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
        Controller.SetUnequipped(REPLICATE)
    end


    --automatic clean up but incase the memory goes up for some reason imma keep this here
    -- if slotType == "Storage" then
    --     task.defer( function()
    --         local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("StowayGui").Stoway
    --         local backpackframe = gui.Backpack.ScrollingFrame
    --         local frame = backpackframe:FindFirstChild(tostring(CreateSlotFrameName(slotIndex)))
            
    --         -- extra clean up just incase but the scope should cleanup
    --         if frame then
    --             Scope:doCleanup()
    --         end
    --     end)
    -- end


    return uuidToRemove
end

function Controller.Drop(slotType: string, slotIndex: number, REPLICATE:boolean)
    local droppedUUID = Controller.Remove(slotType, slotIndex, REPLICATE)
    if droppedUUID then
        NetworkHandler.Send("Drop", {
            slotType = slotType,
            slot = slotIndex,
            uuid = droppedUUID
        })
    end
end

--// ACTION: SWAP
function Controller.Swap(fromType: string, fromSlot: number, toType: string, toSlot: number, REPLICATE:boolean)
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
    
    if REPLICATE then
        NetworkHandler.Send("Swap", {
            fromType = fromType, fromSlot = fromSlot,
            toType = toType, toSlot = toSlot
        })
    end
end

--// ACTION: EQUIP
function Controller.HandleEquipped(uuid:string?, REPLICATE:boolean)
    -- If targeting an empty slot (nil uuid)
    if uuid == nil then
        -- If we are currently holding something, unequip it
        if _peek(Store.EquippedUUID) ~= nil then
            Controller.SetUnequipped(REPLICATE)
        end
        return
    end

    if _peek(Store.EquippedUUID) == uuid then
        Controller.SetUnequipped(REPLICATE)
    else
        Controller.SetEquipped(uuid, REPLICATE)
    end
end

function Controller.SetEquipped(uuid: string, REPLICATE:boolean)
    Store.EquippedUUID:set(uuid)
    
    
    -- Notify server
    local slotType, slotIndex = Store:FindSlotByUUID(uuid)
    if slotType and slotIndex and REPLICATE then
        NetworkHandler.Send("Equip", { slotType = slotType, slot = slotIndex })
    end
end

function Controller.SetUnequipped(REPLICATE:boolean)
    Store.EquippedUUID:set(nil)
    if REPLICATE then NetworkHandler.Send("Unequip", {}) end
end

return Controller