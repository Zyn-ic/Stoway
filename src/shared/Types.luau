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
	-- No ToolRef here; the slot will hold the ToolRef and this ItemData as Properties
}

export type DragStateTable = {
	ID: number,
	SourceSlot: any,
	MouseOffset: Vector2
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

export type Settings = {
	HotbarSettings : {HotbarType:string, MaxSlots:number},
	BackpackSettings : {CarryingType:string, Limit:number, Sorting:boolean},
	CanStack:boolean,
	MaxStackCount:number,
	RarityCheck:boolean,
	Droppable:boolean
}

export type Stoway = {
	PrivateJanitor: any,
	Settings: Settings,

    InventoryFolder : Folder,
    HotBarFolder :Folder,
    BackpackFolder : Folder
}

export type API = {
	GetSettings: (Player)->(Settings),
	GetStoway: (Player)->(Stoway),
	SendStowayorSettings: (Player, string)->(Stoway | Settings | nil),
	Init: (Context)->();
}

export type Actions = {
	CreateHotbarValues : (Stoway)->(),
	Clear: (Stoway)->(),
	ShiftBackpackValuesDown: (ObjectValue, Player)->(),
	AddNewBackpackValue: (Tool, Player)->(),
	FindSuitableHotbarSlot: (Tool, Player)->(),
	UpdatePlayerTools: (Player)->(),
	SwapSlots: (Player, ObjectValue, ObjectValue, boolean)->(),
	MoveToEndofBackpack: (ObjectValue, Player)->(),
	Init: (Context)->();
}

export type Remotes = {
	OnAskForStoway: (Player, string)->(),
	OnUnEquip: (Player)->(),
	OnEquipTool: (Player, Tool)->(),
	OnDropTool: (Player, Tool)->(),
	Init: (Context)->();
}

export type Utils = {
	canAcceptWeight: (Stoway, number)->(),
	FindEmptySlot: ({ObjectValue}, number)->(),
	FindSameSlotType: ({ObjectValue}, Tool)->(),
	ValidateTool: (Player, Tool)->(),
	ValidateSlot: (ObjectValue, Stoway)->(),
	getTools: (Folder, Model)->(),
	FindValueFromTool: (Tool, Player)->(),
	Init: (Context)->();
}

export type Context = {
    PlayerStoways: {[Player]: Stoway},
	Janitor: any?,
    Settings : Settings,
    -- Pass the modules themselves so they can call each other's functions
    API: API,
    Actions: Actions,
    --Events: ModuleScript,
    Utils: Utils,
    Remotes: Remotes
}

return Types
