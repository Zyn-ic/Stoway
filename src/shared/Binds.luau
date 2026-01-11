-- ReplicatedStorage/Shared/Binds.lua

local Binds = {}

-- Helper function to apply binds to an action
-- Usage: Binds.ApplyToAction(action, Binds.Global.InventoryActions.Swap)
-- Or:   Binds.ApplyToAction(action, Binds.Global.InventoryActions.Swap, "Console") -- Console only
function Binds.ApplyToAction(action, bindConfig, inputType: ("PC" | "Console")?)
    if not action or not bindConfig then return end

    local function applyBinds(binds)
        if not binds then return end
        for _, b in ipairs(binds) do
            action:AddBind(b.Main, unpack(b.Modifiers or {}))
        end
    end

    if inputType then
        applyBinds(bindConfig[inputType])
    else
        applyBinds(bindConfig.PC)
        applyBinds(bindConfig.Console)
    end
end

-- Hotbar Slots Configuration
-- PC: Standard number keys
-- Console: Combo binds (e.g., R1 + Button)
Binds.HotbarSlots = {
    [1] = {
        Display = "1",
        PC = { {Main = Enum.KeyCode.One} },
        Console = { {Main = Enum.KeyCode.ButtonX, Modifiers = {Enum.KeyCode.ButtonR1}} } -- R1 + X
    },
    [2] = {
        Display = "2",
        PC = { {Main = Enum.KeyCode.Two} },
        Console = { {Main = Enum.KeyCode.ButtonY, Modifiers = {Enum.KeyCode.ButtonR1}} } -- R1 + Y
    },
    [3] = {
        Display = "3",
        PC = { {Main = Enum.KeyCode.Three} },
        Console = { {Main = Enum.KeyCode.ButtonB, Modifiers = {Enum.KeyCode.ButtonR1}} } -- R1 + B
    },
    [4] = {
        Display = "4",
        PC = { {Main = Enum.KeyCode.Four} },
        Console = { {Main = Enum.KeyCode.ButtonA, Modifiers = {Enum.KeyCode.ButtonR1}} } -- R1 + A
    },
    [5] = {
        Display = "5",
        PC = { {Main = Enum.KeyCode.Five} },
        Console = { {Main = Enum.KeyCode.ButtonX, Modifiers = {Enum.KeyCode.ButtonL1}} } -- L1 + X
    },
    [6] = {
        Display = "6",
        PC = { {Main = Enum.KeyCode.Six} },
        Console = { {Main = Enum.KeyCode.ButtonY, Modifiers = {Enum.KeyCode.ButtonL1}} } -- L1 + Y
    },
    [7] = {
        Display = "7",
        PC = { {Main = Enum.KeyCode.Seven} },
        Console = { {Main = Enum.KeyCode.ButtonB, Modifiers = {Enum.KeyCode.ButtonL1}} } -- L1 + B
    },
    [8] = {
        Display = "8",
        PC = { {Main = Enum.KeyCode.Eight} },
        Console = { {Main = Enum.KeyCode.ButtonA, Modifiers = {Enum.KeyCode.ButtonL1}} } -- L1 + A
    },
    [9] = {
        Display = "9",
        PC = { {Main = Enum.KeyCode.Nine} },
        Console = { {Main = Enum.KeyCode.DPadUp, Modifiers = {Enum.KeyCode.ButtonR1}} } -- R1 + DPadUp
    },
    [10] = {
        Display = "0",
        PC = { {Main = Enum.KeyCode.Zero} },
        Console = { {Main = Enum.KeyCode.DPadDown, Modifiers = {Enum.KeyCode.ButtonR1}} } -- R1 + DPadDown
    }
}

-- Global Binds
Binds.Global = {
    Backpack = {
        PC = { {Main = Enum.KeyCode.Tab}, {Main = Enum.KeyCode.B} },
        Console = { {Main = Enum.KeyCode.DPadLeft} }
    },
    SwitchMode = {
        PC = { {Main = Enum.KeyCode.M} }, -- Testing bind
        Console = { {Main = Enum.KeyCode.ButtonL3} } -- Long press logic
    },
    InventoryActions = {
        Swap = {
            Console = { {Main = Enum.KeyCode.ButtonY} }
        },
        Drop = {
            Console = { {Main = Enum.KeyCode.ButtonX} }
        },
        QuickMove = {
            Console = { {Main = Enum.KeyCode.ButtonL1}, Modifiers = {Enum.KeyCode.ButtonR1} }
        },
        Cancel = {
            Console = { {Main = Enum.KeyCode.ButtonB} }
        }
    },
    DropActions = {
        Increase = { Console = { {Main = Enum.KeyCode.DPadUp} } },
        Decrease = { Console = { {Main = Enum.KeyCode.DPadDown} } },
    }
}

return Binds
