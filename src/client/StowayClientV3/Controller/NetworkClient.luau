--!strict

--@author: yyumchi
--@date: 2026-09-19
--[[@description:
	Client network layer (Phase 2, client-branch edition). Sends are one
	FireServer per Stoway operation using the registered request events
	in Shared StowayRemotes (silent no-ops with no server behind them).
	Listens are the five server pushes the Communications adapter fires
	(Added/Updated/Removed/Equipped/Unequipped), applied through
	ClientController's server-apply paths — never echoed back. Revert is
	log-only: its payload carries no actionable slot data (server-branch
	redesign). Called from ClientController's shared op bodies after
	res.ok; Connect() runs once at boot.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Stoway.StowayRemotes)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)

local NetworkClient = {}

-- Server-apply handlers, injected by init.luau (passing
-- ClientController.ApplyServer*). Injected — never required — so the
-- dependency stays one-directional (Controller -> NetworkClient) and
-- no require cycle exists.
-- Injection seam: fields are any because the two solvers disagree on
-- function subtyping here (concrete () returns vs generic pcall use).
-- The table is built once in init.luau from ClientController's apply
-- functions; pcall at every call site contains any failure.
export type ApplyHandlers = {
	Added: any,
	Updated: any,
	Removed: any,
	Equipped: any,
	Unequipped: any,
}

local _applies: ApplyHandlers? = nil

type Connection = { Disconnect: (any) -> () }

local _conns: { Connection } = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Serialization mismatches must never break local inventory.
local function fire(eventName: string, ...: any)
	local event = (Remotes :: any)[eventName]
	if event == nil then
		warn(`[NetworkClient] unknown request event '{eventName}'`)
		return
	end
	local args = table.pack(...)
	local ok, err = pcall(event.FireServer, event, table.unpack(args, 1, args.n))
	if not ok then
		warn(`[NetworkClient] FireServer '{eventName}' failed: {tostring(err)}`)
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function NetworkClient.SendAddItem(itemInput: CoreTypes.ItemInput, opts: CoreTypes.AddOptions?)
	fire("AddItem", itemInput, opts)
end

function NetworkClient.SendAddToBackpack(itemInput: CoreTypes.ItemInput, opts: CoreTypes.AddOptions?)
	fire("AddToBackpack", itemInput, opts)
end

function NetworkClient.SendAddToHotbar(itemInput: CoreTypes.ItemInput, preferredSlot: number?)
	fire("AddToHotbar", itemInput, preferredSlot)
end

function NetworkClient.SendRemoveItem(uuid: string, amount: number?)
	fire("RemoveItem", uuid, amount)
end

function NetworkClient.SendSwap(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	fire("SwapSlots", { Type = from.Type, Slot = from.Slot }, { Type = to.Type, Slot = to.Slot })
end

function NetworkClient.SendSwapStack(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	fire("SwapStack", { Type = from.Type, Slot = from.Slot }, { Type = to.Type, Slot = to.Slot })
end

function NetworkClient.SendMove(from: CoreTypes.SlotRef, to: CoreTypes.SlotRef)
	fire("Move", { Type = from.Type, Slot = from.Slot }, { Type = to.Type, Slot = to.Slot })
end

function NetworkClient.SendSplit(uuid: string, amount: number, dest: CoreTypes.SlotRef?)
	if dest then
		fire("Split", uuid, amount, { Type = dest.Type, Slot = dest.Slot })
	else
		fire("Split", uuid, amount)
	end
end

function NetworkClient.SendEquip(uuid: string)
	fire("EquipSlot", uuid)
end

function NetworkClient.SendUnequip()
	fire("UnequipSlot")
end

function NetworkClient.SendUpdateMetadata(uuid: string, updates: { [string]: any })
	fire("UpdateMetadata", uuid, updates)
end

function NetworkClient.SendSort()
	fire("Sort")
end

-- Server pushes -> injected apply handlers (pcall-guarded; a malformed
-- push warns, never breaks local inventory).
function NetworkClient.Connect(applies: ApplyHandlers)
	NetworkClient.Disconnect()
	_applies = applies
	table.insert(_conns, Remotes.InventoryAdded.OnClientEvent:Connect(function(payload: any)
		if not _applies then return end
		local ok, err = pcall(_applies.Added, payload.uuid, payload.item, payload.slotType, payload.slot)
		if not ok then
			warn(`[NetworkClient] ApplyServerAdded failed: {tostring(err)}`)
		end
	end))
	table.insert(_conns, Remotes.InventoryUpdated.OnClientEvent:Connect(function(payload: any)
		if not _applies then return end
		local ok, err = pcall(_applies.Updated, payload.uuid, payload.newAmount)
		if not ok then
			warn(`[NetworkClient] ApplyServerUpdated failed: {tostring(err)}`)
		end
	end))
	table.insert(_conns, Remotes.InventoryRemoved.OnClientEvent:Connect(function(payload: any)
		if not _applies then return end
		local ok, err = pcall(_applies.Removed, payload.uuid)
		if not ok then
			warn(`[NetworkClient] ApplyServerRemoved failed: {tostring(err)}`)
		end
	end))
	table.insert(_conns, Remotes.InventoryEquipped.OnClientEvent:Connect(function(payload: any)
		if not _applies then return end
		local ok, err = pcall(_applies.Equipped, payload.uuid)
		if not ok then
			warn(`[NetworkClient] ApplyServerEquipped failed: {tostring(err)}`)
		end
	end))
	table.insert(_conns, Remotes.InventoryUnequipped.OnClientEvent:Connect(function(_payload: any)
		if not _applies then return end
		local ok, err = pcall(_applies.Unequipped)
		if not ok then
			warn(`[NetworkClient] ApplyServerUnequipped failed: {tostring(err)}`)
		end
	end))
	table.insert(_conns, Remotes.InventoryRevert.OnClientEvent:Connect(function(payload: any)
		warn(`[NetworkClient] server revert (log-only): {tostring(payload.fromSlot)}`)
	end))
end

function NetworkClient.Disconnect()
	for _, conn in _conns do
		conn:Disconnect()
	end
	table.clear(_conns)
end

-----------------------------
-- MAIN --
-----------------------------

return NetworkClient
