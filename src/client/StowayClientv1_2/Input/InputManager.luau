-- src/client/StowayClientv1_2/Input/InputManager.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IllusionIAS = require(ReplicatedStorage.Packages.IllusionIAS)
local Binds = require(ReplicatedStorage.Shared.Binds)

local InputManager = {}
InputManager.ContextGlobal = "StowayGlobal"
InputManager.ContextCombat = "StowayCombat"
InputManager.ContextInventory = "StowayInventory"
InputManager.ContextDrop = "StowayDrop"

InputManager.HotbarActions = {} -- { [1] = IASObject, ... }
InputManager.BackpackAction = nil

function InputManager.Init()
    -- Initialize Contexts
    IllusionIAS.newContext(InputManager.ContextGlobal)
    IllusionIAS.newContext(InputManager.ContextCombat)
    IllusionIAS.newContext(InputManager.ContextInventory)
    IllusionIAS.newContext(InputManager.ContextDrop)

    -- Initialize Backpack Action
    local bpAction = IllusionIAS.new("BackpackAction")
    InputManager.BackpackAction = bpAction

    -- Initialize Hotbar Actions
    local slotCount = #Binds.HotbarSlots
    if slotCount < 10 then slotCount = 10 end

    for i = 1, slotCount do
        if not InputManager.HotbarActions[i] then
            local action = IllusionIAS.new("HotbarSlot" .. i)
            table.insert(InputManager.HotbarActions, action)
        end
    end

    -- Add to contexts
    IllusionIAS.addContext(InputManager.ContextGlobal, bpAction)
    IllusionIAS.addContext(InputManager.ContextCombat, unpack(InputManager.HotbarActions))

    -- Apply Binds
    InputManager.UpdateBinds()

    -- Enable Contexts
    IllusionIAS.enableContext(InputManager.ContextGlobal, true)
    IllusionIAS.enableContext(InputManager.ContextCombat, true)
    IllusionIAS.enableContext(InputManager.ContextInventory, false) -- Default Off
    IllusionIAS.enableContext(InputManager.ContextDrop, false)
end

function InputManager.SetCombatEnabled(enabled: boolean)
    IllusionIAS.enableContext(InputManager.ContextCombat, enabled)
end

function InputManager.SetInventoryEnabled(enabled: boolean)
    IllusionIAS.enableContext(InputManager.ContextInventory, enabled)
end

function InputManager.SetDropEnabled(enabled: boolean)
    IllusionIAS.enableContext(InputManager.ContextDrop, enabled)
end

function InputManager.UpdateBinds()
    if InputManager.BackpackAction then
        InputManager.BackpackAction:ClearBinds()
        local binds = Binds.Global.Backpack
        if binds then
            if binds.PC then
                for _, b in ipairs(binds.PC) do
                    InputManager.BackpackAction:AddBind(b.Main, unpack(b.Modifiers or {}))
                end
            end
            if binds.Console then
                for _, b in ipairs(binds.Console) do
                    InputManager.BackpackAction:AddBind(b.Main, unpack(b.Modifiers or {}))
                end
            end
        end
    end

    for i, action in ipairs(InputManager.HotbarActions) do
        local bindData = Binds.HotbarSlots[i]
        if bindData then
            action:ClearBinds()
            if bindData.PC then
                for _, b in ipairs(bindData.PC) do
                    action:AddBind(b.Main, unpack(b.Modifiers or {}))
                end
            end
            if bindData.Console then
                for _, b in ipairs(bindData.Console) do
                     action:AddBind(b.Main, unpack(b.Modifiers or {}))
                end
            end
        end
    end
end

function InputManager.Destroy()
    -- Cleanup Actions
    if InputManager.BackpackAction then
        InputManager.BackpackAction:Destroy()
        InputManager.BackpackAction = nil
    end

    for _, action in ipairs(InputManager.HotbarActions) do
        action:Destroy()
    end
    table.clear(InputManager.HotbarActions)

    -- Cleanup Contexts
    IllusionIAS.removeContext(InputManager.ContextGlobal)
    IllusionIAS.removeContext(InputManager.ContextCombat)
    IllusionIAS.removeContext(InputManager.ContextInventory)
    IllusionIAS.removeContext(InputManager.ContextDrop)
end

return InputManager
