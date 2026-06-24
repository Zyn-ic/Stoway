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

    [any]: any
}

export type Item = {
    UUID: string,
    Id: string,
    Amount: number,
    Metadata: ItemMetadata,
}

export type ItemInput = {
    Id: string?,
    ID: string?,
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

return Types