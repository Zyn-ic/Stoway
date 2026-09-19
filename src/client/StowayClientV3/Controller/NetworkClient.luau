--!strict

--@author: yyumchi
--@date: 2026-09-19
--[[@description:
	Send-only client network layer (Phase 2, client-branch edition).
	One FireServer per Stoway operation, using the registered request
	events in Shared StowayRemotes. No listeners, no snapshot, no
	revert — with no server behind them, sends are silent no-ops and
	local state stands. The server branch listens on this same
	StowayRemotes module, so the wire stays in sync by construction.
	Called from ClientController's shared op bodies after res.ok.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Stoway.StowayRemotes)

local CoreTypes = require(script.Parent.Parent.CoreStore.Types)

local NetworkClient = {}

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

-----------------------------
-- MAIN --
-----------------------------

return NetworkClient
