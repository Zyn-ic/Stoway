--!strict
--@author: yyumchi
--@date: 2026-09-20
--[[@description:
	EXAMPLE (branch example/locked-slots): SlotLocks pure-logic specs.
	Run: require(game.ReplicatedStorage.Tests.Runner).run()
	or:  require(game.ReplicatedStorage.Tests.Runner).runSpec("SlotLocks")
]]

local SlotLocks = require(game:GetService("ReplicatedStorage").Shared.Stoway.SlotLocks)
local SharedTypes = require(game:GetService("ReplicatedStorage").Shared.Stoway.Types)

local function plainItem(uuid: string): SharedTypes.Item
	return { UUID = uuid, Id = "TestItem", Amount = 1, Metadata = {} }
end

local function tokenItem(uuid: string, slot: number): SharedTypes.Item
	return { UUID = uuid, Id = "PouchToken", Amount = 1, Metadata = { UnlocksHotbarSlot = slot } }
end

return function(describe: any, it: any, expect: any)
	describe("SlotLocks - isUnlocked", function()
		it("unlocked when the slot is not in the lock set", function()
			expect(SlotLocks.isUnlocked({}, { [9] = true }, 1)).toBe(true)
		end)

		it("unlocked when the lock set is nil (fail-open)", function()
			expect(SlotLocks.isUnlocked({}, nil, 9)).toBe(true)
		end)

		it("locked with no token held", function()
			local items = { a = plainItem("a") }
			expect(SlotLocks.isUnlocked(items, { [9] = true }, 9)).toBe(false)
		end)

		it("unlocked while holding the token", function()
			local items = { a = plainItem("a"), token = tokenItem("token", 9) }
			expect(SlotLocks.isUnlocked(items, { [9] = true }, 9)).toBe(true)
		end)

		it("a token for another slot does not unlock", function()
			local items = { token = tokenItem("token", 3) }
			expect(SlotLocks.isUnlocked(items, { [9] = true }, 9)).toBe(false)
		end)

		it("an item with no metadata table is ignored", function()
			local items = { odd = {} :: any }
			expect(SlotLocks.isUnlocked(items, { [9] = true }, 9)).toBe(false)
		end)
	end)
end
