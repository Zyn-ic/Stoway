--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	StowayClientV3 — Fusion client entry point. Core phase only: seeds
	ClientStore from mock data and mounts the StandardHotbarStorage layout
	under the DefaultModern skin via LayoutManager. No networking, no
	dragging, no gamepad/hooks yet — see Controller/LayoutManager.luau and
	the Layouts/ folder for how a Carousel or Utility Belt HotbarType slots
	in later without touching this file, CoreStore, or Controller.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local ClientStore = require(script.Controller.ClientStore)
local LayoutManager = require(script.Controller.LayoutManager)
local MockData = require(script.Mock.MockData)

local StowayClient = {}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function StowayClient.Init()
	-- Replace the default backpack UI.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	-- Seed local state from mock data (pure client test: no server round trip).
	ClientStore.Init(MockData.build())

	LayoutManager.SetLayout(ClientStore.RootScope, playerGui, ClientStore, "StandardHotbarStorage", "DefaultModern")

	print("[StowayClientV3] core initialized (mock data, StandardHotbarStorage / DefaultModern)")
end

-----------------------------
-- MAIN --
-----------------------------

return StowayClient
