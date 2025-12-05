-- ReplicatedStorage/Shared/Types.lua
local Types = {}

Types.HotbarType = { Static = "Static", Dynamic = "Dynamic" }
Types.CarryingType = { Inventory = "Inventory", Backpack = "Backpack" }
Types.SortingType = {Name = "Name", Rarity = "Rarity", ItemType = "ItemType", SearchBar = "SearchBar"}

export type ItemData = {
	ID: string,
	Description: string,
	Image: string,
	Amount: number, -- Current stack size of this specific tool instance/group
	IsGamepass: boolean,
	Rarity: string?,
	Droppable: boolean?,
	Type: string, -- e.g., "Weapon", "Potion", "Resource"
}

export type DragStateTable = {
	ID: number,
	SourceSlot: any,
	MouseOffset: Vector2
}

export type Settings = {
	HotbarSettings : {HotbarType:string, MaxSlots:number},
	BackpackSettings : {CarryingType:string, Limit:number, Sorting:boolean},
	CanStack:boolean,
	MaxStackCount:number,
	RarityCheck:boolean,
	Droppable:boolean
}

return Types
