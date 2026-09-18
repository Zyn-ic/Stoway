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
	GhostHidden: { string }?,
	HideInStorage: { string }?,
	HideInHotbar: { string }?,
	SlotBleedPx: number?,
	-- Per-skin look data (optional): category key -> header background.
	-- A skin module sets this; views fall back to category colors.
	HeaderColors: { [string]: Color3 }?,
	-- Per-skin layout data (optional): desktop hotbar X scale. Absent =
	-- the shared default; mobile taper is never overridden.
	DesktopHotbarXScale: number?,
	-- Per-skin glow tuning: UIShadow spread. Absent = shared default
	-- (0.05 scale on both axes). Metal uses a wider 0.5 spread.
	GlowSpread: UDim2?,
	-- Skin hook table (Layer 2): the required HookFuncs module from the
	-- Studio skin folder, or nil when the skin declares none. Boundary-
	-- typed as a string map; each skin's HookPayloads.luau is the precise
	-- contract. Call sites invoke via ClientEvents.CallHook (spawn+pcall).
	Hooks: { [string]: any }?,
}

-----------------------------
-- MAIN --
-----------------------------

return Types
