-- src/client/Inventory/InventoryStore.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Types = require(ReplicatedStorage.Shared.Types)

local Scope = Fusion.scoped(Fusion)
local peek = Fusion.peek

--// 1. Define the Atoms (The raw data)
local Store = {
    Items = Scope:Value({}),        -- {[uuid] = ItemData}
    Hotbar = Scope:Value({}),       -- {[slotIndex] = uuid}
    Storage = Scope:Value({}),      -- {[slotIndex] = uuid} (Array or Dict)
    EquippedUUID = Scope:Value(nil),
    Weight = Scope:Value(0),
    Settings = Scope:Value({}),     -- Static settings from server

    -- Expose Scope for cleanup if needed
    Scope = Scope
}

--// 2. Initialize Function (Called once by Main)
function Store.Init(initialData)
    if not initialData then return end
    Store.Items:set(initialData.Items or {})
    Store.Hotbar:set(initialData.Hotbar or {})
    Store.Storage:set(initialData.Storage or {})
    Store.EquippedUUID:set(initialData.EquippedUUID or initialData.EquippedItemUUID)
    Store.Weight:set(initialData.Weight or 0)
    Store.Settings:set(initialData.Settings or {})
end

function Store:GetState()
    return {
        Hotbar = peek(Store.Hotbar),
        Storage = peek(Store.Storage),
        Items = peek(Store.Items),
        Equipped = peek(Store.EquippedUUID)
    }
end

function Store:GetHotbar()
    return peek(Store.Hotbar)
end

function Store:GetStorage()
    return peek(Store.Storage)
end

function Store:GetEquippedUUID()
    return peek(Store.EquippedUUID)
end

function Store:GetUUidFromIndex(index:number, slottype:string?): nil | string
    local hotbarcheck
    local storagecheck

    if not slottype then
        hotbarcheck = peek(Store.Hotbar)[index]
        storagecheck = peek(Store.Storage)[index]

        if hotbarcheck then return hotbarcheck end
        if storagecheck then return storagecheck end

        return nil
    end

    if slottype == "Hotbar" then
        hotbarcheck = peek(Store.Hotbar)[index]
        return hotbarcheck
    end

    if slottype == "Storage" then
        storagecheck = peek(Store.Storage)[index]
        return storagecheck
    end

    return nil
end


function Store:DoesItemExist(uuid:string): Types.ItemData?
    if not uuid then return nil end
    local check = peek(Store.Items)[uuid]
    return check
end

function Store:GetWeightOfUuid(uuid:string) : number | nil
    local item = Store:DoesItemExist(uuid)
    if item then
        return item.Amount
    end

    return nil
end

function Store:GetDroppableStatus(uuid:string) : boolean | nil
    local item = Store:DoesItemExist(uuid)
    if item then
        return item.Metadata.Droppable
    end

    return nil
end

function Store:FindSlotByUUID(uuid: string): (string?, number?)
    if not uuid then return nil, nil end

    -- Check Hotbar first
    local hotbar = peek(Store.Hotbar)
    for slotIndex, slotUUID in pairs(hotbar) do
        if slotUUID == uuid then
            return "Hotbar", slotIndex
        end
    end

    -- Check Storage
    local storage = peek(Store.Storage)
    for slotIndex, slotUUID in ipairs(storage) do
        if slotUUID == uuid then
            return "Storage", slotIndex
        end
    end

    return nil, nil
end

-- Get item data from a specific slot
function Store:GetItemFromSlot(slotType: string, slotIndex: number): Types.ItemData?
    local uuid = Store:GetUUidFromIndex(slotIndex, slotType)
    if not uuid then return nil end
    return peek(Store.Items)[uuid]
end

-- Get max hotbar slots from settings
function Store:GetMaxHotbarSlots(): number
    local settings = peek(Store.Settings)
    return (settings and settings.MaxHotbarSlots) or 10
end

function Store.CreateSlotFrameName(slotnumber:number): string
    local numberstring = tostring(slotnumber) :: string
    local slotframeName = ""
    local len = numberstring:len()

    if len > 1 then
        for _ = 1, (len - 1) do
            slotframeName ..= "_"
        end
    end

    slotframeName ..= numberstring
    return slotframeName
end

-- Build a packed view of occupied hotbar slots without mutating server-auth slot indices.
function Store:GetVisibleHotbarSlotMap(): ({ [number]: number }, { [number]: number })
    local hotbar = peek(Store.Hotbar)
    local items = peek(Store.Items)
    local maxSlots = Store:GetMaxHotbarSlots()

    local visibleToReal = {}
    local realToVisible = {}
    local visibleIndex = 0

    for realSlot = 1, maxSlots do
        local uuid = hotbar[realSlot]
        if uuid and items[uuid] then
            visibleIndex += 1
            visibleToReal[visibleIndex] = realSlot
            realToVisible[realSlot] = visibleIndex
        end
    end

    return visibleToReal, realToVisible
end

function Store:GetHotbarSlotFromVisibleIndex(visibleIndex: number): number?
    local visibleToReal = Store:GetVisibleHotbarSlotMap()
    return visibleToReal[visibleIndex]
end

function Store:GetVisibleHotbarIndexFromSlot(realSlot: number): number?
    local _visibleToReal, realToVisible = Store:GetVisibleHotbarSlotMap()
    return realToVisible[realSlot]
end

function Store:GetUUidFromVisibleHotbarIndex(visibleIndex: number): string?
    local realSlot = Store:GetHotbarSlotFromVisibleIndex(visibleIndex)
    if not realSlot then return nil end
    return peek(Store.Hotbar)[realSlot]
end

function Store:GetFirstOccupiedHotbarButton(hotbarFrame: Instance?): GuiObject?
    if not hotbarFrame then return nil end

    local firstSlotIndex = nil
    if Settings.Hotbar.Type == "Dynamic" then
        -- Dynamic hotbar is packed; slot 1 is first occupied when any item exists.
        if Store:GetUUidFromIndex(1, "Hotbar") then
            firstSlotIndex = 1
        else
            -- Safety fallback if packed invariant is broken by external mutation.
            firstSlotIndex = Store:GetHotbarSlotFromVisibleIndex(1)
        end
    else
        local maxSlots = Store:GetMaxHotbarSlots()
        for i = 1, maxSlots do
            if Store:GetUUidFromIndex(i, "Hotbar") then
                firstSlotIndex = i
                break
            end
        end
    end

    if not firstSlotIndex then return nil end

    local slotFrame = hotbarFrame:FindFirstChild(Store.CreateSlotFrameName(firstSlotIndex))
    if not slotFrame then return nil end

    local slotButton = slotFrame:FindFirstChild("slotbutton")
    if slotButton and slotButton:IsA("GuiObject") and slotButton.Visible then
        return slotButton
    end

    return nil
end

-- Find first empty hotbar slot
function Store:FindFirstEmptyHotbarSlot(): number?
    local hotbar = peek(Store.Hotbar)
    local items = peek(Store.Items)
    local maxSlots = Store:GetMaxHotbarSlots()

    for i = 1, maxSlots do
        local uuid = hotbar[i]
        if not uuid or not items[uuid] then
            return i
        end
    end

    return nil -- Hotbar full
end

-- Find first available storage slot (next index)
function Store:FindFirstEmptyStorageSlot(): number
    local storage = peek(Store.Storage)
    return #storage + 1
end

return Store
