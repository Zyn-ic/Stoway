--!strict

--@author: yyumchi
--@date: 2026-07-07
--[[@description:
	Communications adapter for Stoway.
	Uses QuickNet for server -> client event firing with typed data schemas.
	Registers as an adapter with Stoway — Stoway does not import this module.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.StowayRemotes)

local Protocol = require("./Protocol")
local Types = require("./CoreStore/Types")

local Communications = {}

type StowayApi = {
	registerAdapter: (Protocol.Adapter) -> (),
}

local _Stoway: StowayApi? = nil

-- PRIVATE FUNCTIONS --
-----------------------------

local function adapter(player: Player, signal: Protocol.Signal)
	-- The tagged union's operation discriminant guards each branch, so the
	-- result cast is safe. (Luau cannot correlate signal.result with
	-- signal.operation across versions, hence the explicit cast.)

	if not signal.result.success then
		if signal.operation == "SwapSlots" or signal.operation == "SwapStack" then
			local result = signal.result :: Types.SwapResult
			-- The player already rendered the swap on their end; only talk back
			-- on failure, and send the inverse of the attempted operation.
			--
			Remotes.InventoryRevert:FireClient(player, {
				success = result.success,
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
				Remotes.InventoryAdded:FireClient(player, {
					uuid = added.uuid,
					slotType = added.slotType,
					slot = added.slot,
				})
			end
		end

		local updatedItems = result.updatedItems
		if updatedItems then
			for uuid, newAmount in updatedItems do
				Remotes.InventoryUpdated:FireClient(player, {
					uuid = uuid,
					newAmount = newAmount,
				})
			end
		end

	elseif signal.operation == "RemoveItem" then
		local result = signal.result :: Types.RemoveResult
		local removedItem = result.removedItem
		if removedItem then
			Remotes.InventoryRemoved:FireClient(player, {
				uuid = removedItem.UUID,
				slotType = result.slotType,
				slot = result.slot,
			})
		end

	elseif signal.operation == "EquipSlot" then
		local result = signal.result :: Types.EquipResult
		Remotes.InventoryEquipped:FireClient(player, {
			uuid = result.uuid,
			previousUUID = result.previousUUID,
		})

	elseif signal.operation == "UnequipSlot" then
		local result = signal.result :: Types.UnequipResult
		Remotes.InventoryUnequipped:FireClient(player, {
			uuid = result.previousUUID,
		})
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Communications.Init(stowayModule: StowayApi)
	_Stoway = stowayModule

	stowayModule.registerAdapter(adapter)
end

function Communications.Start()

end

-----------------------------
--MAIN--
-----------------------------

return Communications
