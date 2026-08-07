--!strict

--@author: yyumchi
--@date: 2026-07-07
--[[@description:
	Communications adapter for Stoway.
	Creates RemoteEvents and fires intent-based events to clients.
	Registers as an adapter with Stoway — Stoway does not import this module.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Protocol = require("@Stoway/Protocol")
local Types = require("@CoreStore/Types")

local Communications = {}

type StowayApi = {
	registerAdapter: (Protocol.Adapter) -> (),
}

local _Stoway: StowayApi? = nil
local RemoteFolder: Instance? = nil

local Remotes: { [string]: RemoteEvent } = {}

-----------------------------
-- CONSTANTS --
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function ensureRemote(name: string): RemoteEvent
	local existing = Remotes[name]
	if existing then
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = RemoteFolder
	Remotes[name] = remote
	return remote
end

local function fireToClient(player: Player, remoteName: string, ...: any)
	local remote = Remotes[remoteName]
	if remote then
		remote:FireClient(player, ...)
	end
end

local function adapter(player: Player, signal: Protocol.Signal)
	-- The tagged union's operation discriminant guards each branch, so the
	-- result cast is safe. (Luau cannot correlate signal.result with
	-- signal.operation across versions, hence the explicit cast.)

	if not signal.result.success then
		if signal.operation == "SwapSlots" then
			local result = signal.result :: Types.SwapResult
			-- The player already rendered the swap on their end; only talk back
			-- on failure, and send the inverse of the attempted operation.
			fireToClient(player, "InventoryRevert", {
				fromResult = result,
				fromSlot = result.reason,
			})
		end
		return
	end

	-- Client-initiated operations don't need a full echo: the client applied
	-- them locally and only needs a confirmation if something failed (above).
	if not signal.replicate then
		return
	end

	if signal.operation == "AddItem" or signal.operation == "AddToBackpack" or signal.operation == "AddToHotbar" then
		local result = signal.result :: Types.AddResult
		local addedItems = result.addedItems
		if addedItems then
			for _, added in addedItems do
				fireToClient(player, "InventoryAdded", {
					uuid = added.uuid,
					slotType = added.slotType,
					slot = added.slot,
				})
			end
		end

		local updatedItems = result.updatedItems
		if updatedItems then
			for uuid, newAmount in updatedItems do
				fireToClient(player, "InventoryUpdated", {
					uuid = uuid,
					newAmount = newAmount,
				})
			end
		end

	elseif signal.operation == "RemoveItem" then
		local result = signal.result :: Types.RemoveResult
		local removedItem = result.removedItem
		if removedItem then
			fireToClient(player, "InventoryRemoved", {
				uuid = removedItem.UUID,
				slotType = result.slotType,
				slot = result.slot,
			})
		end

	elseif signal.operation == "EquipSlot" then
		local result = signal.result :: Types.EquipResult
		fireToClient(player, "InventoryEquipped", {
			uuid = result.uuid,
		})

	elseif signal.operation == "UnequipSlot" then
		local result = signal.result :: Types.UnequipResult
		fireToClient(player, "InventoryUnequipped", {
			uuid = result.previousUUID,
		})
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Communications.Init(stowayModule: StowayApi, folder: Instance)
	_Stoway = stowayModule
	RemoteFolder = folder

	ensureRemote("InventoryAdded")
	ensureRemote("InventoryUpdated")
	ensureRemote("InventoryRemoved")
	ensureRemote("InventoryEquipped")
	ensureRemote("InventoryUnequipped")
	ensureRemote("InventoryRevert")

	stowayModule.registerAdapter(adapter)
end

-----------------------------
--MAIN--
-----------------------------

return Communications
