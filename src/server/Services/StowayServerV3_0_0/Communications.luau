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
local Remotes = require(ReplicatedStorage.Shared.Stoway.StowayRemotes)

local Protocol = require(script.Parent.Protocol)

local _Types = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)

local Communications = {}

type StowayApi = {
	registerAdapter: (Protocol.Adapter) -> (),
	get: (Player) -> _Types.InventoryState?,
}

local _Stoway: StowayApi? = nil

-- PRIVATE FUNCTIONS --
-----------------------------

local function adapter(player: Player, signal: Protocol.Signal)
	-- The tagged union's operation discriminant guards each branch, so the
	-- result cast is safe. (Luau cannot correlate signal.result with
	-- signal.operation across versions, hence the explicit cast.)

	local res = signal.result
	if not res.ok then
		if signal.operation == "SwapSlots" or signal.operation == "SwapStack" then
			-- The player already rendered the swap on their end; only talk back
			-- on failure, and send the inverse of the attempted operation.
			--
			Remotes.InventoryRevert:FireClient(player, {
				success = false,
				fromSlot = res.error.message,
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
		local result = (signal.result :: any).value
		local addedItems = result.addedItems
		if addedItems then
			local state = if _Stoway then _Stoway.get(player) else nil
			for _, added in addedItems do
				-- Full item: the client inserts verbatim (server UUID wins).
				local item = state and state.Items[added.uuid]
				if not item then
					warn(`[Communications] added item {added.uuid} missing from state, skipping push`)
				else
					Remotes.InventoryAdded:FireClient(player, {
						uuid = added.uuid,
						slotType = added.slotType,
						slot = added.slot,
						item = {
							UUID = item.UUID,
							Id = item.Id,
							Amount = item.Amount,
							Metadata = item.Metadata,
						},
					})
				end
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
		local result = (signal.result :: any).value
		local removedItem = result.removedItem
		if removedItem then
			Remotes.InventoryRemoved:FireClient(player, {
				uuid = removedItem.UUID,
				slotType = result.slotType,
				slot = result.slot,
			})
		end

	elseif signal.operation == "EquipSlot" then
		local result = (signal.result :: any).value
		Remotes.InventoryEquipped:FireClient(player, {
			uuid = result.uuid,
			previousUUID = result.previousUUID,
		})

	elseif signal.operation == "UnequipSlot" then
		local result = (signal.result :: any).value
		Remotes.InventoryUnequipped:FireClient(player, {
			uuid = result.previousUUID,
		})

	elseif signal.operation == "Drop" then
		local result = (signal.result :: any).value
		if result.removedItem then
			Remotes.InventoryRemoved:FireClient(player, {
				uuid = result.removedItem.UUID,
				slotType = nil,
				slot = nil,
			})
		end

	elseif signal.operation == "SwapSlots"
		or signal.operation == "SwapStack"
		or signal.operation == "Move"
		or signal.operation == "Split"
		or signal.operation == "UpdateMetadata"
		or signal.operation == "Sort" then
		-- No targeted push exists for these: send full state. res.ok is
		-- guaranteed here (failures returned early above). Client replaces
		-- wholesale and rebuilds indexes; IsNew glow flags do not survive
		-- (server never sets them).
		local state = if _Stoway then _Stoway.get(player) else nil
		if state then
			-- Project to the wire shape (drops engine-only extras).
			local items: { [string]: any } = {}
			for uuid, it in state.Items do
				items[uuid] = {
					UUID = it.UUID,
					Id = it.Id,
					Amount = it.Amount,
					Metadata = it.Metadata,
				}
			end
			local hotbar: { [number]: string } = {}
			for slot, uuid in state.Hotbar do
				if uuid then hotbar[slot] = uuid end
			end
			local storage: { [number]: string } = {}
			for idx, uuid in state.Storage do
				storage[idx] = uuid
			end
			Remotes.InventoryFullSync:FireClient(player, {
				Items = items,
				Hotbar = hotbar,
				Storage = storage,
				EquippedItemUUID = state.EquippedItemUUID,
				Weight = state.Weight,
			})
		end
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
