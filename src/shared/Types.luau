local Types = {}
Types.test = "working"

Types.HotbarType = {
	Static = "Static",
	Dynamic = "Dynamic",
}

Types.CarryingType = {
	Inventory = "Inventory",
	Backpack = "Backpack",
}

export type ItemData = {
	ID: string, -- unique identifier
	Description: string,
	Image: string,
	Amount: number, -- supports stacks
	IsGamepass: boolean, -- optional, respawn logic
	Rarity: string?, -- optional, for rarity check
	Droppable: boolean, -- optional for protected slots
	Type: string,
}

export type PlayerSchema = {
	Hotbar: { ItemData }, -- { [1] = ItemData, [2] = ItemData, ... },
	Backpack: { ItemData }?, --{ [1] = ItemData, [2] = ItemData, ... }, -- optional
	Inventory: { ItemData }?, --{ [1] = ItemData, [2] = ItemData, ... }, -- optional
}

return Types
