--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	StowayClientV3 Fusion root state. Reactive atoms mirror the server
	InventoryState; views derive from these via scoped Computeds.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)
local SharedTypes = require(ReplicatedStorage.Shared.Stoway.Types)

local Scope = Fusion.scoped(Fusion)

local Store = {
	Scope = Scope,

	-- Reactive atoms
	Items = Scope:Value({} :: { [string]: SharedTypes.Item }),
	Hotbar = Scope:Value({} :: { [number]: string? }),
	Storage = Scope:Value({} :: { string }),
	EquippedItemUUID = Scope:Value(nil :: string?),
	Weight = Scope:Value(0),
	Settings = Scope:Value(nil :: SharedTypes.Settings?),
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Store.Init(initialData: SharedTypes.InventoryState)
	Store.Items:set(initialData.Items)
	Store.Hotbar:set(initialData.Hotbar)
	Store.Storage:set(initialData.Storage)
	Store.EquippedItemUUID:set(initialData.EquippedItemUUID)
	Store.Weight:set(initialData.Weight)
	Store.Settings:set(initialData.Settings)
end

function Store.GetState(): SharedTypes.InventoryState
	return {
		Items = Fusion.peek(Store.Items),
		Hotbar = Fusion.peek(Store.Hotbar),
		Storage = Fusion.peek(Store.Storage),
		EquippedItemUUID = Fusion.peek(Store.EquippedItemUUID),
		Weight = Fusion.peek(Store.Weight),
		Settings = Fusion.peek(Store.Settings),
	}
end

function Store.GetSettings(): SharedTypes.Settings?
	return Fusion.peek(Store.Settings)
end

function Store.GetItem(uuid: string): SharedTypes.Item?
	return Fusion.peek(Store.Items)[uuid]
end

function Store.GetUuidAt(slotType: SharedTypes.SlotType, index: number): string?
	if slotType == "Hotbar" then
		return Fusion.peek(Store.Hotbar)[index]
	end
	return Fusion.peek(Store.Storage)[index]
end

function Store.GetSlotOf(uuid: string): (SharedTypes.SlotType?, number?)
	local hotbar = Fusion.peek(Store.Hotbar)
	for slot, hotbarUuid in hotbar do
		if hotbarUuid == uuid then
			return "Hotbar", slot
		end
	end
	local storage = Fusion.peek(Store.Storage)
	for index, storageUuid in storage do
		if storageUuid == uuid then
			return "Storage", index
		end
	end
	return nil, nil
end

-----------------------------
-- MAIN --
-----------------------------

return Store