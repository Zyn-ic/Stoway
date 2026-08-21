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
