--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	StowayClientV3 — Fusion client entry point. Builds the active UiSkin GUI
	from settings + mock data (core phase: settings-driven hotbar and
	sectioned storage; drag/multi-platform/hooks come later).
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientStore = require(script.Core.ClientStore)
local MockData = require(script.Core.MockData)
local DefaultSkin = require(script.Skin.DefaultSkin)
local HotbarView = require(script.Views.HotbarView)
local StorageView = require(script.Views.StorageView)

local StowayClient = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StowayClient.Init()
	-- Replace the default backpack UI.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Seed local state from mock data (pure client test: no server round trip).
	ClientStore.Init(MockData.build())

	local settings = ClientStore.GetSettings()
	local skin = DefaultSkin.load(playerGui, settings and settings.UiSkin or "Default")

	-- Layout scope: torn down on skin/layout swaps.
	local scope = ClientStore.Scope:deriveScope()

	HotbarView.Create(scope, skin, ClientStore)
	StorageView.Create(scope, skin, ClientStore)

	print("[StowayClientV3] core initialized")
end

-----------------------------
-- MAIN --
-----------------------------

return StowayClient