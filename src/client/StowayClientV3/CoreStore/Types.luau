--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Client-local type aliases. Re-exports the canonical shared Stoway types
	(ReplicatedStorage.Shared.Stoway.Types) and adds the client-only shapes
	used to move data between CoreStore (pure) and Controller/Layouts
	(Fusion + Instances). No runtime logic — mirrors the server's
	CoreStore/Types.luau convention of pure type exports only.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedTypes = require(ReplicatedStorage.Shared.Stoway.Types)

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

-- Snapshot passed into pure CoreStore/Query.luau functions. Same shape as
-- InventoryState; named separately so Query.luau never has to know about
-- Fusion or the reactive Controller layer that produces it.
export type ClientSnapshot = SharedTypes.InventoryState

export type ItemRecord = {
	index: number,
	uuid: string,
}

-- Storage items bucketed by Metadata.Type ("Other" for untyped items).
-- Visual grouping only — this never mutates Storage's order or filters what
-- the server thinks is in Storage; it only decides what's currently hidden
-- behind a collapsed group header on screen.
export type GroupedStorage = { [string]: { ItemRecord } }

-- What a UiSkin hands back to a HotbarType layout engine after Load(). Every
-- field is optional because a skin is allowed to omit pieces a given layout
-- doesn't use (e.g. a future Carousel skin has no sectioned Backpack frame).
export type SkinHandle = {
	Gui: ScreenGui?,
	HotbarFrame: Frame?,
	BackpackFrame: Frame?,
	ScrollingFrame: ScrollingFrame?,
	WeightLabel: TextLabel?,
	SearchFilter: TextBox?,
	BackpackStuff: ImageButton?,
	SlotTemplate: Frame?,
}

-----------------------------
-- MAIN --
-----------------------------

return Types
