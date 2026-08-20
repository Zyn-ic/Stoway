--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Fusion root state (Layer 1 of the client: reactive mirror of the server
	InventoryState). Holds the RootScope and every top-level atom. Lookup
	logic itself lives in CoreStore/Query.luau (pure); this module wires
	Fusion around those pure functions and exposes peek-based getters for
	one-shot reads (network handlers, debug prints, etc).

	RootScope is never cleaned up for the lifetime of the client session —
	only LayoutScope (see Controller/LayoutManager.luau) gets torn down and
	recreated when the active HotbarType/UiSkin changes.
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

-- Seeds every atom from a full snapshot (mock data today; the real
-- NetworkReceiver's initial replication payload once Phase 1 networking
-- lands — this is a one-line swap in init.luau, not a rewrite here).
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
