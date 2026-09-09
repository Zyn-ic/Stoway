--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Client type aliases and skin handle.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local SharedTypes = require("@game/ReplicatedStorage/Shared/Stoway/Types")

local Types = {}

-----------------------------
-- SHARED RE-EXPORTS --
-----------------------------

export type HotbarType = SharedTypes.HotbarType
export type SortOrder = SharedTypes.SortOrder
export type SlotType = SharedTypes.SlotType
export type PlacementMode = SharedTypes.PlacementMode
export type SlotRef = SharedTypes.SlotRef
export type Item = SharedTypes.Item
export type ItemMetadata = SharedTypes.ItemMetadata
export type CategoryDef = SharedTypes.CategoryDef
export type Settings = SharedTypes.Settings
export type InventoryState = SharedTypes.InventoryState

-----------------------------
-- CLIENT-LOCAL TYPES --
-----------------------------

-- Snapshot for pure queries.
export type ClientSnapshot = SharedTypes.InventoryState

export type ItemRecord = {
	index: number,
	uuid: string,
}

-- Storage grouped by item type for display.
export type GroupedStorage = { [string]: { ItemRecord } }

-- Handle returned by a skin loader.
export type SkinHandle = {
	Gui: ScreenGui?,
	HotbarFrame: Frame?,
	BackpackFrame: Frame?,
	ScrollingFrame: ScrollingFrame?,
	WeightLabel: TextLabel?,
	SearchFilter: TextBox?,
	BackpackStuff: ImageButton?,
	SlotTemplate: Frame?,
	DraggingGui: ScreenGui?,
	SelectionCursorTemplate: GuiObject?,
}

-----------------------------
-- MAIN --
-----------------------------

return Types
