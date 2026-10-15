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

local Types = require(game:GetService("ReplicatedStorage").Shared.Stoway.CoreStore.Types)

local Protocol = {}

-----------------------------
-- CONSTANTS --
-----------------------------

export type Operation = "AddItem" | "AddToBackpack" | "AddToHotbar" |
	"RemoveItem" | "SwapSlots" | "SwapStack" | "Move" | "Split" |
	"EquipSlot" | "UnequipSlot" | "UpdateMetadata" | "Sort" | "Drop"

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
	| { operation: "Drop", replicate: boolean, result: Types.DropResult }

export type Adapter = (player: Player, signal: Signal) -> ()

-- Single surface for the two hand-copied API shapes (previously
-- triplicated across init/Communications/ConchCommands and already
-- drifted once). Both use CoreStore nominals so the identities match
-- every consumer exactly.
export type CoreStoreApi = {
	new: (Types.SettingsOverrides?) -> Types.InventoryState,
	add: (Types.InventoryState, Types.ItemInput, Types.AddOptions?) -> Types.AddResult,
	addToBackpack: (Types.InventoryState, Types.ItemInput, Types.AddOptions?) -> Types.AddResult,
	addToHotbar: (Types.InventoryState, Types.ItemInput, number?) -> Types.AddResult,
	remove: (Types.InventoryState, string, number?) -> Types.RemoveResult,
	swap: (Types.InventoryState, Types.SlotRef, Types.SlotRef) -> Types.SwapResult,
	swapStack: (Types.InventoryState, Types.SlotRef, Types.SlotRef) -> Types.SwapResult,
	move: (Types.InventoryState, Types.SlotRef, Types.SlotRef) -> Types.MoveResult,
	split: (Types.InventoryState, string, number, Types.SlotRef?) -> Types.SplitResult,
	equip: (Types.InventoryState, string) -> Types.EquipResult,
	unequip: (Types.InventoryState) -> Types.UnequipResult,
	updateMetadata: (Types.InventoryState, string, { [string]: any }) -> Types.MetadataUpdateResult,
	sort: (Types.InventoryState) -> Types.SortResult,
}

export type StowayApi = {
	registerAdapter: (Adapter) -> (),
	get: (Player) -> Types.InventoryState?,
	createPlayer: (Player, Types.SettingsOverrides?) -> Types.InventoryState,
	removePlayer: (Player) -> Types.InventoryState?,
	AddItem: (Player, Types.ItemInput, Types.AddOptions?, boolean?) -> Types.AddResult,
	AddToBackpack: (Player, Types.ItemInput, Types.AddOptions?, boolean?) -> Types.AddResult,
	AddToHotbar: (Player, Types.ItemInput, number?, boolean?) -> Types.AddResult,
	RemoveItem: (Player, string, number?, boolean?) -> Types.RemoveResult,
	SwapSlots: (Player, Types.SlotRef, Types.SlotRef, boolean?) -> Types.SwapResult,
	SwapStack: (Player, Types.SlotRef, Types.SlotRef, boolean?) -> Types.SwapResult,
	Move: (Player, Types.SlotRef, Types.SlotRef, boolean?) -> Types.MoveResult,
	Split: (Player, string, number, Types.SlotRef?, boolean?) -> Types.SplitResult,
	EquipSlot: (Player, string, boolean?) -> Types.EquipResult,
	UnequipSlot: (Player, boolean?) -> Types.UnequipResult,
	UpdateMetadata: (Player, string, { [string]: any }, boolean?) -> Types.MetadataUpdateResult,
	Sort: (Player, boolean?) -> Types.SortResult,
	Drop: (Player, string, number?, boolean?) -> Types.DropResult,
}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
--MAIN--
-----------------------------

return Protocol
