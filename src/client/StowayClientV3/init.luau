--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Client entry point. Seeds ClientStore from mock data and mounts the
	StandardHotbarStorage layout with the DefaultModern skin.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local ClientStore = require("@self/Controller/ClientStore")
local ClientController = require("@self/Controller/ClientController")
local LayoutManager = require("@self/Controller/LayoutManager")
local MockData = require("@self/Mock/MockData")
local Signals = require("@self/Signals")

local StowayClient = {}
StowayClient.Signals = Signals
StowayClient.Store = ClientStore
StowayClient.Controller = ClientController

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
	local snapshot = MockData.build()
	ClientStore.Init(snapshot)

	LayoutManager.SetLayout(ClientStore.RootScope, playerGui, ClientStore, "StandardHotbarStorage", "DefaultModern")

	-- SignalPlus bus mirrors master NetworkHandler: UI mutations go through
	-- ClientController which clone→set ClientStore atoms so Fusion Hydrate
	-- updates are deferred+coalesced (atomic rebuild like master).
	ClientController.Init(Signals, snapshot)

	print("[StowayClientV3] core initialized (mock data, StandardHotbarStorage / DefaultModern) — Signals bound")
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

-----------------------------
-- MAIN --
-----------------------------

return StowayClient
