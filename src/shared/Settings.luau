-- src/server/StowayServerV1.2/Config/Settings.luau
-- Configuration for the Inventory System V1.2

local Settings = {}

--// Types
export type HotbarType = "Static" | "Dynamic"

--// Hotbar Settings
Settings.Hotbar = {
	Type = "Static" :: HotbarType, -- Static: fixed slots with holes, Dynamic: packed array (perplayer setting)
	MaxSlots = 10, -- (perplayer setting)
}

--// Storage/Backpack Settings (Always Dynamic)
Settings.Storage = {
	Limit = 15,             -- Total weight limit (Hotbar + Storage combined) (perplayer setting)
	CanStack = true, -- (perplayer setting)
	Sorting = true, -- (global setting)
	MaxStackSize = 5, -- (perplayer setting)
	BackpackEnabled = true, -- (global setting)
	SortOrder = "None" -- Name, Rarity, ItemType, None (global setting)
}

--// Stacking Rules
Settings.Stacking = {
	-- Fields that MUST match for items to stack
	RequiredFields = { "Rarity", "Type" }, -- (global setting)
	-- Rarities that can NEVER stack
	Blacklist = { -- (global setting)
		["Legendary"] = true,
		["Mythic"] = true,
		["Special"] = true,
	},

	Rarity = true -- (global setting)
}

--// Gameplay Settings
Settings.Gameplay = { -- (global settings)
	Droppable = true,
	DropDistance = 10,
	MouseScroll = true,
}

Settings.DifferentUIs = {
	Default = {
		FolderName = "StowayGui",
		GuiName = "Stoway",
		HookPresetName = "DefaultHooks"
	},

	Admin = {
		FolderName = "StowayAdmin",
		GuiName = "AdminGui",
		HookPresetName = "AdminHooks"
	},

	Grass = {
        FolderName = "StowayGrass",
    	GuiName = "GrassUi",
    	HookPresetName = "GrassHooks"
	},

	Metal = {
        FolderName = "StowayMetal",
    	GuiName = "MetalGUI",
    	HookPresetName = "MetalHooks"
	}
}

return Settings
