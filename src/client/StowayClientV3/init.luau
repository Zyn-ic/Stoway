--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Client entry point. Seeds ClientStore from mock data and mounts the
	StandardHotbarStorage layout with the settings UiSkin.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local ClientStore = require("@self/Controller/ClientStore")
local ClientController = require("@self/Controller/ClientController")
local ClientEvents = require("@self/Controller/ClientEvents")
local NotifyExample = require("@self/Controller/NotifyExample")
local LayoutManager = require("@self/Controller/LayoutManager")
local MockData = require("@self/Mock/MockData")
local Signals = require("@self/Signals")

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

	-- Seed local state from mock data (pure client test: no server round trip).
	-- Glow demo trio (SteelDagger + FireBow + HealthPotion) carry
	-- Metadata.IsNew in the seed itself; equipping any deletes the key.
	local snapshot = MockData.build()
	ClientStore.Init(snapshot)

	-- Single source of truth: Settings.UiSkin selects both the loader key
	-- and the GUI asset folder (1:1 contract in LayoutManager).
	local uiSkin: string = (snapshot.Settings :: any).UiSkin or "Default"
	LayoutManager.SetLayout(ClientStore.RootScope, playerGui, ClientStore, "StandardHotbarStorage", uiSkin)

	-- SignalPlus bus: UI mutations go through ClientController, which
	-- clone→sets ClientStore atoms so Hydrate updates coalesce into one frame.
	ClientController.Init(Signals, snapshot)

	-- First external subscriber on the generic UI event bus (toast/sound
	-- stubs until real assets exist). Connections live for the session.
	local notifyConns = NotifyExample.Connect()
	table.insert(ClientStore.RootScope, function()
		for _, conn in notifyConns do
			conn:Disconnect()
		end
	end)

	print(`[StowayClientV3] core initialized (mock data, StandardHotbarStorage / {uiSkin}) — Signals bound`)
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
