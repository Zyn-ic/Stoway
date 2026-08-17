local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Types.Result)

local Types = {}

export type HotbarType = "Static" | "Dynamic"
export type SortOrder = "None" | "Name" | "Rarity" | "ItemType"
export type SlotType = "Hotbar" | "Storage"
export type PlacementMode = "Auto" | "Hotbar" | "Backpack" | "Slot"

export type SlotRef = {
    Type: SlotType,
    Slot: number,
}

export type ItemMetadata = {
    Description: string?,
    Image: string?,
    IsGamepass: boolean?,
    Rarity: string?,
    Droppable: boolean?,
    Type: string?,

    [string]: any
}

export type Item = {
    UUID: string,
    Id: string,
    Amount: number,
    Metadata: ItemMetadata,
}

export type ItemInput = {
    Id: string?,
    Amount: number?,
    Metadata: ItemMetadata?,
}

export type Settings = {
    HotbarType: HotbarType,
    MaxHotbarSlots: number,

    Limit: number,
    CanStack: boolean,
    MaxStackSize: number,
    BackpackEnabled: boolean,

    Sorting: boolean,
    SortOrder: SortOrder,

    StackOnSwap: boolean,
    StackRequiredFields: { string },
    StackBlacklist: { boolean },

    DefaultDroppable: boolean,
}

export type SettingsOverrides = {
    HotbarType: HotbarType?,
    MaxHotbarSlots: number?,

    Limit: number?,
    CanStack: boolean?,
    MaxStackSize: number?,
    BackpackEnabled: boolean?,

    Sorting: boolean?,
    SortOrder: SortOrder?,

    StackOnSwap: boolean?,
    StackRequiredFields: { string }?,
    StackBlacklist: { boolean }?,

    DefaultDroppable: boolean?,
}

export type InventoryState = {
	-- O(1): UUID -> Item
	Items: { [string]: Item },

	-- O(1) to get all stack UUIDs for an item id
	-- ItemId -> array of UUIDs
	ItemsByID: { [string]: { string } },

	-- Slot -> UUID
	Hotbar: { string? },

	-- Array of UUIDs
	Storage: { string },

	-- O(1): UUID -> where this item currently lives
	LocationByUUID: { [string]: SlotRef },

	-- O(1): MetadataIndex[fieldName][fieldValue] -> array of UUIDs
	-- Indexed fields: Rarity, Type
	MetadataIndex: { [string]: { [string]: { string } } },

    EquippedItemUUID: string?,
    Weight: number,

    Settings: Settings,
}

export type AddOptions = {
    Placement: PlacementMode?,
    Slot: number?,
    SlotRef: SlotRef?,
}

export type AddedSlot = {
    uuid: string,
    slotType: SlotType,
    slot: number,
}

export type AddResult = Result.Result<{
    addedItems: { AddedSlot }?,
    updatedItems: { [string]: number }?,
    addedAmount: number?,
    overflow: number?,
}>

export type RemoveResult = Result.Result<{
    removedItem: Item?,
    remaining: number?,
    slotType: SlotType?,
    slot: number?,
}>

export type SwapResult = Result.Result<{
    hotbarCompacted: boolean?,
}>

export type MoveResult = Result.Result<{
    hotbarCompacted: boolean?,
}>

export type SplitResult = Result.Result<{
    sourceUUID: string?,
    newUUID: string?,
    sourceAmount: number?,
    newAmount: number?,
    newSlotType: SlotType?,
    newSlot: number?,
    hotbarCompacted: boolean?,
}>

export type MetadataUpdateResult = Result.Result<{
    updatedFields: { string }?,
}>

export type SortResult = Result.Result<{
    storageOrder: { string }?,
}>

export type EquipResult = Result.Result<{
    uuid: string?,
    previousUUID: string?,
}>

export type UnequipResult = Result.Result<{
    previousUUID: string?,
}>

export type DropResult = Result.Result<{
	removedItem: Item,
	remaining: number?,
	tool: Tool,
}>

return Types
