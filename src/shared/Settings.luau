-- src/server/StowayServerV1.2/Config/Settings.luau
-- Configuration for the Inventory System V1.2

local Settings = {}

--// Types
export type HotbarType = "Static" | "Dynamic"

--// Hotbar Settings
Settings.Hotbar = {
	Type = "Static" :: HotbarType, -- Static: fixed slots with holes, Dynamic: packed array
	MaxSlots = 10,
}

--// Storage/Backpack Settings (Always Dynamic)
Settings.Storage = {
	Limit = 15,             -- Total weight limit (Hotbar + Storage combined)
	CanStack = true,
	Sorting = true,
	MaxStackSize = 5,
	SortOrder = "None" -- Name, Rarity, ItemType, None
}

--// Stacking Rules
Settings.Stacking = {
	-- Fields that MUST match for items to stack
	RequiredFields = { "Rarity", "Type" },
	-- Rarities that can NEVER stack
	Blacklist = {
		["Legendary"] = true,
		["Mythic"] = true,
		["Special"] = true,
	},

	Rarity = true
}

--// Gameplay Settings
Settings.Gameplay = {
	Droppable = true,
	DropDistance = 10,
}

Settings.DifferentUIs = {
	Default = {
		FolderName = "StowayGui",
		GuiName = "Stoway",
		HookPresetName = "DefaultHooks"
	}
}

return Settings
