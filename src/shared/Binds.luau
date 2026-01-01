-- ReplicatedStorage/Shared/Binds.lua

local Binds = {}

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
        Console = { {Main = Enum.KeyCode.ButtonSelect}, {Main = Enum.KeyCode.DPadLeft} }
    }
}

return Binds
