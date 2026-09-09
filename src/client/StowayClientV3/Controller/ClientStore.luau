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

local ClientStore = {}

-----------------------------
-- ROOT SCOPE + ATOMS --
-----------------------------

ClientStore.RootScope = Fusion.scoped(Fusion) :: Fusion.Scope<typeof(Fusion)>

local Scope: Fusion.Scope<typeof(Fusion)> = ClientStore.RootScope

-- Typed wrappers hide Fusion's unannotated generics from the new solver.
-- Call sites stay strictly typed, single :: any lives inside wrapper.
local function peekValue(v: any): any
	return (Fusion.peek :: any)(v)
end

local function newValue<T>(init: T): Fusion.Value<T>
	return (Scope :: any):Value(init) :: Fusion.Value<T>
end

ClientStore.Items = newValue({} :: { [string]: Types.Item })
ClientStore.Hotbar = newValue({} :: { [number]: string? })
ClientStore.Storage = newValue({} :: { string })
ClientStore.EquippedItemUUID = newValue(nil :: string?)
ClientStore.Weight = newValue(0)
ClientStore.Settings = newValue(nil :: Types.Settings?)

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Populates atoms from a full snapshot. Clones tables so Fusion sees new refs
-- and future in-place mutations of snapshot don't alias the Value interior.
function ClientStore.Init(snapshot: Types.InventoryState)
	ClientStore.Items:set(table.clone(snapshot.Items))
	ClientStore.Hotbar:set(table.clone(snapshot.Hotbar))
	ClientStore.Storage:set(table.clone(snapshot.Storage))
	ClientStore.EquippedItemUUID:set(snapshot.EquippedItemUUID)
	ClientStore.Weight:set(snapshot.Weight)
	if typeof(snapshot.Settings) == "table" then
		ClientStore.Settings:set((table.clone :: any)(snapshot.Settings) :: Types.Settings)
	else
		ClientStore.Settings:set((snapshot.Settings :: any) :: Types.Settings?)
	end
end

function ClientStore.GetSnapshot(): Types.InventoryState
	local items: { [string]: Types.Item } = peekValue(ClientStore.Items)
	local hotbar: { [number]: string? } = peekValue(ClientStore.Hotbar)
	local storage: { string } = peekValue(ClientStore.Storage)
	local equipped: string? = peekValue(ClientStore.EquippedItemUUID)
	local weight: number = peekValue(ClientStore.Weight)
	local settingsRaw: Types.Settings? = peekValue(ClientStore.Settings)
	-- Snapshot expects Settings non-nil after Init (cold start falls back to nil-spoofed any)
	local settings: Types.Settings = settingsRaw :: any
	return {
		Items = items,
		Hotbar = hotbar,
		Storage = storage,
		EquippedItemUUID = equipped,
		Weight = weight,
		Settings = settings,
	}
end

function ClientStore.GetSettings(): Types.Settings?
	local settings: Types.Settings? = peekValue(ClientStore.Settings)
	return settings
end

function ClientStore.GetItem(uuid: string?): Types.Item?
	local items: { [string]: Types.Item } = peekValue(ClientStore.Items)
	return Query.getItem(items, uuid)
end

function ClientStore.GetSlotOf(uuid: string): (Types.SlotType?, number?)
	local hotbar: { [number]: string? } = peekValue(ClientStore.Hotbar)
	local storage: { string } = peekValue(ClientStore.Storage)
	return Query.findSlotByUUID(hotbar, storage, uuid)
end

-----------------------------
-- MAIN --
-----------------------------

return ClientStore
