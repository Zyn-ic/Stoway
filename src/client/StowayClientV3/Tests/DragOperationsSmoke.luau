--!strict

--@author: yyumchi
--@date: 2026-09-01
--[[@description:
	Smoke tests for the new drag router (Swap / Move / AddToBackpack / Remove)
	and Click-to-equip. Run in Studio Play (Client context):

	require(game.Players.LocalPlayer.PlayerScripts.StowayClientV3.Tests.DragOperationsSmoke).run()

	Or via LocalScript in StarterPlayerScripts:
	require(script.Parent.StowayClientV3.Tests.DragOperationsSmoke).run()

	Covers:
	- Static Hotbar + BackpackEnabled=false (no storage)
	- Static Hotbar + BackpackEnabled=true (Move HS append = AddToBackpack, Remove outside, StackOnSwap)
	- Dynamic Hotbar packed semantics (empty invisible slots not swappable, append via background)
	- Click equip/unequip (SlotView MouseButton1Click -> ClientController)
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedCore = require(ReplicatedStorage.Shared.Stoway.CoreStore)
local ClientStore = require(script.Parent.Parent.Controller.ClientStore)
local ClientController = require(script.Parent.Parent.Controller.ClientController)
local Signals = require(script.Parent.Parent.Signals)

local Smoke = {}

local function assertEq(actual: any, expected: any, msg: string)
	if actual ~= expected then
		error(`{msg} expected {tostring(expected)} got {tostring(actual)}`, 2)
	end
end

local function assertTrue(v: boolean, msg: string)
	if not v then error(msg, 2) end
end

local function seedState(overrides: { [string]: any }, itemsSetup: ((any) -> ())?): any
	local baseSettings = {
		Limit = 100,
		HotbarType = "Static",
		BackpackEnabled = true,
		CanStack = true,
		MaxStackSize = 5,
		StackOnSwap = false,
		StackRequiredFields = { "Rarity", "Type" },
		StackBlacklist = { Legendary = true, Mythic = true, Special = true },
		Sorting = false,
		SortOrder = "None",
	}
	for k, v in overrides do (baseSettings :: any)[k] = v end
	local s = SharedCore.new(baseSettings :: any)
	if itemsSetup then itemsSetup(s) end
	-- Bind controller so ClientStore mirrors state (needed for Router peek)
	pcall(function() ClientController.Destroy() end)
	local signals = Signals
	ClientStore.Init(s :: any)
	ClientController.Init(signals, s)
	return s
end

local function printState(tag: string, s: any)
	local hotbarStr = {}
	for i = 1, 10 do
		local uuid = s.Hotbar[i]
		if uuid then
			local it = s.Items[uuid]
			table.insert(hotbarStr, `{i}:{it and it.Id or uuid} x{it and it.Amount or "?" }`)
		else
			table.insert(hotbarStr, `{i}:empty`)
		end
	end
	local storageStr = {}
	for i, uuid in ipairs(s.Storage) do
		local it = s.Items[uuid]
		table.insert(storageStr, `{i}:{it and it.Id or uuid} x{it and it.Amount or "?"}`)
	end
	print(`[{tag}] Hotbar {table.concat(hotbarStr, " | ")}`)
	print(`[{tag}] Storage {table.concat(storageStr, " | ")}`)
	print(`[{tag}] Equipped {tostring(s.EquippedItemUUID)} Weight {s.Weight}`)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Smoke.run()
	print("\n=== DragOperationsSmoke ===")

	-- 1. Static + BackpackDisabled: Swap HH + Move HH empty + Click equip
	do
		print("\n[1] Static BackpackDisabled: Swap HH / Move HH empty / Click equip")
		local s = seedState({ HotbarType = "Static", BackpackEnabled = false }, function(state)
			SharedCore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Common", Type = "Weapon" } }, 1)
			SharedCore.addToHotbar(state, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Common", Type = "Armor" } }, 2)
			-- slot 3 empty
		end)
		printState("1-init", s)
		-- Swap occupied->occupied (router would call Swap)
		local r = ClientController.Swap({ Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
		assertTrue(r.ok, "Swap HH occupied should ok")
		assertEq(s.Items[s.Hotbar[1]].Id, "Shield", "H1 Shield after swap")
		assertEq(s.Items[s.Hotbar[2]].Id, "Sword", "H2 Sword after swap")
		printState("1-swap", s)
		-- Move to empty hole (router empty->Move)
		local r2 = ClientController.Move({ Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 3 })
		assertTrue(r2.ok, "Move HH to empty should ok in Static")
		assertEq(s.Hotbar[1], nil, "H1 empty after move")
		assertEq(s.Items[s.Hotbar[3]].Id, "Shield", "H3 Shield after move")
		printState("1-move", s)
		-- Click equip (SlotView MouseButton1Click simulation)
		local uuid = s.Hotbar[3] :: string
		local eq = ClientController.Equip(uuid)
		assertTrue(eq.ok, "Equip should ok")
		assertEq(s.EquippedItemUUID, uuid, "Equipped follows Shield at H3")
		printState("1-equip", s)
		local uneq = ClientController.Unequip()
		assertTrue(uneq.ok, "Unequip ok")
		assertEq(s.EquippedItemUUID, nil, "Unequipped nil")
		printState("1-unequip", s)
		print("  [PASS] 1 Static BackpackDisabled")
	end

	-- 2. Static + BackpackEnabled: AddToBackpack via Move HS append + Remove outside + SS move
	do
		print("\n[2] Static BackpackEnabled: AddToBackpack (Move HS) / Remove outside / Move SS")
		local s = seedState({ HotbarType = "Static", BackpackEnabled = true }, function(state)
			SharedCore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Common", Type = "Weapon" } }, 1)
			SharedCore.addToHotbar(state, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Common", Type = "Armor" } }, 2)
			SharedCore.addToBackpack(state, { Id = "Potion", Amount = 3, Metadata = { Rarity = "Common", Type = "Consumable" } })
		end)
		printState("2-init", s)
		-- AddToBackpack: Hotbar -> Storage append (router overBackpack path calls Move HS)
		local beforeStorage = #s.Storage
		local r = ClientController.Move({ Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = beforeStorage + 1 })
		assertTrue(r.ok, "Move HS append should ok")
		assertEq(s.Hotbar[1], nil, "H1 empty after AddToBackpack")
		assertEq(#s.Storage, beforeStorage + 1, "Storage grew by 1")
		assertEq(s.Items[s.Storage[#s.Storage]].Id, "Sword", "Appended Sword at Storage end")
		printState("2-addToBackpack", s)
		-- Remove outside: simulate drag outside -> ClientController.Remove(uuid)
		local swordUUID = s.Storage[#s.Storage]
		local rem = ClientController.Remove(swordUUID)
		assertTrue(rem.ok, "Remove should ok")
		assertEq(s.Items[swordUUID], nil, "Sword removed from Items")
		printState("2-remove", s)
		-- Move SS (reorder within storage) – never stacks
		if #s.Storage >= 2 then
			local _first = s.Storage[1]
			local r2 = ClientController.Move({ Type = "Storage", Slot = 1 }, { Type = "Storage", Slot = 2 })
			assertTrue(r2.ok, "Move SS should ok")
			printState("2-moveSS", s)
		end
		print("  [PASS] 2 Static BackpackEnabled")
	end

	-- 3. StackOnSwap: Swap should stack when StackOnSwap=true, Move never stacks
	do
		print("\n[3] StackOnSwap via Swap (occupied->occupied) vs Move never stacks")
		local s = seedState({ HotbarType = "Static", BackpackEnabled = true, StackOnSwap = true, MaxStackSize = 5 }, function(state)
			-- Two stackable HealthPotions Common/Consumable, room to stack
			SharedCore.addToHotbar(state, { Id = "HealthPotion", Amount = 2, Metadata = { Rarity = "Common", Type = "Consumable" } }, 1)
			SharedCore.add(state, { Id = "HealthPotion", Amount = 3, Metadata = { Rarity = "Common", Type = "Consumable" } }, { Placement = "Backpack" })
			-- Ensure storage has potion at slot 1
		end)
		printState("3-init", s)
		-- Find positions: H1=2, Storage contains 3
		local hotbarPotionUUID = s.Hotbar[1] :: string
		local storagePotionUUID = s.Storage[1] :: string
		local beforeAmountDest = s.Items[storagePotionUUID].Amount -- 3
		-- Router would call Swap for occupied->occupied
		local r = ClientController.Swap({ Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
		assertTrue(r.ok, "Swap with StackOnSwap should ok")
		-- Stack: dest absorbs source fully (2+3=5), source destroyed, H1 should be nil
		-- Note: if dest was at 3, room=2, source 2 fully absorbed -> 5
		local afterDest = s.Items[storagePotionUUID]
		assertTrue(afterDest ~= nil, "Dest still exists")
		assertEq(afterDest.Amount, beforeAmountDest + 2, "Dest stacked to 5")
		assertEq(s.Hotbar[1], nil, "Source slot empty after full absorption")
		assertEq(s.Items[hotbarPotionUUID], nil, "Source item destroyed")
		printState("3-swapStacked", s)

		-- Now test Move never stacks even with same settings
		local s2 = seedState({ HotbarType = "Static", BackpackEnabled = true, StackOnSwap = true, MaxStackSize = 5 }, function(state)
			SharedCore.addToHotbar(state, { Id = "HealthPotion", Amount = 2, Metadata = { Rarity = "Common", Type = "Consumable" } }, 1)
			SharedCore.add(state, { Id = "HealthPotion", Amount = 3, Metadata = { Rarity = "Common", Type = "Consumable" } }, { Placement = "Backpack" })
		end)
		-- Try Move onto occupied -> should reject DESTINATION_OCCUPIED, not stack
		local r2 = ClientController.Move({ Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
		assertTrue(not r2.ok, "Move onto occupied should reject, never stacks")
		assertEq(r2.error and r2.error.message, "DESTINATION_OCCUPIED", "Move occupied error")
		printState("3-moveNoStack", s2)

		-- Blacklisted rarity should NOT stack even with StackOnSwap=true
		local s3 = seedState({ HotbarType = "Static", BackpackEnabled = true, StackOnSwap = true, MaxStackSize = 5 }, function(state)
			SharedCore.addToHotbar(state, { Id = "HealthPotion", Amount = 2, Metadata = { Rarity = "Legendary", Type = "Consumable" } }, 1)
			SharedCore.add(state, { Id = "HealthPotion", Amount = 3, Metadata = { Rarity = "Legendary", Type = "Consumable" } }, { Placement = "Backpack" })
		end)
		printState("3-blacklist-init", s3)
		local r3 = ClientController.Swap({ Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
		assertTrue(r3.ok, "Swap blacklisted should still ok (positional swap)")
		-- Should have swapped positions, not stacked
		assertEq(s3.Items[s3.Hotbar[1]].Amount, 3, "H1 now has dest 3 (swapped, not stacked)")
		assertEq(s3.Items[s3.Storage[1]].Amount, 2, "S1 now has source 2")
		printState("3-blacklist-swap", s3)
		print("  [PASS] 3 StackOnSwap")
	end

	-- 4. Dynamic hotbar: empty invisible slots + append via background
	do
		print("\n[4] Dynamic hotbar: invisible empties + Storage->Hotbar append")
		local s = seedState({ HotbarType = "Dynamic", BackpackEnabled = true, MaxHotbarSlots = 10 }, function(state)
			SharedCore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Common", Type = "Weapon" } }, 1)
			SharedCore.addToHotbar(state, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Common", Type = "Armor" } }, 3)
			-- Note: gaps will be compacted on Dynamic switch; we compact explicitly
			SharedCore.setHotbarType(state, "Dynamic")
		end)
		printState("4-init", s)
		-- After compact, hotbar should be packed: [1]=Sword, [2]=Shield, [3]=nil
		assertEq(s.Items[s.Hotbar[1]].Id, "Sword", "D H1 Sword")
		assertEq(s.Items[s.Hotbar[2]].Id, "Shield", "D H2 Shield")
		assertEq(s.Hotbar[3], nil, "D H3 empty (invisible)")
		-- Move in Dynamic to empty hole should be rejected (router fallback covers, direct Move should reject)
		local r = ClientController.Move({ Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 5 })
		assertTrue(not r.ok, "Dynamic Move HH to empty hole should reject")
		printState("4-moveHHReject", s)
		-- Swap HH in Dynamic to empty hole should also reject
		local r2 = ClientController.Swap({ Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 5 })
		assertTrue(not r2.ok, "Dynamic Swap HH to empty hole should reject")
		printState("4-swapHHReject", s)
		-- Move HS append (AddToBackpack) should compact hotbar
		local r3 = ClientController.Move({ Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
		assertTrue(r3.ok, "Dynamic Move HS should ok and compact")
		printState("4-moveHSCompact", s)
		-- Storage -> Hotbar append via router would use Swap to first empty slot (should be at 2 after compact)
		-- Directly test Swap SH append via our router logic: find first nil
		local appendSlot: number? = nil
		for i = 1, 10 do if s.Hotbar[i]==nil then appendSlot=i; break end end
		assertTrue(appendSlot ~= nil, "Found append slot")
		local _storageUUID = s.Storage[1]
		local r4 = ClientController.Swap({ Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = appendSlot :: number })
		assertTrue(r4.ok, "Storage->Hotbar append via Swap should ok in Dynamic")
		printState("4-storageToHotbarAppend", s)
		print("  [PASS] 4 Dynamic")
	end

	pcall(function() ClientController.Destroy() end)
	print("\n=== DragOperationsSmoke DONE: all 4 groups passed ===")
	print("Manual drag checks still needed in Play:")
	print("- Drag H1 -> H2 (occupied) => Swap (with StackOnSwap=true should stack potions)")
	print("- Drag H1 -> empty H3 (Static) => Move, works")
	print("- Drag H1 -> Backpack background => AddToBackpack (append)")
	print("- Drag H1 -> outside window => Remove")
	print("- Click slotbutton => Equip/Unequip (selecticon toggles)")
	print("- Dynamic: Drag Storage item over Hotbar background => append to first empty")
end

return Smoke
