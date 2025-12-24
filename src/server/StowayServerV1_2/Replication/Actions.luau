-- src/server/StowayServerV1.2/Replication/Actions.luau
-- Defines action types and payload structures for delta replication

local Actions = {}

--// Action Types
Actions.Types = {
	INIT = "Init",           -- Full state sync (join/respawn)
	ADD = "Add",             -- Item added
	REMOVE = "Remove",       -- Item removed
	SWAP = "Swap",           -- Slots swapped
	EQUIP = "Equip",         -- Equipped item changed
	UPDATE_META = "UpdateMeta", -- Item metadata updated
	UPDATE_SETTINGS = "UpdateSettings", -- Settings updated
	RELOAD = "Reload",       -- Reload client interface/config
}

--// Payload Builders
function Actions.Init(state: any)
	return {
		Items = state.Items,
		Hotbar = state.Hotbar,
		Storage = state.Storage,
		EquippedUUID = state.EquippedItemUUID
	}
end

function Actions.UpdateSettings(settings: any)
	return settings
end

function Actions.Reload(uiType:string, data: any?)
	return {
		UiType = uiType,
		Data = data
	}
end

function Actions.Add(addedItems: { { uuid: string, slotType: string, slot: number } }, items: any)
	-- Build payload with full item data for each added slot
	local slots = {}
	for _, added in ipairs(addedItems) do
		table.insert(slots, {
			UUID = added.uuid,
			SlotType = added.slotType,
			Slot = added.slot,
			Item = items[added.uuid]
		})
	end
	return { Slots = slots }
end

function Actions.Remove(slotType: string, slot: number, uuid: string)
	return {
		UUID = uuid,
		SlotType = slotType,
		Slot = slot
	}
end

function Actions.Swap(fromType: string, fromSlot: number, toType: string, toSlot: number)
	return {
		From = { Type = fromType, Slot = fromSlot },
		To = { Type = toType, Slot = toSlot }
	}
end

function Actions.Equip(uuid: string?)
	return { UUID = uuid }
end

function Actions.UpdateMeta(uuid: string, updates: { [string]: any }, newWeight:number)
	return {
		UUID = uuid,
		Updates = updates,
		NewWeight = newWeight
	}
end

return Actions
