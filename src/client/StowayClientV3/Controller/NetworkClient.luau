--!strict

--@author: yyumchi
--@date: 2026-09-19
--[[@description:
	Client network layer. Sends are one direct FireServer per operation
	(single-table payloads per the wire convention). Listens are the
	server pushes (Added/Updated/Removed/Equipped/Unequipped/FullSync),
	applied through injected ClientController server-apply paths — never
	echoed back. Revert is log-only. Snapshot boot reads the last
	received FullSync. Connect() runs once at boot.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Stoway.StowayRemotes)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)
local SharedCoreTypes = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)

-- One any for the whole QuickNet seam, and why it earns its place:
-- QuickNet infers callback payloads and FireServer params from the
-- *schema tables* (schema nominals like AddedPayload/SlotRef), while
-- game code uses the *domain nominals* (CoreStore Item/SlotRef). Same
-- shapes, different identities — the new solver rejects the crossing.
-- Serialization genuinely erases types here, so a single any-binding
-- is honest. Everything past it (handlers, applies, state) stays typed.
local R: any = Remotes

local NetworkClient = {}

-- Server-apply handlers, injected by init.luau. Concrete signatures
-- matching ClientController.ApplyServer* exactly; injected (never
-- required) so the dependency stays one-directional.
export type ApplyHandlers = {
	Added: (uuid: string, item: SharedCoreTypes.Item, slotType: string?, slot: number?) -> (),
	Updated: (uuid: string, newAmount: number) -> (),
	Removed: (uuid: string, amount: number?) -> (),
	Equipped: (uuid: string) -> (),
	Unequipped: () -> (),
	FullSync: (payload: CoreTypes.FullSyncPayload) -> (),
	LayoutChanged: (hotbarTypeKey: string, skinKey: string) -> (),
	SettingsChanged: (patch: { [string]: any }) -> (),
}

local _applies: ApplyHandlers? = nil
local _lastFullSync: CoreTypes.FullSyncPayload? = nil

type Connection = { Disconnect: (self: Connection) -> () }

local _conns: { Connection } = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- One serialization guard for every send. Thunk keeps the call fully
-- typed at the call site; pcall takes a single target so any return
-- shape is fine on both solvers.
local function send(name: string, fn: () -> ())
	if not pcall(fn) then
		warn(`[NetworkClient] {name} send failed`)
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function NetworkClient.SendAddItem(itemInput: CoreTypes.ItemInput, opts: CoreTypes.AddOptions?)
	send("AddItem", function()
		R.AddItem:FireServer({ input = itemInput, options = opts })
	end)
end

function NetworkClient.SendAddToBackpack(itemInput: CoreTypes.ItemInput, opts: CoreTypes.AddOptions?)
	send("AddToBackpack", function()
		R.AddToBackpack:FireServer({ input = itemInput, options = opts })
	end)
end

function NetworkClient.SendAddToHotbar(itemInput: CoreTypes.ItemInput, preferredSlot: number?)
	send("AddToHotbar", function()
		R.AddToHotbar:FireServer({ input = itemInput, preferredSlot = preferredSlot })
	end)
end

function NetworkClient.SendRemoveItem(uuid: string, amount: number?)
	send("RemoveItem", function()
		R.RemoveItem:FireServer({ uuid = uuid, amount = amount })
	end)
end

function NetworkClient.SendSwap(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	send("SwapSlots", function()
		R.SwapSlots:FireServer({
			from = { Type = from.Type, Slot = from.Slot },
			to = { Type = to.Type, Slot = to.Slot },
		})
	end)
end

function NetworkClient.SendSwapStack(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	send("SwapStack", function()
		R.SwapStack:FireServer({
			from = { Type = from.Type, Slot = from.Slot },
			to = { Type = to.Type, Slot = to.Slot },
		})
	end)
end

function NetworkClient.SendMove(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	send("Move", function()
		R.Move:FireServer({
			from = { Type = from.Type, Slot = from.Slot },
			to = { Type = to.Type, Slot = to.Slot },
		})
	end)
end

function NetworkClient.SendSplit(uuid: string, amount: number, dest: CoreTypes.SlotRef?)
	send("Split", function()
		if dest then
			R.Split:FireServer({ uuid = uuid, amount = amount, dest = { Type = dest.Type, Slot = dest.Slot } })
		else
			R.Split:FireServer({ uuid = uuid, amount = amount })
		end
	end)
end

function NetworkClient.SendEquip(uuid: string)
	send("EquipSlot", function()
		R.EquipSlot:FireServer({ uuid = uuid })
	end)
end

function NetworkClient.SendUnequip()
	send("UnequipSlot", function()
		R.UnequipSlot:FireServer()
	end)
end

function NetworkClient.SendUpdateMetadata(uuid: string, updates: CoreTypes.MetadataUpdates)
	send("UpdateMetadata", function()
		R.UpdateMetadata:FireServer({ uuid = uuid, updates = updates })
	end)
end


function NetworkClient.SendSort()
	send("Sort", function()
		R.Sort:FireServer()
	end)
end

function NetworkClient.SendDrop(uuid: string, amount: number?)
	send("Drop", function()
		R.Drop:FireServer({ uuid = uuid, amount = amount })
	end)
end

function NetworkClient.RequestSnapshot()
	send("RequestInventorySync", function()
		R.RequestInventorySync:FireServer()
	end)
end

-- Server pushes -> injected apply handlers. A malformed push warns,
-- never breaks local inventory.
function NetworkClient.Connect(applies: ApplyHandlers)
	NetworkClient.Disconnect()
	_applies = applies
	_conns[#_conns + 1] = R.InventoryAdded.OnClientEvent:Connect(function(payload)
		if not _applies then return end
		if not pcall(_applies.Added, payload.uuid, payload.item, payload.slotType, payload.slot) then
			warn("[NetworkClient] ApplyServerAdded failed")
		end
	end)
	_conns[#_conns + 1] = R.InventoryUpdated.OnClientEvent:Connect(function(payload)
		if not _applies then return end
		if not pcall(_applies.Updated, payload.uuid, payload.newAmount) then
			warn("[NetworkClient] ApplyServerUpdated failed")
		end
	end)
	_conns[#_conns + 1] = R.InventoryRemoved.OnClientEvent:Connect(function(payload)
		if not _applies then return end
		-- pcall threads the handler's arity: pass the optional amount
		-- explicitly or the new solver rejects the call.
		if not pcall(_applies.Removed, payload.uuid, nil) then
			warn("[NetworkClient] ApplyServerRemoved failed")
		end
	end)
	_conns[#_conns + 1] = R.InventoryEquipped.OnClientEvent:Connect(function(payload)
		if not _applies then return end
		-- uuid is schema-optional (shared with Unequipped's shape).
		if typeof(payload.uuid) ~= "string" then
			warn("[NetworkClient] Equipped push without uuid, skipping")
			return
		end
		if not pcall(_applies.Equipped, payload.uuid) then
			warn("[NetworkClient] ApplyServerEquipped failed")
		end
	end)
	_conns[#_conns + 1] = R.InventoryUnequipped.OnClientEvent:Connect(function()
		if not _applies then return end
		if not pcall(_applies.Unequipped) then
			warn("[NetworkClient] ApplyServerUnequipped failed")
		end
	end)
	_conns[#_conns + 1] = R.InventoryRevert.OnClientEvent:Connect(function(payload)
		warn(`[NetworkClient] server revert (log-only): {tostring(payload.fromSlot)}`)
		-- Log-only by design: the server's handle() already pushes a
		-- FullSync behind every failed op, so requesting another snapshot
		-- here would triple-send (revert + handle push + requested push).
	end)
	_conns[#_conns + 1] = R.InventoryFullSync.OnClientEvent:Connect(function(payload: CoreTypes.FullSyncPayload)
		_lastFullSync = payload
		if not _applies then return end
		if not pcall(_applies.FullSync, payload) then
			warn("[NetworkClient] ApplyServerFullSync failed")
		end
	end)
	_conns[#_conns + 1] = R.LayoutChanged.OnClientEvent:Connect(function(payload)
		if not _applies then return end
		if typeof(payload.layout) ~= "string" or typeof(payload.skin) ~= "string" then
			warn("[NetworkClient] invalid layout change payload")
			return
		end
		if not pcall(_applies.LayoutChanged, payload.layout, payload.skin) then
			warn("[NetworkClient] ApplyServerLayoutChanged failed")
		end
	end)
	_conns[#_conns + 1] = R.SettingsChanged.OnClientEvent:Connect(function(payload)
		if not _applies then return end
		if typeof(payload) ~= "table" then
			warn("[NetworkClient] invalid settings payload")
			return
		end
		if not pcall(_applies.SettingsChanged, payload) then
			warn("[NetworkClient] ApplyServerSettingsChanged failed")
		end
	end)
end

function NetworkClient.GetLastFullSync(): CoreTypes.FullSyncPayload?
	return _lastFullSync
end

function NetworkClient.Disconnect()
	_applies = nil
	for _, conn in _conns do
		conn:Disconnect()
	end
	table.clear(_conns)
end

-----------------------------
-- MAIN --
-----------------------------

return NetworkClient
