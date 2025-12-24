-- src/client/StowayClientV1_2/NetworkFunctions/NetworkHandler.luau
-- Centralized Network Gateway for Inventory System V1.2
-- This module handles all server communication (incoming & outgoing)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkHandler = {}

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryUpdate = Remotes:WaitForChild("InventoryUpdate") :: RemoteEvent
local InventoryAction = Remotes:WaitForChild("InventoryAction") :: RemoteEvent

-- Connection storage for cleanup
local _updateConnection = nil


function NetworkHandler.Send(action: string, args: {[string]: any})
    InventoryAction:FireServer(action, args)
end


function NetworkHandler.Init(handlers: {[string]: (any) -> ()})
    if _updateConnection then
        _updateConnection:Disconnect()
    end
    
    _updateConnection = InventoryUpdate.OnClientEvent:Connect(function(action: string, payload: any)
        local handler = handlers[action]
        if handler then
            handler(payload)
        else
            warn("[NetworkHandler] Unknown action received:", action)
        end
    end)
end


function NetworkHandler.Destroy()
    if _updateConnection then
        _updateConnection:Disconnect()
        _updateConnection = nil
    end
end

return NetworkHandler
