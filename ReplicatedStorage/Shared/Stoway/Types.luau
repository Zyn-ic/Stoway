--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Shared Stoway data types (pure type exports, no runtime logic).
	Client-side mirror of the CoreStore InventoryState — server-only indexes
	(ItemsByID, LocationByUUID, MetadataIndex) are omitted here.
]]
-----------------------------
-- VARIABLES --
-----------------------------

export type HotbarType = "Static" | "Dynamic"
export type SortOrder = "None" | "Name" | "Rarity" | "ItemType"
export type SlotType = "Hotbar" | "Storage"
export type PlacementMode = "Auto" | "Hotbar" | "Backpack" | "Slot"

export type SlotRef = {
	Type: SlotType,
	Slot: number,
}

export type MetadataValue = string | number | boolean

export type ItemMetadata = {
	Description: string?,
	Image: string?,
	IsGamepass: boolean?,
	Rarity: string?,
	Droppable: boolean?,
	Type: string?,
	[string]: MetadataValue?,
}

export type MetadataUpdates = { [string]: MetadataValue? }

export type Item = {
	UUID: string,
	Id: string,
	Amount: number,
	Metadata: ItemMetadata,
}

export type CategoryDef = {
	DisplayName: string,
	Color: Color3,
	Order: number,
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
	StackBlacklist: { [string]: boolean },
	DefaultDroppable: boolean,
	DebugLogs: boolean,
	UiSkin: string,
	-- HotbarType layout engine key (LayoutManager.Layouts). Boot mounts
	-- this; runtime switches arrive via the LayoutChanged event.
	Layout: string,
	Categories: { [string]: CategoryDef },
	-- Client/UI-only demo toggle: when true, Storage renders as collapsible
	-- groups by Metadata.Type (StorageView); when false, Storage renders as
	-- a single flat, ungrouped list straight into the backpack
	-- ScrollingFrame. For now this is a runtime-toggleable setting so the
	-- grouped view is just one example of settings-driven sort/filter —
	-- later a given Layout/Skin may bake this in rather than exposing it.
	GroupByCategory: boolean,
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
	StackBlacklist: { [string]: boolean }?,
	DefaultDroppable: boolean?,
	DebugLogs: boolean?,
	UiSkin: string?,
	Layout: string?,
	Categories: { [string]: CategoryDef }?,
	GroupByCategory: boolean?,
}

export type InventoryState = {
	Items: { [string]: Item },
	Hotbar: { [number]: string? },
	Storage: { string },
	EquippedItemUUID: string?,
	Weight: number,
	Settings: Settings,
}

export type AddOptions = {
	Placement: PlacementMode?,
	Slot: number?,
	SlotRef: SlotRef?,
}

return {}
