--@author: yyumchi
--@date: 2026-08-07
--[[@description:
	Shared dispatch protocol between Stoway orchestration and registered adapters.
	Defines the typed Signal envelope (tagged union by operation) that both
	init.luau (producer) and Communications.luau (consumer) reference.
	No player field — the adapter receives the player as a separate argument.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("./CoreStore/Types")

local Protocol = {}

-----------------------------
-- CONSTANTS --
-----------------------------

export type Operation = "AddItem" | "AddToBackpack" | "AddToHotbar" |
	"RemoveItem" | "SwapSlots" | "SwapStack" | "Move" | "Split" |
	"EquipSlot" | "UnequipSlot" | "UpdateMetadata" | "Sort"

export type Signal =
	| { operation: "AddItem", replicate: boolean, result: Types.AddResult }
	| { operation: "AddToBackpack", replicate: boolean, result: Types.AddResult }
	| { operation: "AddToHotbar", replicate: boolean, result: Types.AddResult }
	| { operation: "RemoveItem", replicate: boolean, result: Types.RemoveResult }
	| { operation: "SwapSlots", replicate: boolean, result: Types.SwapResult }
	| { operation: "SwapStack", replicate: boolean, result: Types.SwapResult }
	| { operation: "Move", replicate: boolean, result: Types.MoveResult }
	| { operation: "Split", replicate: boolean, result: Types.SplitResult }
	| { operation: "EquipSlot", replicate: boolean, result: Types.EquipResult }
	| { operation: "UnequipSlot", replicate: boolean, result: Types.UnequipResult }
	| { operation: "UpdateMetadata", replicate: boolean, result: Types.MetadataUpdateResult }
	| { operation: "Sort", replicate: boolean, result: Types.SortResult }

export type Adapter = (player: Player, signal: Signal) -> ()

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
--MAIN--
-----------------------------

return Protocol
