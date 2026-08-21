--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Reactive state mirror of the server InventoryState. Holds RootScope and
	top-level atoms. Pure lookups are in CoreStore/Query.luau.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.fusion)

local Types = require(script.Parent.Parent.CoreStore.Types)
local Query = require(script.Parent.Parent.CoreStore.Query)

local peek = Fusion.peek

local ClientStore = {}

-----------------------------
-- ROOT SCOPE + ATOMS --
-----------------------------

ClientStore.RootScope = Fusion.scoped(Fusion)

local Scope = ClientStore.RootScope

ClientStore.Items = Scope:Value({} :: { [string]: Types.Item })
ClientStore.Hotbar = Scope:Value({} :: { [number]: string? })
ClientStore.Storage = Scope:Value({} :: { string })
ClientStore.EquippedItemUUID = Scope:Value(nil :: string?)
ClientStore.Weight = Scope:Value(0)
ClientStore.Settings = Scope:Value(nil :: Types.Settings?)

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Populates atoms from a full snapshot.
function ClientStore.Init(snapshot: Types.InventoryState)
	ClientStore.Items:set(snapshot.Items)
	ClientStore.Hotbar:set(snapshot.Hotbar)
	ClientStore.Storage:set(snapshot.Storage)
	ClientStore.EquippedItemUUID:set(snapshot.EquippedItemUUID)
	ClientStore.Weight:set(snapshot.Weight)
	ClientStore.Settings:set(snapshot.Settings)
end

function ClientStore.GetSnapshot(): Types.InventoryState
	return {
		Items = peek(ClientStore.Items),
		Hotbar = peek(ClientStore.Hotbar),
		Storage = peek(ClientStore.Storage),
		EquippedItemUUID = peek(ClientStore.EquippedItemUUID),
		Weight = peek(ClientStore.Weight),
		Settings = peek(ClientStore.Settings) :: any,
	}
end

function ClientStore.GetSettings(): Types.Settings?
	return peek(ClientStore.Settings)
end

function ClientStore.GetItem(uuid: string?): Types.Item?
	return Query.getItem(peek(ClientStore.Items), uuid)
end

function ClientStore.GetSlotOf(uuid: string): (Types.SlotType?, number?)
	return Query.findSlotByUUID(peek(ClientStore.Hotbar), peek(ClientStore.Storage), uuid)
end

-----------------------------
-- MAIN --
-----------------------------

return ClientStore
