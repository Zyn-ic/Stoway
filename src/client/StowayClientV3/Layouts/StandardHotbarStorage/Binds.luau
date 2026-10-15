--!strict

--@author: yyumchi
--@date: 2026-09-09
--[[@description:
	Per-layout bind table for StandardHotbarStorage. Layout-owned so
	switching layouts can teardown/rebuild cleanly. Sparse-tolerant:
	missing index (e.g. [13] nil, [14] present, MaxHotbarSlots 14)
	means that slot simply gets no PC nor Console bind.

	No DropActions Increase/Decrease — tap-to-equip covers it. PC and
	Console are separate arrays; Input mounts only the side matching
	PreferredInput (or both for Shared contexts like Backpack).
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

-- Hotbar 1..10 defaults. Custom skins/layouts can add [11]..[N] entries;
-- Input loops 1..MaxHotbarSlots and skips nils.

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
	-- SPARSE TEST: [9] has Display but no keys. Slot 9 must render + drag +
	-- tap, show a red "!" badge, and fire no PC/Console bind.
	[9] = {
		Display = "9",
		-- PC = { { Main = Enum.KeyCode.Nine } },
		-- Console = { { Main = Enum.KeyCode.DPadUp, Modifiers = { Enum.KeyCode.ButtonR1 } } },
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
	SwitchMode: BindConfig,
	InventoryActions: {
		Swap: BindConfig,
		Drop: BindConfig,
		QuickMove: BindConfig,
		Cancel: BindConfig,
	},
} = {
	Backpack = {
		PC = { { Main = Enum.KeyCode.Tab }, { Main = Enum.KeyCode.B } },
		Console = { { Main = Enum.KeyCode.DPadLeft } },
	},
	SwitchMode = {
		PC = { { Main = Enum.KeyCode.M } },
		Console = { { Main = Enum.KeyCode.ButtonL3 } },
	},
	InventoryActions = {
		Swap = {
			Console = { { Main = Enum.KeyCode.ButtonY } },
		},
		Drop = {
			Console = { { Main = Enum.KeyCode.ButtonX } },
		},
		QuickMove = {
			Console = { { Main = Enum.KeyCode.ButtonL1, Modifiers = { Enum.KeyCode.ButtonR1 } } },
		},
		Cancel = {
			Console = { { Main = Enum.KeyCode.ButtonB } },
		},
	},
}

Binds.Global = GLOBAL

return Binds
