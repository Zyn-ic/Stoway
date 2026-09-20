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
local Settings = require(ReplicatedStorage.Shared.Stoway.Settings)

local ClientStore = {}

-----------------------------
-- ROOT SCOPE + ATOMS --
-----------------------------

ClientStore.RootScope = Fusion.scoped(Fusion)

local Scope: Fusion.Scope<typeof(Fusion)> = ClientStore.RootScope

local initialItems: { [string]: Types.Item } = {}
local initialHotbar: { [number]: string? } = {}
local initialStorage: { string } = {}
local initialEquippedItemUUID: string? = nil
local initialSettings: Types.Settings? = nil

ClientStore.Items = Scope:Value(initialItems)
ClientStore.Hotbar = Scope:Value(initialHotbar)
ClientStore.Storage = Scope:Value(initialStorage)
ClientStore.EquippedItemUUID = Scope:Value(initialEquippedItemUUID)
ClientStore.Weight = Scope:Value(0)
ClientStore.Settings = Scope:Value(initialSettings)

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
	ClientStore.SetEngineSettings(snapshot.Settings)
end

function ClientStore.SetEngineSettings(settings: Types.EngineSettings)
	local clientSettings = Settings.getDefault()
	clientSettings.HotbarType = settings.HotbarType
	clientSettings.MaxHotbarSlots = settings.MaxHotbarSlots
	clientSettings.Limit = settings.Limit
	clientSettings.CanStack = settings.CanStack
	clientSettings.MaxStackSize = settings.MaxStackSize
	clientSettings.BackpackEnabled = settings.BackpackEnabled
	clientSettings.Sorting = settings.Sorting
	clientSettings.SortOrder = settings.SortOrder
	clientSettings.StackOnSwap = settings.StackOnSwap
	clientSettings.StackRequiredFields = table.clone(settings.StackRequiredFields)
	clientSettings.StackBlacklist = table.clone(settings.StackBlacklist)
	clientSettings.DefaultDroppable = settings.DefaultDroppable
	ClientStore.Settings:set(clientSettings)
end

function ClientStore.GetSnapshot(): Types.InventoryState
	local items: { [string]: Types.Item } = Fusion.peek(ClientStore.Items)
	local hotbar: { [number]: string? } = Fusion.peek(ClientStore.Hotbar)
	local storage: { string } = Fusion.peek(ClientStore.Storage)
	local equipped: string? = Fusion.peek(ClientStore.EquippedItemUUID)
	local weight: number = Fusion.peek(ClientStore.Weight)
	local settings: Types.Settings = Fusion.peek(ClientStore.Settings) or Settings.getDefault()
	return {
		Items = items,
		ItemsByID = {},
		Hotbar = hotbar,
		Storage = storage,
		LocationByUUID = {},
		MetadataIndex = {},
		EquippedItemUUID = equipped,
		Weight = weight,
		Settings = settings,
	}
end

function ClientStore.GetEngineSettings(): Types.EngineSettings
	local settings: Types.Settings = Fusion.peek(ClientStore.Settings) or Settings.getDefault()
	return {
		HotbarType = settings.HotbarType,
		MaxHotbarSlots = settings.MaxHotbarSlots,
		Limit = settings.Limit,
		CanStack = settings.CanStack,
		MaxStackSize = settings.MaxStackSize,
		BackpackEnabled = settings.BackpackEnabled,
		Sorting = settings.Sorting,
		SortOrder = settings.SortOrder,
		StackOnSwap = settings.StackOnSwap,
		StackRequiredFields = table.clone(settings.StackRequiredFields),
		StackBlacklist = table.clone(settings.StackBlacklist),
		DefaultDroppable = settings.DefaultDroppable,
	}
end

function ClientStore.GetSettings(): Types.Settings?
	local settings: Types.Settings? = Fusion.peek(ClientStore.Settings)
	return settings
end

function ClientStore.GetItem(uuid: string?): Types.Item?
	local items: { [string]: Types.Item } = Fusion.peek(ClientStore.Items)
	return Query.getItem(items, uuid)
end

function ClientStore.GetSlotOf(uuid: string): (Types.SlotType?, number?)
	local hotbar: { [number]: string? } = Fusion.peek(ClientStore.Hotbar)
	local storage: { string } = Fusion.peek(ClientStore.Storage)
	return Query.findSlotByUUID(hotbar, storage, uuid)
end

-----------------------------
-- MAIN --
-----------------------------

return ClientStore
