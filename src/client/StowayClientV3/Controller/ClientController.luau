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
local Result = require(ReplicatedStorage.Shared.Stoway.Result)
local ClientStore = require(script.Parent.ClientStore)
local CoreTypes = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)
local ClientTypes = require(script.Parent.Parent.CoreStore.Types)
local Signals = require(script.Parent.Parent.Signals)
local ClientEvents = require(script.Parent.ClientEvents)
local NetworkClient = require(script.Parent.NetworkClient)

local ClientController = {}

local _state: CoreTypes.InventoryState? = nil
local _connections: { SignalPlus.Connection } = {}
local _signals: typeof(Signals)? = nil
-- Skin hook table (Layer 2), set per mount by the layout. Nil = no hooks.
local _hooks: ClientTypes.HookMap? = nil

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function noState(): { ok: false, error: Result.Error }
	return Result.Err({
		kind = Result.ErrorKind.NotAvailable,
		message = "NO_STATE",
	})
end

local function hydrateIfNeeded(state: CoreTypes.InventoryState)
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
		for uuid, it in state.Items do
			local id = it.Id
			local bucket = state.ItemsByID[id]
			if not bucket then bucket = {}; state.ItemsByID[id] = bucket end
			table.insert(bucket, uuid)
		end
	end
	if next(state.MetadataIndex) == nil and state.Items then
		for uuid, it in state.Items do
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
	ClientStore.SetEngineSettings(_state.Settings)
end

-- Pre-op slot resolution for (slotType, index) payloads. Remove destroys
-- the LocationByUUID entry, so callers capture BEFORE mutating. Returns
-- the SlotRef itself so call sites pass ref.Type/ref.Slot (property
-- access narrows cleanly on both solvers).
local function lookupSlot(uuid: string): CoreTypes.SlotRef?
	if not _state or _state.LocationByUUID == nil then return nil end
	return _state.LocationByUUID[uuid]
end

local function unequipOp(): CoreTypes.UnequipResult
	if not _state then return noState() end
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

local function equipAndClearNew(uuid: string): CoreTypes.EquipResult
	if not _state then return noState() end
	local res = CoreStore.equip(_state, uuid)
	if res.ok then
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
local function swapOp(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef): CoreTypes.SwapResult
	if not _state then return noState() end
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

local function removeOp(uuid: string, amount: number?): CoreTypes.RemoveResult
	if not _state then return noState() end
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

local function addOp(itemInput: CoreTypes.ItemInput, opts: CoreTypes.AddOptions?): CoreTypes.AddResult
	if not _state then return noState() end
	hydrateIfNeeded(_state)
	local res = CoreStore.add(_state, itemInput, opts)
	if res.ok then
		sync()
		local value = res.value
		if value ~= nil then
			-- addedItems are AddedSlot tables {uuid, slotType, slot}:
			-- fire the server-reported destination directly.
			local firstAdded = value.addedItems ~= nil and value.addedItems[1] or nil
			if firstAdded ~= nil then
				ClientEvents.ItemAdded:Fire(firstAdded.slotType, firstAdded.slot)
				ClientEvents.CallHook(_hooks, "OnItemAdd", firstAdded.slotType, firstAdded.slot)
			else
				-- updatedItems is a {[uuid]: newAmount} dict (pure stack):
				-- resolve the touched slot for the payload.
				local stackedUUID: string? = nil
				if value.updatedItems ~= nil then
					for uuid in value.updatedItems do
						stackedUUID = uuid
						break
					end
				end
				if stackedUUID ~= nil then
					local ref = lookupSlot(stackedUUID)
					if ref ~= nil then
						ClientEvents.ItemAdded:Fire(ref.Type, ref.Slot)
						ClientEvents.CallHook(_hooks, "OnItemAdd", ref.Type, ref.Slot)
					end
				end
			end
		end
		NetworkClient.SendAddItem(itemInput, opts)
	end
	return res
end

-- Index one item into the O(1) lookup tables. Mirrors hydrateIfNeeded's
-- bucket rules (Rarity + Type, stringified).
local function indexItem(uuid: string, item: CoreTypes.Item)
	if not _state then return end
	local idBucket = _state.ItemsByID[item.Id]
	if not idBucket then
		idBucket = {}
		_state.ItemsByID[item.Id] = idBucket
	end
	table.insert(idBucket, uuid)
	if item.Metadata then
		for _, field in { "Rarity", "Type" } do
			local v = item.Metadata[field]
			if v ~= nil then
				local sv = tostring(v)
				local ft = _state.MetadataIndex[field]
				if not ft then
					ft = {}
					_state.MetadataIndex[field] = ft
				end
				local b = ft[sv]
				if not b then
					b = {}
					ft[sv] = b
				end
				table.insert(b, uuid)
			end
		end
	end
end

-- SERVER-APPLY PATHS. These mirror server-originated pushes (chat
-- commands today, request router tomorrow) into local state. They call
-- CoreStore directly and NEVER FireServer — the server already applied
-- them; echoing back would loop the moment listeners exist.
--
-- Ghost healing: a push can arrive for a slot whose occupant has no Items
-- entry (a removal that never landed — e.g. a dropped remote). That ghost
-- renders empty and weighs nothing, but blocks the slot forever if we
-- skip. evictGhost drops every reference to such a uuid so the
-- authoritative push can land. A conflict with a REAL item keeps the old
-- warn+skip: that means a genuine bug elsewhere, never destroy data.
local function evictGhost(uuid: string)
	if not _state then return end
	for slot, occupant in _state.Hotbar do
		if occupant == uuid then
			_state.Hotbar[slot] = nil
		end
	end
	local storage = _state.Storage
	for i = #storage, 1, -1 do
		if storage[i] == uuid then
			table.remove(storage, i)
		end
	end
	-- Packed storage shifted: re-derive storage locations.
	for idx, id in storage do
		local loc = _state.LocationByUUID[id]
		if loc ~= nil and loc.Type == "Storage" then
			loc.Slot = idx
		end
	end
	_state.LocationByUUID[uuid] = nil
	for _, bucket in _state.ItemsByID do
		for i = #bucket, 1, -1 do
			if bucket[i] == uuid then
				table.remove(bucket, i)
			end
		end
	end
	for _, field in _state.MetadataIndex do
		for _, bucket in field do
			for i = #bucket, 1, -1 do
				if bucket[i] == uuid then
					table.remove(bucket, i)
				end
			end
		end
	end
end

function ClientController.ApplyServerAdded(uuid: string, item: CoreTypes.Item, slotType: string?, slot: number?)
	if not _state then return end
	hydrateIfNeeded(_state)
	if _state.Items[uuid] ~= nil then
		warn(`[ClientController] server add for known uuid {uuid}, skipping`)
		return
	end
	if slotType ~= "Hotbar" and slotType ~= "Storage" then
		warn(`[ClientController] server add with bad slotType {tostring(slotType)}, skipping`)
		return
	end
	if typeof(slot) ~= "number" then
		warn(`[ClientController] server add with bad slot {tostring(slot)}, skipping`)
		return
	end
	if slotType == "Hotbar" then
		local occupant = _state.Hotbar[slot]
		if occupant ~= nil then
			if _state.Items[occupant] ~= nil then
				warn(`[ClientController] server add to occupied hotbar {tostring(slot)}, skipping`)
				return
			end
			warn(`[ClientController] healing ghost hotbar {tostring(slot)} (stale {occupant})`)
			evictGhost(occupant)
		end
		_state.Hotbar[slot] = uuid
	else
		local atSlot = math.clamp(slot, 1, #_state.Storage + 1)
		table.insert(_state.Storage, atSlot, uuid)
		slot = atSlot
	end
	_state.Items[uuid] = item
	_state.LocationByUUID[uuid] = { Type = slotType, Slot = slot }
	indexItem(uuid, item)
	_state.Weight += if typeof(item.Amount) == "number" then item.Amount else 0
	sync()
	ClientEvents.ItemAdded:Fire(slotType, slot)
	ClientEvents.CallHook(_hooks, "OnItemAdd", slotType, slot)
end

function ClientController.ApplyServerRemoved(uuid: string, amount: number?)
	if not _state then return end
	hydrateIfNeeded(_state)
	if _state.Items[uuid] == nil then
		warn(`[ClientController] server remove for unknown uuid {uuid}, skipping`)
		return
	end
	local ref = lookupSlot(uuid)
	local res = CoreStore.remove(_state, uuid, amount)
	if res.ok then
		sync()
		if ref ~= nil then
			ClientEvents.ItemRemoved:Fire(ref.Type, ref.Slot)
			ClientEvents.CallHook(_hooks, "OnItemRemove", ref.Type, ref.Slot)
		end
	else
		-- Loud: a removal the server performed but we could not mirror is
		-- exactly how ghost slots are born.
		warn("[ClientController] server remove failed locally", res.error and res.error.message or tostring(res))
	end
end

function ClientController.ApplyServerUpdated(uuid: string, newAmount: number)
	if not _state then return end
	hydrateIfNeeded(_state)
	local item = _state.Items[uuid]
	if item == nil then
		warn(`[ClientController] server update for unknown uuid {uuid}, skipping`)
		return
	end
	if typeof(newAmount) ~= "number" then return end
	_state.Weight += newAmount - item.Amount
	item.Amount = newAmount
	sync()
end

function ClientController.ApplyServerEquipped(uuid: string)
	if not _state then return end
	hydrateIfNeeded(_state)
	if _state.Items[uuid] == nil then
		warn(`[ClientController] server equip for unknown uuid {uuid}, skipping`)
		return
	end
	local res = CoreStore.equip(_state, uuid)
	if res.ok then
		sync()
		local ref = lookupSlot(uuid)
		if ref ~= nil then
			ClientEvents.Equipped:Fire(ref.Type, ref.Slot)
			ClientEvents.CallHook(_hooks, "OnEquip", ref.Type, ref.Slot)
		end
	end
end

-- Wholesale replace from a FullSync push. Indexes are rebuilt from the
-- slot tables; Settings stay local (not covered). Silent: no per-item events.
function ClientController.ApplyServerFullSync(payload: CoreTypes.FullSyncPayload)
	if not _state then return end
	local items = payload.Items
	local hotbar = payload.Hotbar
	local storage = payload.Storage
	if typeof(items) ~= "table" or typeof(hotbar) ~= "table" or typeof(storage) ~= "table" then
		warn("[ClientController] server fullsync with bad tables, skipping")
		return
	end
	_state.Items = items
	_state.Hotbar = {}
	for slot, uuid in hotbar do
		if typeof(slot) == "number" and typeof(uuid) == "string" then
			_state.Hotbar[slot] = uuid
		end
	end
	_state.Storage = {}
	for idx, uuid in storage do
		if typeof(idx) == "number" and typeof(uuid) == "string" then
			_state.Storage[idx] = uuid
		end
	end
	_state.EquippedItemUUID = payload.EquippedItemUUID
	if typeof(payload.Weight) == "number" then
		_state.Weight = payload.Weight
	end
	-- Settings snapshot (convergence backstop for sparse pushes): same
	-- patch applier as the live path, then the trailing sync() fans out.
	if typeof(payload.Settings) == "table" then
		ClientController.ApplyServerSettings(payload.Settings)
	end
	_state.LocationByUUID = {}
	_state.ItemsByID = {}
	_state.MetadataIndex = {}
	hydrateIfNeeded(_state)
	sync()
end

function ClientController.ApplyServerUnequipped()
	if not _state then return end
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
	end
end

-- Live settings patches (sparse per change, see SettingsChanged). Overlays
-- present fields onto _state first so later sync() calls re-apply them
-- instead of clobbering atoms with the boot snapshot, then syncs once
-- (single atomic atoms update via SetEngineSettings). Unknown keys are
-- ignored by construction. Engine fields only.
function ClientController.ApplyServerSettings(patch: { [string]: any })
	if not _state then return end
	local s = _state.Settings
	if patch.HotbarType ~= nil then s.HotbarType = patch.HotbarType end
	if patch.MaxHotbarSlots ~= nil then s.MaxHotbarSlots = patch.MaxHotbarSlots end
	if patch.Limit ~= nil then s.Limit = patch.Limit end
	if patch.CanStack ~= nil then s.CanStack = patch.CanStack end
	if patch.MaxStackSize ~= nil then s.MaxStackSize = patch.MaxStackSize end
	if patch.BackpackEnabled ~= nil then s.BackpackEnabled = patch.BackpackEnabled end
	if patch.Sorting ~= nil then s.Sorting = patch.Sorting end
	if patch.SortOrder ~= nil then s.SortOrder = patch.SortOrder end
	if patch.StackOnSwap ~= nil then s.StackOnSwap = patch.StackOnSwap end
	if patch.StackRequiredFields ~= nil then s.StackRequiredFields = table.clone(patch.StackRequiredFields) end
	if patch.StackBlacklist ~= nil then s.StackBlacklist = table.clone(patch.StackBlacklist) end
	if patch.DefaultDroppable ~= nil then s.DefaultDroppable = patch.DefaultDroppable end
	sync()
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
		ClientStore.Init(full)
		sync()
	else
		local state = ClientStore.GetSnapshot()
		_state = state
		hydrateIfNeeded(state)
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

function ClientController.SetHooks(hooks: ClientTypes.HookMap?)
	_hooks = hooks
end

-- Direct core API for Interactions (drag, input). No Signals, just add onto core.
function ClientController.Swap(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef): CoreTypes.SwapResult
	return swapOp(from, to)
end

function ClientController.Move(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef): CoreTypes.MoveResult
	if not _state then return noState() end
	hydrateIfNeeded(_state)
	local res = CoreStore.move(_state, from, to)
	if res.ok then
		sync()
		NetworkClient.SendMove(from, to)
	end
	return res
end

function ClientController.Remove(uuid: string, amount: number?): CoreTypes.RemoveResult
	return removeOp(uuid, amount)
end

-- Proper drop: send-only, no local apply. The server validates
-- (Droppable), spawns the world Tool, and pushes Removed — which is
-- what actually takes the item out of the UI. Pessimistic by design:
-- a rejected drop changes nothing locally.
function ClientController.RequestDrop(uuid: string, amount: number?)
	NetworkClient.SendDrop(uuid, amount)
end

function ClientController.Equip(uuid: string): CoreTypes.EquipResult
	if not _state then return noState() end
	hydrateIfNeeded(_state)
	return equipAndClearNew(uuid)
end

function ClientController.Unequip(): CoreTypes.UnequipResult
	return unequipOp()
end

-----------------------------
-- MAIN --
-----------------------------

return ClientController
