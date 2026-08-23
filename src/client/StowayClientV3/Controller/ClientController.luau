--!strict

--@author: yyumchi
--@date: 2026-08-22
--[[@description:
	Mirrors master InventoryController: SignalPlus bus -> ClientStore atoms.
	Holds single InventoryState (from MockData or server snapshot) and delegates
	mutations to Shared CoreStore (pure). After each CoreStore op, clones
	atoms before set so Fusion sees new table refs and recomputes SlotView
	computeds atomically (image, stackcount, rarity, selecticon, layout).

	Master: src/client/StowayClientv1_2/Operations/InventoryController.luau
	        used peek+clone per container then set().
	This:   state: InventoryState -- mutated in-place by CoreStore
	        sync() clones shallow and sets all atoms back-to-back;
	        Hydrate's task.defer coalesces instance writes to one frame.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalPlus = require(ReplicatedStorage.Packages.SignalPlus)

local CoreStore = require(ReplicatedStorage.Shared.Stoway.CoreStore)
local ClientStore = require(script.Parent.ClientStore)
local CoreTypes = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)
local Signals = require(script.Parent.Parent.Signals)

local ClientController = {}

local _state: CoreTypes.InventoryState? = nil
local _connections: { SignalPlus.Connection } = {}
local _signals: typeof(Signals)? = nil

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function hydrateIfNeeded(state: any)
	if not state then return end
	if state.LocationByUUID ~= nil and state.ItemsByID ~= nil and state.MetadataIndex ~= nil then return end
	state.LocationByUUID = state.LocationByUUID or {}
	state.ItemsByID = state.ItemsByID or {}
	state.MetadataIndex = state.MetadataIndex or {}
	-- rebuild from current Items/Hotbar/Storage if empty
	if next(state.LocationByUUID) == nil and state.Hotbar and state.Storage then
		for slot, uuid in state.Hotbar :: any do
			if uuid then (state.LocationByUUID :: any)[uuid] = { Type = "Hotbar", Slot = slot } end
		end
		for idx, uuid in state.Storage :: any do
			(state.LocationByUUID :: any)[uuid] = { Type = "Storage", Slot = idx }
		end
	end
	if next(state.ItemsByID) == nil and state.Items then
		for uuid, it in state.Items :: any do
			local id = (it :: any).Id
			local bucket = (state.ItemsByID :: any)[id]
			if not bucket then bucket = {}; (state.ItemsByID :: any)[id] = bucket end
			table.insert(bucket, uuid)
		end
	end
	if next(state.MetadataIndex) == nil and state.Items then
		for uuid, it in state.Items :: any do
			for _, field in { "Rarity", "Type" } do
				local v = (it :: any).Metadata and (it :: any).Metadata[field]
				if v ~= nil then
					local sv = tostring(v)
					local ft = (state.MetadataIndex :: any)[field]
					if not ft then ft = {}; (state.MetadataIndex :: any)[field] = ft end
					local b = ft[sv]
					if not b then b = {}; ft[sv] = b end
					table.insert(b, uuid)
				end
			end
		end
	end
end

local function sync()
	if not _state then return end
	ClientStore.Items:set(table.clone(_state.Items))
	ClientStore.Hotbar:set(table.clone(_state.Hotbar))
	ClientStore.Storage:set(table.clone(_state.Storage))
	ClientStore.EquippedItemUUID:set(_state.EquippedItemUUID)
	ClientStore.Weight:set(_state.Weight)
	if typeof(_state.Settings) == "table" then
		ClientStore.Settings:set(table.clone(_state.Settings) :: any)
	else
		ClientStore.Settings:set(_state.Settings)
	end
end

local function bindSignals(signals: typeof(Signals))
	table.clear(_connections)
	_signals = signals

	table.insert(_connections, signals.Swap:Connect(function(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.swap, _state, from, to)
		if ok and res and res.ok then
			sync()
		elseif ok and res and not res.ok then
			warn("[ClientController] Swap rejected", res.error and res.error.message or tostring(res))
		elseif not ok then
			warn("[ClientController] Swap error", res)
		end
	end))

	table.insert(_connections, signals.SwapStack:Connect(function(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.swapStack, _state, from, to)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] SwapStack error", res) end
	end))

	table.insert(_connections, signals.Move:Connect(function(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.move, _state, from, to)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] Move error", res) end
	end))

	table.insert(_connections, signals.Remove:Connect(function(uuid: string, amount: number?)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.remove, _state, uuid, amount)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] Remove error", res) end
	end))

	table.insert(_connections, signals.Add:Connect(function(itemInput: CoreTypes.ItemInput, opts: CoreTypes.AddOptions?)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.add, _state, itemInput, opts)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] Add error", res) end
	end))

	table.insert(_connections, signals.Split:Connect(function(uuid: string, amount: number, dest: CoreTypes.SlotRef?)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.split, _state, uuid, amount, dest)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] Split error", res) end
	end))

	table.insert(_connections, signals.Equip:Connect(function(uuid: string)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.equip, _state, uuid)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] Equip error", res) end
	end))

	table.insert(_connections, signals.Unequip:Connect(function()
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.unequip, _state)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] Unequip error", res) end
	end))
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function ClientController.Init(signals: typeof(Signals), snapshot: CoreTypes.InventoryState?)
	if snapshot then
		local full: CoreTypes.InventoryState = snapshot
		_state = full
		hydrateIfNeeded(full)
		-- Boundary cast: full engine state carries server-only indexes
		-- (ItemsByID, LocationByUUID, MetadataIndex) beyond the client mirror shape.
		ClientStore.Init(full :: any)
		sync()
	else
		_state = ClientStore.GetSnapshot() :: any
		hydrateIfNeeded(_state)
	end
	bindSignals(signals)
end

function ClientController.Destroy()
	for _, conn in _connections do
		if conn and conn.Disconnect then conn:Disconnect() end
	end
	table.clear(_connections)
	_state = nil
	_signals = nil
end

function ClientController.GetState(): CoreTypes.InventoryState?
	return _state
end

function ClientController.Sync()
	sync()
end

-- Direct core API for Interactions (drag, input). No Signals, just add onto core.
function ClientController.Swap(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local res = CoreStore.swap(_state, from, to)
	if res.ok then sync() end
	return res
end

function ClientController.Move(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local res = CoreStore.move(_state, from, to)
	if res.ok then sync() end
	return res
end

function ClientController.Remove(uuid: string, amount: number?)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local res = CoreStore.remove(_state, uuid, amount)
	if res.ok then sync() end
	return res
end

function ClientController.Equip(uuid: string)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local res = CoreStore.equip(_state, uuid)
	if res.ok then sync() end
	return res
end

function ClientController.Unequip()
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local res = CoreStore.unequip(_state)
	if res.ok then sync() end
	return res
end

-----------------------------
-- MAIN --
-----------------------------

return ClientController
