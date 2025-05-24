-- ReplicatedStorage/Shared/Types.lua
local Types = {}

Types.HotbarType = { Static = "Static", Dynamic = "Dynamic" }
Types.CarryingType = { Inventory = "Inventory", Backpack = "Backpack" }

export type ItemData = {
	ID: string,
	Description: string,
	Image: string,
	Amount: number, -- Current stack size of this specific tool instance/group
	MaxStack: number, -- Max stack allowed for this item type (could be from Settings or item-specific)
	IsGamepass: boolean,
	Rarity: string?,
	Droppable: boolean?,
	Type: string, -- e.g., "Weapon", "Potion", "Resource"
	-- No ToolRef here; the slot will hold the ToolRef and this ItemData as Properties
}

-- Represents the content of a single slot in Hotbar or Backpack_Data
export type SlotContents = {
	ToolRef: Tool, -- Direct reference to the Tool instance
	Properties: ItemData, -- Stoway's tracked properties for this tool
}

export type PlayerSchema = {
	Hotbar: { SlotContents? }, -- Array of optional SlotContents
	Backpack_Data: { SlotContents? }?, -- Our data array for backpack items (if CarryingType is Backpack)
	Inventory_Data: { SlotContents? }?, -- Our data array for inventory items (if CarryingType is Inventory)
	-- Note: For "Inventory" type, ToolRef might point to ServerStorage initially
}

return Types
