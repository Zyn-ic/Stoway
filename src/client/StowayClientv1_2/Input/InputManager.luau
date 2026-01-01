-- src/client/StowayClientv1_2/Input/InputManager.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IllusionIAS = require(ReplicatedStorage.Packages.IllusionIAS)
local Binds = require(ReplicatedStorage.Shared.Binds)

local InputManager = {}
InputManager.ContextName = "StowayGameplay"
InputManager.HotbarActions = {} -- { [1] = IASObject, ... }
InputManager.BackpackAction = nil

function InputManager.Init()
    -- Initialize Context
    IllusionIAS.newContext(InputManager.ContextName)

    -- Initialize Backpack Action
    local bpAction = IllusionIAS.new("BackpackAction")
    InputManager.BackpackAction = bpAction

    -- Initialize Hotbar Actions
    -- We'll initialize based on Binds.HotbarSlots length or a fixed number
    local slotCount = #Binds.HotbarSlots
    if slotCount < 10 then slotCount = 10 end -- Default to at least 10

    for i = 1, slotCount do
        if not InputManager.HotbarActions[i] then
            local action = IllusionIAS.new("HotbarSlot" .. i)
            table.insert(InputManager.HotbarActions, action)
        end
    end

    -- Add to context
    IllusionIAS.addContext(InputManager.ContextName, bpAction, unpack(InputManager.HotbarActions))

    -- Apply Binds
    InputManager.UpdateBinds()

    -- Enable Context
    IllusionIAS.enableContext(InputManager.ContextName, true)
end

function InputManager.UpdateBinds()
    -- Update Backpack Binds
    if InputManager.BackpackAction then
        InputManager.BackpackAction:ClearBinds()
        local bpBinds = Binds.Global.Backpack
        if bpBinds then
            if bpBinds.PC then
                for _, b in ipairs(bpBinds.PC) do
                    InputManager.BackpackAction:AddBind(b.Main, unpack(b.Modifiers or {}))
                end
            end
            if bpBinds.Console then
                for _, b in ipairs(bpBinds.Console) do
                    InputManager.BackpackAction:AddBind(b.Main, unpack(b.Modifiers or {}))
                end
            end
        end
    end

    -- Update Hotbar Binds
    for i, action in ipairs(InputManager.HotbarActions) do
        local slotBinds = Binds.HotbarSlots[i]
        if slotBinds then
            action:ClearBinds()
            if slotBinds.PC then
                for _, b in ipairs(slotBinds.PC) do
                    action:AddBind(b.Main, unpack(b.Modifiers or {}))
                end
            end
            if slotBinds.Console then
                for _, b in ipairs(slotBinds.Console) do
                     action:AddBind(b.Main, unpack(b.Modifiers or {}))
                end
            end
        end
    end
end

return InputManager
