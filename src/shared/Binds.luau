-- ReplicatedStorage/Shared/Binds.lua

local Binds = {}

-- NEW STRUCTURE: An ordered array for hotbar slots
-- The 1st element is for slot 1, 2nd for slot 2, 10th for slot 10, etc.
Binds.KeyBinds = {
    -- Slot 1
    { Display = "1", Keys = {Enum.KeyCode.One} },
    -- Slot 2
    { Display = "2", Keys = {Enum.KeyCode.Two} },
    -- Slot 3
    { Display = "3", Keys = {Enum.KeyCode.Three} },
    -- Slot 4
    { Display = "4", Keys = {Enum.KeyCode.Four} },
    -- Slot 5
    { Display = "5", Keys = {Enum.KeyCode.Five} },
    -- Slot 6
    { Display = "6", Keys = {Enum.KeyCode.Six} },
    -- Slot 7
    { Display = "7", Keys = {Enum.KeyCode.Seven} },
    -- Slot 8
    { Display = "8", Keys = {Enum.KeyCode.Eight} },
    -- Slot 9
    { Display = "9", Keys = {Enum.KeyCode.Nine} },
    -- Slot 10 (Displays "0" but is at index 10)
    { Display = "0", Keys = {Enum.KeyCode.Zero} },
    -- Slot 11 (Simply the next item in the list!)
    { Display = "T", Keys = {Enum.KeyCode.T} },
    -- Slot 12 (Example of multiple keys for one slot)
    { Display = "G", Keys = {Enum.KeyCode.G, Enum.KeyCode.H} },
    -- Add as many more as you might need...
}

-- Other binds like Backpack toggle can remain the same
Binds.BackpackBinds = {Enum.KeyCode.Tab, Enum.KeyCode.ButtonY}

return Binds