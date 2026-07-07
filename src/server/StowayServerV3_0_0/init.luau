--!strict

--@author: yyumchi
--@date: 2026-07-06
--[[@description:
	StowayServerV3_0_0 — orchestration layer.
	Connects CoreStore to Roblox-specific layers (Network, World, Client).
	Handles player lifecycle, operation routing, anti-exploit, result dispatching.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Stoway = {}

local Types = require("@CoreStore/Types")

-- Minimal contract for the injected CoreStore module.
type CoreStoreApi = {
	new: (Types.SettingsOverrides?) -> Types.InventoryState,
	add: (Types.InventoryState, Types.ItemInput, Types.AddOptions?) -> Types.AddResult,
	addToBackpack: (Types.InventoryState, Types.ItemInput, Types.AddOptions?) -> Types.AddResult,
	addToHotbar: (Types.InventoryState, Types.ItemInput, number?) -> Types.AddResult,
	remove: (Types.InventoryState, string, number?) -> Types.RemoveResult,
	swap: (Types.InventoryState, Types.SlotRef, Types.SlotRef) -> Types.SwapResult,
	move: (Types.InventoryState, Types.SlotRef, Types.SlotRef) -> Types.MoveResult,
	split: (Types.InventoryState, string, number, Types.SlotRef?) -> Types.SplitResult,
	equip: (Types.InventoryState, string) -> Types.EquipResult,
	unequip: (Types.InventoryState) -> Types.UnequipResult,
	updateMetadata: (Types.InventoryState, string, { [string]: any }) -> Types.MetadataUpdateResult,
	sort: (Types.InventoryState) -> Types.SortResult,
}

type Adapter = (Player, string, any) -> ()

local CoreStore: CoreStoreApi? = nil
local _store: { [Player]: Types.InventoryState } = {}
local _locks: { [Player]: number } = {}
local _adapters: { Adapter } = {}

-- CONSTANTS --
-----------------------------

local LOCK_TIMEOUT = 3

-- PRIVATE FUNCTIONS --
-----------------------------

local function lockPlayer(player: Player): boolean
	local existing = _locks[player]
	if existing then
		local elapsed = os.clock() - existing
		if elapsed < LOCK_TIMEOUT then
			return false
		end
	end
	_locks[player] = os.clock()
	return true
end

local function unlockPlayer(player: Player)
	_locks[player] = nil
end

local function dispatch(player: Player, operation: string, result: any)
	for _, adapter in _adapters do
		adapter(player, operation, result)
	end
end

-- fn receives the (non-nil) CoreStore so it never touches the nullable module field.
local function route(player: Player, operation: string, fn: (cs: CoreStoreApi) -> any): any
	if not lockPlayer(player) then
		return { success = false, reason = "OPERATION_IN_PROGRESS" }
	end

	assert(CoreStore, "CoreStore not initialized")
	local ok, result = pcall(fn, CoreStore)

	if not ok then
		unlockPlayer(player)
		return { success = false, reason = "OPERATION_FAILED", error = result }
	end

	dispatch(player, operation, result)
	unlockPlayer(player)
	return result
end

-- PUBLIC FUNCTIONS --
-----------------------------

function Stoway.Init(CS: CoreStoreApi)
	CoreStore = CS
end

-- Player lifecycle

function Stoway.createPlayer(player: Player, settingsOverrides: Types.SettingsOverrides?): Types.InventoryState
	local cs = CoreStore :: CoreStoreApi
	local state = cs.new(settingsOverrides)
	_store[player] = state
	return state
end

function Stoway.get(player: Player): Types.InventoryState?
	return _store[player]
end

function Stoway.removePlayer(player: Player): Types.InventoryState?
	unlockPlayer(player)
	local state = _store[player]
	_store[player] = nil
	return state
end

function Stoway.getAll(): { [Player]: Types.InventoryState }
	return _store
end

-- Adapter registration

function Stoway.registerAdapter(adapter: Adapter)
	table.insert(_adapters, adapter)
end

-- Operation routes

function Stoway.AddItem(player: Player, itemData: Types.ItemInput, options: Types.AddOptions?): Types.AddResult
	return route(player, "AddItem", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.add(state, itemData, options)
	end)
end

function Stoway.AddToBackpack(player: Player, itemData: Types.ItemInput, options: Types.AddOptions?): Types.AddResult
	return route(player, "AddToBackpack", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.addToBackpack(state, itemData, options)
	end)
end

function Stoway.AddToHotbar(player: Player, itemData: Types.ItemInput, slot: number?): Types.AddResult
	return route(player, "AddToHotbar", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.addToHotbar(state, itemData, slot)
	end)
end

function Stoway.RemoveItem(player: Player, uuid: string, amount: number?): Types.RemoveResult
	return route(player, "RemoveItem", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.remove(state, uuid, amount)
	end)
end

function Stoway.SwapSlots(player: Player, fromRef: Types.SlotRef, toRef: Types.SlotRef): Types.SwapResult
	return route(player, "SwapSlots", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.swap(state, fromRef, toRef)
	end)
end

function Stoway.Move(player: Player, fromRef: Types.SlotRef, toRef: Types.SlotRef): Types.MoveResult
	return route(player, "Move", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.move(state, fromRef, toRef)
	end)
end

function Stoway.Split(player: Player, uuid: string, amount: number, destination: Types.SlotRef?): Types.SplitResult
	return route(player, "Split", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.split(state, uuid, amount, destination)
	end)
end

function Stoway.EquipSlot(player: Player, uuid: string): Types.EquipResult
	return route(player, "EquipSlot", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.equip(state, uuid)
	end)
end

function Stoway.UnequipSlot(player: Player): Types.UnequipResult
	return route(player, "UnequipSlot", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.unequip(state)
	end)
end

function Stoway.UpdateMetadata(player: Player, uuid: string, updates: { [string]: any }): Types.MetadataUpdateResult
	return route(player, "UpdateMetadata", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.updateMetadata(state, uuid, updates)
	end)
end

function Stoway.Sort(player: Player): Types.SortResult
	return route(player, "Sort", function(cs: CoreStoreApi)
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return cs.sort(state)
	end)
end

-----------------------------
--MAIN--
-----------------------------

return Stoway
