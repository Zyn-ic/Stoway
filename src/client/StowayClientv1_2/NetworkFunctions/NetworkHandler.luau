-- src/client/Inventory/NetworkHandler.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryUpdateRemote = ReplicatedStorage.Remotes.InventoryUpdate
local Fusion = require(ReplicatedStorage.Packages.fusion)
local Store = require(script.Parent.Parent.CoreState.InventoryStore)

local NetworkHandler = {}

function NetworkHandler.Init()
    InventoryUpdateRemote.OnClientEvent:Connect(NetworkHandler.ProcessUpdate)
end

function NetworkHandler.ProcessUpdate(action: string, payload: any)
    -- This looks at the Store and forces it to match the payload
    -- Because the UI listens to the Store, the UI will correct itself automatically.
    
    if action == "FullSync" then
        Store.Init(payload)
        
    elseif action == "UpdateSlot" then
        -- Example: Server says "Slot 1 in Hotbar is now UUID 'XYZ'"
        local newHotbar = table.clone(Fusion.peek(Store.Hotbar))
        newHotbar[payload.Slot] = payload.UUID
        Store.Hotbar:set(newHotbar)
        
        -- Also update item data if provided
        if payload.ItemData then
            local newItems = table.clone(Fusion.peek(Store.Items))
            newItems[payload.UUID] = payload.ItemData
            Store.Items:set(newItems)
        end
    end
end

return NetworkHandler