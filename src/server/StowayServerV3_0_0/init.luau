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
local CoreStore = nil
local _store = {}
local _locks = {}
local _adapters = {}

-- CONSTANTS --
-----------------------------

local LOCK_TIMEOUT = 3

-- PRIVATE FUNCTIONS --
-----------------------------

local function lockPlayer(player: any): boolean
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

local function unlockPlayer(player: any)
	_locks[player] = nil
end

local function dispatch(player: any, operation: string, result: any)
	for _, adapter in _adapters do
		adapter(player, operation, result)
	end
end

local function route(player: any, operation: string, fn: () -> any): any
	if not lockPlayer(player) then
		return { success = false, reason = "OPERATION_IN_PROGRESS" }
	end

	local ok, result = pcall(fn)

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

function Stoway.Init(CS: any)
	CoreStore = CS
end

-- Player lifecycle

function Stoway.createPlayer(player: any, settingsOverrides: any?): any
	local state = CoreStore.new(settingsOverrides)
	_store[player] = state
	return state
end

function Stoway.get(player: any): any?
	return _store[player]
end

function Stoway.removePlayer(player: any): any?
	unlockPlayer(player)
	local state = _store[player]
	_store[player] = nil
	return state
end

function Stoway.getAll(): { [any]: any }
	return _store
end

-- Adapter registration

function Stoway.registerAdapter(adapter: (any, string, any) -> ())
	table.insert(_adapters, adapter)
end

-- Operation routes

function Stoway.AddItem(player: any, itemData: any, options: any?): any
	return route(player, "AddItem", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.add(state, itemData, options)
	end)
end

function Stoway.AddToBackpack(player: any, itemData: any, options: any?): any
	return route(player, "AddToBackpack", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.addToBackpack(state, itemData, options)
	end)
end

function Stoway.AddToHotbar(player: any, itemData: any, slot: number?): any
	return route(player, "AddToHotbar", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.addToHotbar(state, itemData, slot)
	end)
end

function Stoway.RemoveItem(player: any, uuid: string, amount: number?): any
	return route(player, "RemoveItem", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.remove(state, uuid, amount)
	end)
end

function Stoway.SwapSlots(player: any, fromRef: any, toRef: any): any
	return route(player, "SwapSlots", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.swap(state, fromRef, toRef)
	end)
end

function Stoway.Move(player: any, fromRef: any, toRef: any): any
	return route(player, "Move", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.move(state, fromRef, toRef)
	end)
end

function Stoway.Split(player: any, uuid: string, amount: number, destination: any?): any
	return route(player, "Split", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.split(state, uuid, amount, destination)
	end)
end

function Stoway.EquipSlot(player: any, uuid: string): any
	return route(player, "EquipSlot", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.equip(state, uuid)
	end)
end

function Stoway.UnequipSlot(player: any): any
	return route(player, "UnequipSlot", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.unequip(state)
	end)
end

function Stoway.UpdateMetadata(player: any, uuid: string, updates: { [string]: any }): any
	return route(player, "UpdateMetadata", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.updateMetadata(state, uuid, updates)
	end)
end

function Stoway.Sort(player: any): any
	return route(player, "Sort", function()
		local state = _store[player]
		if not state then return { success = false, reason = "NO_STATE" } end
		return CoreStore.sort(state)
	end)
end

-----------------------------
--MAIN--
-----------------------------

return Stoway
