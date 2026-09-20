--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Client entry point. Boots from the server snapshot (FullSync pushed
	on join, requested as backup) and mounts the StandardHotbarStorage
	layout with the settings UiSkin. No mock data: without a snapshot
	the UI mounts empty.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local ClientStore = require("@self/Controller/ClientStore")
local ClientController = require("@self/Controller/ClientController")
local ClientEvents = require("@self/Controller/ClientEvents")
local NetworkClient = require("@self/Controller/NetworkClient")
local LayoutManager = require("@self/Controller/LayoutManager")
local Signals = require("@self/Signals")
local CoreTypes = require("@self/CoreStore/Types")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage.Shared.Stoway.Settings)
local EngineTypes = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)

-- Empty inventory with default settings. Indexes fill via hydrate.
-- Engine-shaped (not the slim client mirror): ClientController.Init
-- takes the full state; Stoway-level Settings is a compatible superset.
local function emptyState(): EngineTypes.InventoryState
	return {
		Items = {},
		ItemsByID = {},
		Hotbar = {},
		Storage = {},
		LocationByUUID = {},
		MetadataIndex = {},
		EquippedItemUUID = nil,
		Weight = 0,
		Settings = Settings.getDefault(),
	}
end

-- FullSync payload (no indexes, no Settings) into bootable state.
local function snapshotState(payload: CoreTypes.FullSyncPayload): EngineTypes.InventoryState
	local state = emptyState()
	state.Items = payload.Items
	for slot, uuid in payload.Hotbar do
		state.Hotbar[slot] = uuid
	end
	for idx, uuid in payload.Storage do
		state.Storage[idx] = uuid
	end
	state.EquippedItemUUID = payload.EquippedItemUUID
	if typeof(payload.Weight) == "number" then
		state.Weight = payload.Weight
	end
	return state
end

local StowayClient = {}
StowayClient.Signals = Signals
StowayClient.Store = ClientStore
StowayClient.Controller = ClientController
StowayClient.Events = ClientEvents

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StowayClient.Init()
	-- Replace the default backpack UI.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	-- Network first: subscriptions before anything can push, then ask
	-- for a snapshot to cover a missed join push.
	NetworkClient.Connect({
		Added = ClientController.ApplyServerAdded,
		Updated = ClientController.ApplyServerUpdated,
		Removed = ClientController.ApplyServerRemoved,
		Equipped = ClientController.ApplyServerEquipped,
		Unequipped = ClientController.ApplyServerUnequipped,
		FullSync = ClientController.ApplyServerFullSync,
		LayoutChanged = function(hotbarTypeKey: string, skinKey: string)
			LayoutManager.SetLayout(
				ClientStore.RootScope,
				playerGui,
				ClientStore,
				hotbarTypeKey,
				skinKey
			)
			print(`[StowayClientV3] layout changed to {hotbarTypeKey} / {skinKey}`)
		end,
	})
	NetworkClient.RequestSnapshot()

	-- Boot from the server snapshot. The join push usually lands before
	-- this runs; the request covers the race. Empty (never mock) when
	-- the server stays silent — a later FullSync still fills the UI.
	local snapshot = NetworkClient.GetLastFullSync()
	local state: EngineTypes.InventoryState
	if snapshot then
		state = snapshotState(snapshot)
	else
		warn("[StowayClientV3] no snapshot from server, mounting empty")
		state = emptyState()
	end
	ClientController.Init(Signals, state)

	-- Single source of truth: Settings.UiSkin selects both the loader key
	-- and the GUI asset folder (1:1 contract in LayoutManager).
	local settings = ClientStore.GetSettings()
	local uiSkin: string = (settings and settings.UiSkin) or "Default"
	LayoutManager.SetLayout(ClientStore.RootScope, playerGui, ClientStore, "StandardHotbarStorage", uiSkin)

	print(`[StowayClientV3] core initialized (server snapshot, StandardHotbarStorage / {uiSkin}) — Signals bound`)
end

function StowayClient.GetSignals()
	return Signals
end

function StowayClient.GetStore()
	return ClientStore
end

function StowayClient.GetController()
	return ClientController
end

function StowayClient.GetEvents()
	return ClientEvents
end

-----------------------------
-- MAIN --
-----------------------------

return StowayClient
