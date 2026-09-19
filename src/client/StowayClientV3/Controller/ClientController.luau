--!strict

--@author: yyumchi
--@date: 2026-08-22
--[[@description:
	SignalPlus bus -> ClientStore atoms. Holds the single InventoryState
	(from MockData or server snapshot) and delegates mutations to Shared
	CoreStore (pure). sync() clones shallow and sets all atoms back-to-back
	so Hydrate's task.defer coalesces instance writes to one frame.
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
local ClientEvents = require(script.Parent.ClientEvents)
local NetworkClient = require(script.Parent.NetworkClient)

local ClientController = {}

local _state: CoreTypes.InventoryState? = nil
local _connections: { SignalPlus.Connection } = {}
local _signals: typeof(Signals)? = nil
-- Skin hook table (Layer 2), set per mount by the layout. Nil = no hooks.
local _hooks: { [string]: any }? = nil

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
		for slot, uuid in state.Hotbar do
			if uuid then state.LocationByUUID[uuid] = { Type = "Hotbar", Slot = slot } end
		end
		for idx, uuid in state.Storage do
			state.LocationByUUID[uuid] = { Type = "Storage", Slot = idx }
		end
	end
	if next(state.ItemsByID) == nil and state.Items then
		for uuid, it in state.Items :: any do
			local id = it.Id
			local bucket = state.ItemsByID[id]
			if not bucket then bucket = {}; state.ItemsByID[id] = bucket end
			table.insert(bucket, uuid)
		end
	end
	if next(state.MetadataIndex) == nil and state.Items then
		for uuid, it in state.Items :: any do
			for _, field in { "Rarity", "Type" } do
				local v = it.Metadata and it.Metadata[field]
				if v ~= nil then
					local sv = tostring(v)
					local ft = state.MetadataIndex[field]
					if not ft then ft = {}; state.MetadataIndex[field] = ft end
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

-- Pre-op slot resolution for (slotType, index) payloads. Remove destroys
-- the LocationByUUID entry, so callers capture BEFORE mutating. Returns
-- the SlotRef itself so call sites pass ref.Type/ref.Slot (property
-- access narrows cleanly on both solvers).
local function lookupSlot(uuid: string): CoreTypes.SlotRef?
	if not _state or _state.LocationByUUID == nil then return nil end
	return _state.LocationByUUID[uuid]
end

local function equipAndClearNew(uuid: string)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	local res = CoreStore.equip(_state, uuid)
	if res.ok then
		-- Glow off: delete the IsNew flag. Presence renders, absence hides.
		CoreStore.updateMetadata(_state, uuid, { IsNew = CoreStore.METADATA_DELETE })
		sync()
		-- Equip never moves the item: post-op lookup is valid.
		local ref = lookupSlot(uuid)
		if ref ~= nil then
			ClientEvents.Equipped:Fire(ref.Type, ref.Slot)
			ClientEvents.CallHook(_hooks, "OnEquip", ref.Type, ref.Slot)
		end
		NetworkClient.SendEquip(uuid)
	end
	return res
end

-- Shared op bodies: signal handlers AND direct APIs route through these
-- so each success fires exactly one bus event + one skin hook (res.ok only).
local function swapOp(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local res = CoreStore.swap(_state, from, to)
	if res.ok then
		sync()
		ClientEvents.Swapped:Fire(from.Type, from.Slot, to.Type, to.Slot)
		ClientEvents.CallHook(_hooks, "OnSwap", to.Type, to.Slot)
		NetworkClient.SendSwap(from, to)
	end
	return res
end

local function removeOp(uuid: string, amount: number?)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local ref = lookupSlot(uuid)
	local res = CoreStore.remove(_state, uuid, amount)
	if res.ok then
		sync()
		if ref ~= nil then
			ClientEvents.ItemRemoved:Fire(ref.Type, ref.Slot)
			ClientEvents.CallHook(_hooks, "OnItemRemove", ref.Type, ref.Slot)
		end
		NetworkClient.SendRemoveItem(uuid, amount)
	end
	return res
end

local function addOp(itemInput: CoreTypes.ItemInput, opts: CoreTypes.AddOptions?)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local res = CoreStore.add(_state, itemInput, opts)
	if res.ok then
		sync()
		local value = (res :: any).value
		local uuid: string? = nil
		if value ~= nil then
			if value.addedItems ~= nil and #value.addedItems > 0 then
				uuid = value.addedItems[1]
			elseif value.updatedItems ~= nil and #value.updatedItems > 0 then
				uuid = value.updatedItems[1]
			end
		end
		if uuid ~= nil then
			local ref = lookupSlot(uuid)
			if ref ~= nil then
				ClientEvents.ItemAdded:Fire(ref.Type, ref.Slot)
				ClientEvents.CallHook(_hooks, "OnItemAdd", ref.Type, ref.Slot)
			end
		end
		NetworkClient.SendAddItem(itemInput, opts)
	end
	return res
end

local function unequipOp()
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local equipped: string? = _state.EquippedItemUUID
	local ref: CoreTypes.SlotRef? = nil
	if equipped then
		ref = lookupSlot(equipped)
	end
	local res = CoreStore.unequip(_state)
	if res.ok then
		sync()
		if ref ~= nil then
			ClientEvents.Unequipped:Fire(ref.Type, ref.Slot)
			ClientEvents.CallHook(_hooks, "OnUnequip", ref.Type, ref.Slot)
		end
		NetworkClient.SendUnequip()
	end
	return res
end

local function bindSignals(signals: typeof(Signals))
	table.clear(_connections)
	_signals = signals

	table.insert(_connections, signals.Swap:Connect(function(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(swapOp, from, to)
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
		if ok and res and res.ok then
			sync()
			NetworkClient.SendSwapStack(from, to)
		elseif not ok then warn("[ClientController] SwapStack error", res) end
	end))

	table.insert(_connections, signals.Move:Connect(function(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.move, _state, from, to)
		if ok and res and res.ok then
			sync()
			NetworkClient.SendMove(from, to)
		elseif not ok then warn("[ClientController] Move error", res) end
	end))

	table.insert(_connections, signals.Remove:Connect(function(uuid: string, amount: number?)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(removeOp, uuid, amount)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] Remove error", res) end
	end))

	table.insert(_connections, signals.Add:Connect(function(itemInput: CoreTypes.ItemInput, opts: CoreTypes.AddOptions?)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(addOp, itemInput, opts)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] Add error", res) end
	end))

	table.insert(_connections, signals.Split:Connect(function(uuid: string, amount: number, dest: CoreTypes.SlotRef?)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.split, _state, uuid, amount, dest)
		if ok and res and res.ok then
			sync()
			NetworkClient.SendSplit(uuid, amount, dest)
		elseif not ok then warn("[ClientController] Split error", res) end
	end))

	table.insert(_connections, signals.Equip:Connect(function(uuid: string)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(equipAndClearNew, uuid)
		if ok and res and res.ok then
			-- equipAndClearNew already synced
		elseif ok and res and not res.ok then
			warn("[ClientController] Equip rejected", res.error and res.error.message or tostring(res))
		elseif not ok then
			warn("[ClientController] Equip error", res)
		end
	end))

	table.insert(_connections, signals.Unequip:Connect(function()
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(unequipOp)
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] Unequip error", res) end
	end))

	table.insert(_connections, signals.MarkNew:Connect(function(uuid: string)
		if not _state then return end
		hydrateIfNeeded(_state)
		local ok, res = pcall(CoreStore.updateMetadata, _state, uuid, { IsNew = true })
		if ok and res and res.ok then sync() elseif not ok then warn("[ClientController] MarkNew error", res) end
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
	_hooks = nil
end

function ClientController.GetState(): CoreTypes.InventoryState?
	return _state
end

function ClientController.Sync()
	sync()
end

function ClientController.SetHooks(hooks: { [string]: any }?)
	_hooks = hooks
end

-- Direct core API for Interactions (drag, input). No Signals, just add onto core.
function ClientController.Swap(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	return swapOp(from, to)
end

function ClientController.Move(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	local res = CoreStore.move(_state, from, to)
	if res.ok then
		sync()
		NetworkClient.SendMove(from, to)
	end
	return res
end

function ClientController.Remove(uuid: string, amount: number?)
	return removeOp(uuid, amount)
end

function ClientController.Equip(uuid: string)
	if not _state then return { ok = false, error = { message = "NO_STATE" } } :: any end
	hydrateIfNeeded(_state)
	return equipAndClearNew(uuid)
end

function ClientController.Unequip()
	return unequipOp()
end

-----------------------------
-- MAIN --
-----------------------------

return ClientController
