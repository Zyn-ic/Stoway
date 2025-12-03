-- src/server/StowayServerV1/Config/Settings.luau
local Settings = {}

--// Types
export type HotbarType = "Static" | "Dynamic"
export type CarryingType = "Inventory" | "Backpack"

--// Hotbar Settings
Settings.Hotbar = {
	Type = "Static" :: HotbarType, -- Static: fixed slots, Dynamic: grows with items
	MaxSlots = 9,
}

--// Backpack/Storage Settings
Settings.Storage = {
	Type = "Backpack" :: CarryingType, -- Inventory: Data-only storage, Backpack: Roblox Backpack (Not used in this V1 rework logic, but kept for config)
	Limit = 15, -- Total slots including hotbar
	CanStack = true,
	MaxStackSize = 5,
}

--// Gameplay Settings
Settings.Gameplay = {
	Droppable = true,
	DropDistance = 10,
	RarityCheck = true, -- If true, prevents stacking different rarities
}

return Settings
