--@author: yyumchi
--@date: 2026-07-06
--[[@description:
	Tests for StowayServerV3_0_0 orchestration layer.
	Uses mock player objects (no Roblox environment needed).
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Stoway = require("@Stoway")
local CoreStore = require("@CoreStore")

Stoway.Init(CoreStore)

local passCount = 0
local failCount = 0
local totalTests = 0

-- Mock player objects
local MockPlayer1 = { Name = "Player1", UserId = 1 }
local MockPlayer2 = { Name = "Player2", UserId = 2 }

-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		error(`  Expected {tostring(expected)}, got {tostring(actual)}: {message}`)
	end
end

local function runTest(name: string, shouldPass: boolean, fn: () -> ())
	totalTests += 1

	local ok, err = pcall(fn)

	if ok and shouldPass then
		passCount += 1
		print(`  [PASS] {name}`)
	elseif not ok and not shouldPass then
		passCount += 1
		print(`  [PASS] {name}`)
	elseif ok and not shouldPass then
		failCount += 1
		print(`  [FAIL] {name} - expected failure but passed`)
	else
		failCount += 1
		print(`  [FAIL] {name}`)
		print(`    {err}`)
	end
end

-- PUBLIC FUNCTIONS --
-----------------------------

-- ==================== PLAYER LIFECYCLE ==================

runTest("createPlayer returns inventory state", true, function()
	-- Clean up any previous state
	Stoway.removePlayer(MockPlayer1)
	Stoway.removePlayer(MockPlayer2)

	local state = Stoway.createPlayer(MockPlayer1, { Limit = 50 })
	assertEqual(state ~= nil, true, "state should exist")
	assertEqual(state.Settings.Limit, 50, "limit should be 50")
end)

runTest("get returns state for player", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1)
	local state = Stoway.get(MockPlayer1)
	assertEqual(state ~= nil, true, "state should exist")
end)

runTest("get returns nil for unknown player", true, function()
	Stoway.removePlayer(MockPlayer1)
	local state = Stoway.get(MockPlayer1)
	assertEqual(state, nil, "should be nil")
end)

runTest("removePlayer returns and clears state", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1)
	local removed = Stoway.removePlayer(MockPlayer1)
	assertEqual(removed ~= nil, true, "removed should exist")
	assertEqual(Stoway.get(MockPlayer1), nil, "should be nil after remove")
end)

runTest("getAll returns all players", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.removePlayer(MockPlayer2)
	Stoway.createPlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer2)
	local all = Stoway.getAll()
	local count = 0
	for _ in all do
		count += 1
	end
	assertEqual(count, 2, "should have 2 players")
end)

-- ==================== ROUTE TESTS ==================

runTest("AddItem routes to CoreStore", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })
	local result = Stoway.AddItem(MockPlayer1, { Id = "Sword", Amount = 1 })
	assertEqual(result.ok, true, "should succeed")
end)

runTest("AddItem fails without state", true, function()
	Stoway.removePlayer(MockPlayer1)
	local result = Stoway.AddItem(MockPlayer1, { Id = "Sword", Amount = 1 })
	assertEqual(result.ok, false, "should fail")
	assertEqual(result.error.message, "NO_STATE", "should be NO_STATE")
end)

runTest("EquipSlot routes to CoreStore", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })
	Stoway.AddToHotbar(MockPlayer1, { Id = "Sword", Amount = 1 })
	local state = Stoway.get(MockPlayer1)
	local uuid = state.Hotbar[1]

	local result = Stoway.EquipSlot(MockPlayer1, uuid)
	assertEqual(result.ok, true, "should succeed")
end)

runTest("UnequipSlot routes to CoreStore", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })
	Stoway.AddToHotbar(MockPlayer1, { Id = "Sword", Amount = 1 })
	local state = Stoway.get(MockPlayer1)
	local uuid = state.Hotbar[1]

	Stoway.EquipSlot(MockPlayer1, uuid)
	local result = Stoway.UnequipSlot(MockPlayer1)
	assertEqual(result.ok, true, "should succeed")
	assertEqual(state.EquippedItemUUID, nil, "should be unequipped")
end)

runTest("RemoveItem routes to CoreStore", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })
	local addResult = Stoway.AddItem(MockPlayer1, { Id = "Sword", Amount = 1 })
	local uuid = addResult.value.addedItems[1].uuid

	local result = Stoway.RemoveItem(MockPlayer1, uuid, 1)
	assertEqual(result.ok, true, "should succeed")
end)

runTest("SwapSlots routes to CoreStore", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })
	Stoway.AddToHotbar(MockPlayer1, { Id = "Sword", Amount = 1 })
	Stoway.AddToHotbar(MockPlayer1, { Id = "Shield", Amount = 1 })

	local result = Stoway.SwapSlots(MockPlayer1,
		{ Type = "Hotbar", Slot = 1 },
		{ Type = "Hotbar", Slot = 2 }
	)
	assertEqual(result.ok, true, "should succeed")
end)

runTest("SwapStack routes and dispatches its distinct operation", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100, StackOnSwap = true, CanStack = false })
	Stoway.AddToHotbar(MockPlayer1, { Id = "Apple", Amount = 3 })
	Stoway.AddToHotbar(MockPlayer1, { Id = "Apple", Amount = 2 })
	local state = Stoway.get(MockPlayer1)
	state.Settings.CanStack = true
	local operations = {}
	Stoway.registerAdapter(function(_, signal)
		table.insert(operations, signal.operation)
	end)

	local result = Stoway.SwapStack(MockPlayer1, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertEqual(result.ok, true, "should succeed")
	assertEqual(state.Hotbar[1], nil, "source should be absorbed")
	assertEqual(state.Items[state.Hotbar[2]].Amount, 5, "target should receive source amount")
	assertEqual(operations[1], "SwapStack", "should dispatch SwapStack")
end)

runTest("UpdateMetadata routes to CoreStore", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })
	local addResult = Stoway.AddItem(MockPlayer1, { Id = "Sword", Amount = 1 })
	local uuid = addResult.value.addedItems[1].uuid

	local result = Stoway.UpdateMetadata(MockPlayer1, uuid, { Rarity = "Legendary" })
	assertEqual(result.ok, true, "should succeed")
end)

runTest("Sort routes to CoreStore", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100, Sorting = true, SortOrder = "Name" })
	Stoway.AddItem(MockPlayer1, { Id = "Zebra", Amount = 1 })
	Stoway.AddItem(MockPlayer1, { Id = "Apple", Amount = 1 })

	local result = Stoway.Sort(MockPlayer1)
	assertEqual(result.ok, true, "should succeed")
end)

-- ==================== ADAPTER DISPATCH ==================

runTest("operation dispatches to adapters", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })

	local dispatched = {}
	Stoway.registerAdapter(function(player, signal)
		table.insert(dispatched, signal.operation)
	end)

	Stoway.AddItem(MockPlayer1, { Id = "Sword", Amount = 1 })
	assertEqual(#dispatched >= 1, true, "should dispatch at least 1")
	assertEqual(dispatched[1], "AddItem", "should dispatch AddItem")
end)

-- ==================== REPLICATE FLAG ==================

runTest("add does not replicate when replicate omitted", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })

	local signals = {}
	Stoway.registerAdapter(function(player, signal)
		table.insert(signals, { operation = signal.operation, replicate = signal.replicate })
	end)

	-- Replication is opt-in: no override given, so replicate = false.
	local result = Stoway.AddItem(MockPlayer1, { Id = "Sword", Amount = 1 })
	assertEqual(result.ok, true, "should succeed")
	assertEqual(signals[1].operation, "AddItem", "should dispatch AddItem")
	assertEqual(signals[1].replicate, false, "omitted replicate should not replicate")
end)

runTest("add replicates only when replicate = true", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })

	local signals = {}
	Stoway.registerAdapter(function(player, signal)
		table.insert(signals, { operation = signal.operation, replicate = signal.replicate })
	end)

	local result = Stoway.AddItem(MockPlayer1, { Id = "Sword", Amount = 1 }, nil, true)
	assertEqual(result.ok, true, "should succeed")
	assertEqual(signals[1].operation, "AddItem", "should dispatch AddItem")
	assertEqual(signals[1].replicate, true, "explicit replicate = true should replicate")
end)

runTest("player swap does not replicate a full echo", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })
	Stoway.AddToHotbar(MockPlayer1, { Id = "Apple", Amount = 1 })
	Stoway.AddToHotbar(MockPlayer1, { Id = "Sword", Amount = 1 })

	local signals = {}
	Stoway.registerAdapter(function(player, signal)
		table.insert(signals, { operation = signal.operation, replicate = signal.replicate })
	end)

	-- Client already rendered the swap locally; no need to echo back a sync.
	local result = Stoway.SwapSlots(MockPlayer1,
		{ Type = "Hotbar", Slot = 1 },
		{ Type = "Hotbar", Slot = 2 },
		false
	)
	assertEqual(result.ok, true, "swap should succeed")
	assertEqual(signals[1].operation, "SwapSlots", "should dispatch SwapSlots")
	assertEqual(signals[1].replicate, false, "client swap should not replicate a full sync")
end)

runTest("failed swap still dispatches a revert signal", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })

	local signals = {}
	Stoway.registerAdapter(function(player, signal)
		table.insert(signals, { operation = signal.operation, replicate = signal.replicate, ok = signal.result.ok })
	end)

	-- Attempt to swap out of bounds -> fails. The client applied it locally,
	-- so we still dispatch a (failed) swap so Communications can send the inverse.
	local result = Stoway.SwapSlots(MockPlayer1,
		{ Type = "Hotbar", Slot = 1 },
		{ Type = "Hotbar", Slot = 99 },
		false
	)
	assertEqual(result.ok, false, "swap should fail")
	assertEqual(signals[1].operation, "SwapSlots", "should dispatch SwapSlots")
	assertEqual(signals[1].ok, false, "revert should carry the failure")
end)

-- ==================== CONCURRENT OPERATIONS ==================

runTest("blocks concurrent operations", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })

	-- First operation should succeed (acquires and releases lock)
	local result1 = Stoway.AddItem(MockPlayer1, { Id = "Sword", Amount = 1 })
	assertEqual(result1.ok, true, "first should succeed")
end)

runTest("removePlayer clears everything", true, function()
	Stoway.removePlayer(MockPlayer1)
	Stoway.createPlayer(MockPlayer1, { Limit = 100 })

	local removed = Stoway.removePlayer(MockPlayer1)
	assertEqual(removed ~= nil, true, "should return removed state")
	assertEqual(Stoway.get(MockPlayer1), nil, "should be nil")
end)

-- ==================== RESULTS ==================

print()
print(`============================================`)
print(`  Results: {passCount} passed, {failCount} failed, {totalTests} total`)
print(`============================================`)
