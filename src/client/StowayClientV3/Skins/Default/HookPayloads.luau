--!strict

--@author: yyumchi
--@date: 2026-09-18
--[[@description:
	Default skin hook-function contract (Layer 2). Describes exactly what
	the Studio DefaultHooks module receives at each call site. Frozen
	2026-09-18 against game.ReplicatedStorage.Stoway.GUI.Default.HookFuncs.
	Change protocol: HookPayloads type -> hook function -> fire site(s).
]]
-----------------------------
-- VARIABLES --
-----------------------------

local CoreTypes = require(script.Parent.Parent.Parent.CoreStore.Types)

local HookPayloads = {}

-----------------------------
-- TYPES --
-----------------------------

-- Skin-direct hook table. Every field optional: a skin implements only
-- what it needs; absent entries are skipped silently. Passed frames
-- and buttons are borrowed, not owned: never destroy, reparent, or
-- permanently restyle them (OnSelect's highlight MUST be removed by
-- OnDeselect).
export type HookFuncs = {
	-- Tap/click landed (post drag-guard). uuid nil on empty slots.
	OnSlotClick: ((slotType: CoreTypes.SlotType, index: number, uuid: string?) -> ())?,
	-- Hover began. btn is the live slotbutton; it carries a UIStroke
	-- child per the skin contract (pcall guards skins without one).
	-- Handler yields (task.wait tween) — call sites task.spawn this.
	OnSlotHover: ((btn: GuiButton, slotType: CoreTypes.SlotType, slotIndex: number) -> ())?,
	-- Drag threshold crossed, ghost created.
	OnDragStart: ((slotType: CoreTypes.SlotType, index: number) -> ())?,
	-- Drag released, before commit.
	OnDragEnd: ((slotType: CoreTypes.SlotType, index: number) -> ())?,
	-- Equip/unequip succeeded (res.ok only).
	OnEquip: ((slotType: CoreTypes.SlotType, index: number) -> ())?,
	OnUnequip: ((slotType: CoreTypes.SlotType, index: number) -> ())?,
	-- Add/remove succeeded (res.ok only).
	OnItemAdd: ((slotType: CoreTypes.SlotType, index: number) -> ())?,
	OnItemRemove: ((slotType: CoreTypes.SlotType, index: number) -> ())?,
	-- Swap succeeded (res.ok only). Reports the DESTINATION slot;
	-- both ends changed, the destination is what the user aimed at.
	OnSwap: ((slotType: CoreTypes.SlotType, index: number) -> ())?,
	-- Equip-state observed per slot (any source: click, bind, server).
	-- frame is the live slot cell; OnSelect parents a "SelectionHighlight"
	-- UIStroke to it, OnDeselect destroys it.
	OnSelect: ((frame: Frame, slotType: CoreTypes.SlotType, slotIndex: number) -> ())?,
	OnDeselect: ((frame: Frame, slotType: CoreTypes.SlotType, slotIndex: number) -> ())?,
}

-- The 11 hook names, in fire order. SkinLoader validates the required
-- Studio module against this list (unknown entries warn, non-functions warn).
local HookPayloadsList: { string } = {
	"OnSlotClick",
	"OnDragStart",
	"OnSlotHover",
	"OnDragEnd",
	"OnEquip",
	"OnUnequip",
	"OnItemAdd",
	"OnItemRemove",
	"OnSwap",
	"OnSelect",
	"OnDeselect",
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function HookPayloads.GetHookNames(): { string }
	return HookPayloadsList
end

-----------------------------
-- MAIN --
-----------------------------

return HookPayloads
