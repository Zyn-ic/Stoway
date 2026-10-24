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
local CoreStoreTypes = require("@game/ReplicatedStorage/Shared/Stoway/CoreStore/Types")

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
export type ItemInput = CoreStoreTypes.ItemInput
export type AddOptions = SharedTypes.AddOptions
export type ItemMetadata = SharedTypes.ItemMetadata
export type MetadataValue = SharedTypes.MetadataValue
export type MetadataUpdates = SharedTypes.MetadataUpdates
export type CategoryDef = SharedTypes.CategoryDef
export type Settings = SharedTypes.Settings
export type EngineSettings = CoreStoreTypes.Settings
export type InventoryState = CoreStoreTypes.InventoryState

-----------------------------
-- CLIENT-LOCAL TYPES --
-----------------------------

-- Snapshot for pure queries.
export type ClientSnapshot = SharedTypes.InventoryState

export type FullSyncPayload = CoreStoreTypes.FullSyncPayload

export type ItemRecord = {
	index: number,
	uuid: string,
}

-- Studio skin hook modules are an intentionally dynamic boundary: they are
-- loaded from an Instance and validated at runtime by SkinLoader.
export type HookMap = { [string]: unknown }

-- Storage grouped by item type for display.
export type GroupedStorage = { [string]: { ItemRecord } }

-- Optional category-header chrome for code-built skins. Layouts apply
-- these values on top of their generic header; absent fields keep the
-- existing prefab/category look.
export type HeaderStyle = {
	BackgroundColor3: Color3?,
	BackgroundTransparency: number?,
	TextColor3: Color3?,
	TextSize: number?,
	FontFace: Font?,
	CornerRadius: UDim?,
	StrokeColor: Color3?,
	StrokeThickness: number?,
	StrokeLineJoin: Enum.LineJoinMode?,
	PaddingLeft: number?,
	PaddingRight: number?,
}

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
	-- Code-built skins opt into layout-owned responsive popup/toggle
	-- geometry. Prefab skins leave this nil and keep their authored
	-- positions untouched.
	ResponsiveUi: boolean?,
	-- Extra clearance above the popup for skin art that overhangs its
	-- top edge (Persona's title tag). Ignored unless ResponsiveUi is set.
	PopupTopOverhang: number?,
	-- Per-skin look data (optional): category key -> header background.
	-- A skin module sets this; views fall back to category colors.
	HeaderColors: { [string]: Color3 }?,
	-- Optional category-header chrome for code-built skins.
	HeaderStyle: HeaderStyle?,
	-- Per-skin layout data (optional): desktop hotbar X scale. Absent =
	-- the shared default; mobile taper is never overridden.
	DesktopHotbarXScale: number?,
	-- Skin hook table (Layer 2): the required HookFuncs module from the
	-- Studio skin folder, or nil when the skin declares none. Boundary-
	-- typed as a string map; the Studio module itself (self-contained
	-- --!strict) is the precise contract. Call sites invoke via
	-- ClientEvents.CallHook (spawn+pcall).
	Hooks: HookMap?,
}

-----------------------------
-- MAIN --
-----------------------------

return Types
