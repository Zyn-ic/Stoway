--!strict
--@author: yyumchi
--@date: 2026-08-21
--[[@description:
	Visual UI reflection harness — CLIENT singleton.
	Runs in Play on the client (PlayerGui exists). Drives the REAL
	ClientStore singleton via SignalPlus (like master NetworkHandler).
	Only UI atomic cases remain here – pure CoreStore logic (Limit,
	BackpackEnabled, Move, StackOnSwap, Split etc) is covered by Lune
	suites (66+21+12). Use the auto LocalScript
	StarterPlayer.StarterPlayerScripts.LocalScript for the 5s smoke run.

	Usage (Play, Command Bar — Client context):
		require(game.Players.LocalPlayer.PlayerScripts.StowayClientV3.Tests.VisualHarness).run(2)
		require(game.Players.LocalPlayer.PlayerScripts.StowayClientV3.Tests.VisualHarness).runCase(1, 2)
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SharedCore = require(ReplicatedStorage.Shared.Stoway.CoreStore)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local MockData = require(script.Parent.Parent.Mock.MockData)
local Signals = require(script.Parent.Parent.Signals)
local ClientController = require(script.Parent.Parent.Controller.ClientController)

local VisualHarness = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function getGui(): (ScreenGui?, Frame?, Frame?, ScrollingFrame?, TextLabel?, TextBox?)
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui") :: PlayerGui?
	if not playerGui then return nil, nil, nil, nil, nil, nil end
	local gui = playerGui:FindFirstChild("Stoway") :: ScreenGui?
	if not gui then
		for _, child in playerGui:GetChildren() do
			if child:IsA("ScreenGui") and child:FindFirstChild("Hotbar") then
				gui = child :: ScreenGui
				break
			end
		end
	end
	if not gui then return nil, nil, nil, nil, nil, nil end
	local hotbar = gui:FindFirstChild("Hotbar") :: Frame?
	local backpack = gui:FindFirstChild("Backpack") :: Frame?
	local scrolling = backpack and backpack:FindFirstChild("ScrollingFrame") :: ScrollingFrame?
	local weight = backpack and backpack:FindFirstChild("Weight") :: TextLabel?
	local search = backpack and backpack:FindFirstChild("SearchFilter") :: TextBox?
	return gui, hotbar, backpack, scrolling, weight, search
end

local function getSlotFrame(hotbar: Frame?, name: string): Frame?
	if not hotbar then return nil end
	return hotbar:FindFirstChild(name) :: Frame?
end

local function getStackcountVisible(slotFrame: Frame?): boolean
	if not slotFrame then return false end
	local sc = slotFrame:FindFirstChild("stackcount") :: TextLabel?
	if not sc then return false end
	return sc.Visible and sc.Text ~= ""
end

local function getSlotButtonVisible(slotFrame: Frame?): boolean
	if not slotFrame then return false end
	local btn = slotFrame:FindFirstChild("slotbutton") :: ImageButton?
	if not btn then return false end
	return (btn :: GuiObject).Visible
end

local function assertEqual(actual: any, expected: any, msg: string)
	if actual ~= expected then
		error(`{msg} | expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function assertTrue(v: any, msg: string)
	if not v then error(msg, 2) end
end

local function flush()
	task.wait()
	if RunService:IsClient() then RunService.Heartbeat:Wait() end
	task.wait(0.15)
	task.wait()
end

-----------------------------
-- CASES --
-----------------------------

type Case = {
	title: string,
	setup: (any) -> any,
	assert: (any, ScreenGui?, Frame?, Frame?, ScrollingFrame?, TextLabel?) -> (),
}

local cases: { Case } = {}

-- 1 Mock valid weight – sanity that MockData hydrates LocationByUUID etc.
table.insert(cases, {
	title = "1 Mock valid weight (sum/Limit)",
	setup = function(SC)
		return MockData.build()
	end,
	assert = function(state, _gui, hotbar, backpack, _scrolling, weight)
		assertTrue(backpack ~= nil, "Backpack exists")
		if backpack then
			assertTrue(backpack.Visible, "Backpack Visible")
		end
		assertTrue(weight ~= nil, "Weight exists")
		if weight then
			local expected = `{state.Weight}/{state.Settings.Limit}`
			assertEqual(weight.Text, expected, `Weight {expected}`)
			assertTrue(weight.Visible, "Weight visible")
		end
		local f1 = getSlotFrame(hotbar, "Hotbar-1")
		assertTrue(f1 ~= nil and f1.Visible, "Hotbar-1 frame visible")
		local sel = f1 and f1:FindFirstChild("selecticon") :: GuiObject?
		assertTrue(sel ~= nil and sel.Visible, "Hotbar-1 selecticon ON")
		local f2 = getSlotFrame(hotbar, "Hotbar-2")
		assertTrue(getStackcountVisible(f2), "Hotbar-2 stackcount 3x visible")
	end,
})

-- 6 Swap HH Static H1<->H2 – direct CoreStore (baseline, no bus)
table.insert(cases, {
	title = "6 Swap HH Static H1<->H2",
	setup = function(SC)
		local s = SC.new({ Limit = 100, HotbarType = "Static" })
		SC.addToHotbar(s, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Common" } })
		SC.addToHotbar(s, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Common" } })
		SC.swap(s, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
		return s
	end,
	assert = function(state, _gui, hotbar, _backpack, _scrolling, _weight)
		assertEqual(state.Items[state.Hotbar[1]].Id, "Shield", "H1 Shield")
		assertEqual(state.Items[state.Hotbar[2]].Id, "Sword", "H2 Sword")
		local f1 = getSlotFrame(hotbar, "Hotbar-1")
		local f2 = getSlotFrame(hotbar, "Hotbar-2")
		assertTrue(getSlotButtonVisible(f1) and getSlotButtonVisible(f2), "Both slotbuttons visible")
		local r1 = f1 and f1:FindFirstChild("rarityframe") :: GuiObject?
		assertTrue(r1 ~= nil and r1.Visible, "rarityframe visible")
	end,
})

-- 6b Equipped H1<->H2 – atomic UI test (direct)
table.insert(cases, {
	title = "6b Swap HH equipped H1<->H2 atomic",
	setup = function(SC)
		local s = SC.new({ Limit = 100, HotbarType = "Static" })
		SC.addToHotbar(s, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Rare", Type = "Weapon", Image = "rbxassetid://111" } })
		SC.addToHotbar(s, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Common", Type = "Armor", Image = "rbxassetid://222" } })
		SC.equip(s, s.Hotbar[1])
		SC.swap(s, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
		return s
	end,
	assert = function(state, _gui, hotbar, _backpack, _scrolling, _weight)
		assertEqual(state.Items[state.Hotbar[1]].Id, "Shield", "H1 Shield after swap")
		assertEqual(state.Items[state.Hotbar[2]].Id, "Sword", "H2 Sword after swap")
		assertEqual(state.EquippedItemUUID, state.Hotbar[2], "Equipped follows Sword to H2")
		local f1 = getSlotFrame(hotbar, "Hotbar-1")
		local f2 = getSlotFrame(hotbar, "Hotbar-2")
		local sel1 = f1 and f1:FindFirstChild("selecticon") :: GuiObject?
		local sel2 = f2 and f2:FindFirstChild("selecticon") :: GuiObject?
		assertTrue(sel1 == nil or not sel1.Visible, "H1 selecticon OFF")
		assertTrue(sel2 ~= nil and sel2.Visible, "H2 selecticon ON")
		assertTrue(getSlotButtonVisible(f1) and getSlotButtonVisible(f2), "Both slotbuttons visible")
	end,
})

-- 6c Same as 6b but via SignalPlus – real app path (ClientController clone+set)
table.insert(cases, {
	title = "6c Swap HH equipped via SignalPlus atomic",
	setup = function(SC)
		local s = SC.new({ Limit = 100, HotbarType = "Static" })
		SC.addToHotbar(s, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Rare", Type = "Weapon", Image = "rbxassetid://111" } })
		SC.addToHotbar(s, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Common", Type = "Armor", Image = "rbxassetid://222" } })
		SC.equip(s, s.Hotbar[1])
		ClientStore.Init(s)
		ClientController.Init(Signals, s)
		Signals.Swap:Fire({ Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
		return ClientController.GetState()
	end,
	assert = function(state, _gui, hotbar, _backpack, _scrolling, _weight)
		assertEqual(state.Items[state.Hotbar[1]].Id, "Shield", "H1 Shield via Signal")
		assertEqual(state.Items[state.Hotbar[2]].Id, "Sword", "H2 Sword via Signal")
		assertEqual(state.EquippedItemUUID, state.Hotbar[2], "Equipped follows via Signal")
		local f1 = getSlotFrame(hotbar, "Hotbar-1")
		local f2 = getSlotFrame(hotbar, "Hotbar-2")
		local sel1 = f1 and f1:FindFirstChild("selecticon") :: GuiObject?
		local sel2 = f2 and f2:FindFirstChild("selecticon") :: GuiObject?
		assertTrue(sel1 == nil or not sel1.Visible, "H1 selecticon OFF via Signal")
		assertTrue(sel2 ~= nil and sel2.Visible, "H2 selecticon ON via Signal")
	end,
})

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function VisualHarness.run(intervalSec: number?)
	local interval = intervalSec or 2
	print(`\n=== Visual Harness (signal) {interval}s ===`)
	for idx, case in cases do
		print(`\n[Case {idx}] {case.title}`)
		pcall(function() ClientController.Destroy() end)
		local okSetup, stateOrErr = pcall(case.setup, SharedCore)
		if not okSetup then warn(`  [SETUP FAIL] {stateOrErr}`); task.wait(interval); continue end
		local state = stateOrErr :: any
		local isSignalCase = string.find(case.title, "via SignalPlus") ~= nil
		if not isSignalCase then
			pcall(function() ClientController.Destroy() end)
			local okInit, errInit = pcall(function() ClientStore.Init(state) end)
			if not okInit then warn(`  [INIT FAIL] {errInit}`); task.wait(interval); continue end
		else
			state = ClientController.GetState() or state
		end
		flush()
		local gui, hotbar, backpack, scrolling, weight, _search = getGui()
		local packed = table.pack(pcall(case.assert, state, gui, hotbar, backpack, scrolling, weight))
		local okAssert = packed[1] :: boolean
		local errAssert = packed[2]
		if okAssert then print(`  [PASS] {case.title}`) else warn(`  [FAIL] {case.title}: {errAssert}`) end
		task.wait(interval)
	end
	pcall(function() ClientController.Destroy() end)
	print("\n=== Visual Harness done: 4 cases (mock + 6/6b/6c) — other CoreStore cases removed (covered by Lune) ===")
end

function VisualHarness.runCase(idx: number, intervalSec: number?)
	local case = cases[idx]
	if not case then warn(`[VisualHarness] no case {idx}`); return end
	local interval = intervalSec or 2
	print(`\n[Single Case {idx}] {case.title}`)
	pcall(function() ClientController.Destroy() end)
	local state = case.setup(SharedCore)
	local isSignalCase = string.find(case.title, "via SignalPlus") ~= nil
	if not isSignalCase then ClientStore.Init(state) else state = ClientController.GetState() or state end
	flush()
	local gui, hotbar, backpack, scrolling, weight, _ = getGui()
	local packed = table.pack(pcall(case.assert, state, gui, hotbar, backpack, scrolling, weight))
	local ok = packed[1] :: boolean
	local err = packed[2]
	if ok then print(`  [PASS] {case.title}`) else warn(`  [FAIL] {case.title}: {err}`) end
	task.wait(interval)
	pcall(function() ClientController.Destroy() end)
end

function VisualHarness.list()
	for i, c in cases do print(`{i}: {c.title}`) end
end

return VisualHarness
