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

export type AddResult = {
    success: boolean,
    reason: string?,

    addedItems: { AddedSlot }?,
    updatedItems: { number }?,

    addedAmount: number?,
    overflow: number?,
}

export type RemoveResult = {
    success: boolean,
    reason: string?,

    removedItem: Item?,
    remaining: number?,

    slotType: SlotType?,
    slot: number?,
}

export type SwapResult = {
    success: boolean,
    reason: string?,
    hotbarCompacted: boolean?,
}

export type MoveResult = {
    success: boolean,
    reason: string?,
    hotbarCompacted: boolean?,
}

export type SplitResult = {
    success: boolean,
    reason: string?,
    sourceUUID: string?,
    newUUID: string?,
    sourceAmount: number?,
    newAmount: number?,
    newSlotType: SlotType?,
    newSlot: number?,
    hotbarCompacted: boolean?,
}

export type MetadataUpdateResult = {
    success: boolean,
    reason: string?,
    updatedFields: { string }?,
}

export type SortResult = {
    success: boolean,
    storageOrder: { string }?,
}

return Types
