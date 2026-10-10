--!strict

--@author: yyumchi
--@date: 2026-10-10
--[[@description:
	Per-layout bind table for JailbreakHotbar. Direct 1..10 equip binds
	(PC number row, console R1/L1 combos) plus the storage popup toggle.
	No Inventory-mode actions yet: sweep/paint-swap arrives in the logic
	pass and registers its own binds here.
]]

local Binds = {}

export type BindEntry = {
	Main: Enum.KeyCode,
	Modifiers: { Enum.KeyCode }?,
}

export type BindConfig = {
	Display: string?,
	PC: { BindEntry }?,
	Console: { BindEntry }?,
}

local IllusionIAS = require(game:GetService("ReplicatedStorage").Packages.IllusionIAS)

export type BindingAction = IllusionIAS.BindingObject

-- Applies PC, Console, or both into an IllusionIAS BindingObject.
function Binds.ApplyToAction(action: BindingAction, bindConfig: BindConfig?, inputType: ("PC" | "Console")?)
	if not action or not bindConfig then return end
	local function apply(binds: { BindEntry }?)
		if not binds then return end
		for _, b in binds do
			-- IllusionIAS AddBind(main, primary?, secondary?, UIButton?, UIModifier?, DisplayName?)
			local m1 = b.Modifiers and b.Modifiers[1] or nil
			local m2 = b.Modifiers and b.Modifiers[2] or nil
			action:AddBind(b.Main, m1, m2)
		end
	end
	if inputType == "PC" then
		apply(bindConfig.PC)
	elseif inputType == "Console" then
		apply(bindConfig.Console)
	else
		apply(bindConfig.PC)
		apply(bindConfig.Console)
	end
end

local HOTBAR_SLOTS: { [number]: BindConfig? } = {
	[1] = {
		Display = "1",
		PC = { { Main = Enum.KeyCode.One } },
		Console = { { Main = Enum.KeyCode.ButtonX, Modifiers = { Enum.KeyCode.ButtonR1 } } },
	},
	[2] = {
		Display = "2",
		PC = { { Main = Enum.KeyCode.Two } },
		Console = { { Main = Enum.KeyCode.ButtonY, Modifiers = { Enum.KeyCode.ButtonR1 } } },
	},
	[3] = {
		Display = "3",
		PC = { { Main = Enum.KeyCode.Three } },
		Console = { { Main = Enum.KeyCode.ButtonB, Modifiers = { Enum.KeyCode.ButtonR1 } } },
	},
	[4] = {
		Display = "4",
		PC = { { Main = Enum.KeyCode.Four } },
		Console = { { Main = Enum.KeyCode.ButtonA, Modifiers = { Enum.KeyCode.ButtonR1 } } },
	},
	[5] = {
		Display = "5",
		PC = { { Main = Enum.KeyCode.Five } },
		Console = { { Main = Enum.KeyCode.ButtonX, Modifiers = { Enum.KeyCode.ButtonL1 } } },
	},
	[6] = {
		Display = "6",
		PC = { { Main = Enum.KeyCode.Six } },
		Console = { { Main = Enum.KeyCode.ButtonY, Modifiers = { Enum.KeyCode.ButtonL1 } } },
	},
	[7] = {
		Display = "7",
		PC = { { Main = Enum.KeyCode.Seven } },
		Console = { { Main = Enum.KeyCode.ButtonB, Modifiers = { Enum.KeyCode.ButtonL1 } } },
	},
	[8] = {
		Display = "8",
		PC = { { Main = Enum.KeyCode.Eight } },
		Console = { { Main = Enum.KeyCode.ButtonA, Modifiers = { Enum.KeyCode.ButtonL1 } } },
	},
	[9] = {
		Display = "9",
		PC = { { Main = Enum.KeyCode.Nine } },
		Console = { { Main = Enum.KeyCode.ButtonX, Modifiers = { Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonL1 } } },
	},
	[10] = {
		Display = "0",
		PC = { { Main = Enum.KeyCode.Zero } },
		Console = { { Main = Enum.KeyCode.DPadDown, Modifiers = { Enum.KeyCode.ButtonR1 } } },
	},
}

Binds.HotbarSlots = HOTBAR_SLOTS

local GLOBAL: {
	Backpack: BindConfig,
} = {
	Backpack = {
		PC = { { Main = Enum.KeyCode.Tab }, { Main = Enum.KeyCode.B } },
		Console = { { Main = Enum.KeyCode.DPadLeft } },
	},
}

Binds.Global = GLOBAL

return Binds
