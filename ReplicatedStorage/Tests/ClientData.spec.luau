--!strict
--@author: yyumchi
--@date: 2026-08-21
--[[@description:
	Studio data specs for the inventory tables behind the UI.
	Runs in Roblox Studio (not Lune). Covers client CoreStore/Query pure
	logic: grouping, ordering, search, sort, packed hotbar, amount formatting.
	Also spot-checks Shared CoreStore MetadataIndex/sort via the canonical
	engine at ReplicatedStorage.Shared.Stoway.CoreStore.

	How to run:
	 1) In Studio, open TestService or Command Bar.
	 2) Run: require(game.ReplicatedStorage.Tests.Runner).run()
	 3) Output appears in Output. No Play needed — uses Studio VM.
	Alternatively, add this Module to TestService and use TestEZ's
	TestBootstrap:run() if TestEZ is vendored later.

	These specs intentionally avoid Fusion/Instances — pure table checks.
]]

local ClientQuery = require(game:GetService("StarterPlayer").StarterPlayerScripts.StowayClientV3.CoreStore.Query)
local ClientTypes = require(game:GetService("StarterPlayer").StarterPlayerScripts.StowayClientV3.CoreStore.Types)
local SharedCore = require(game:GetService("ReplicatedStorage").Shared.Stoway.CoreStore)

return function(describe: any, it: any, expect: any)
	describe("ClientQuery - groupStorageByType", function()
		it("groups by Type and preserves order", function()
			local items: { [string]: ClientTypes.Item } = {
				a = { UUID = "a", Id = "Sword", Amount = 1, Metadata = { Type = "Weapon", Rarity = "Common" } },
				b = { UUID = "b", Id = "Apple", Amount = 3, Metadata = { Type = "Food" } },
				c = { UUID = "c", Id = "Axe", Amount = 1, Metadata = { Type = "Weapon" } },
			}
			local storage = { "a", "b", "c" }
			local grouped = ClientQuery.groupStorageByType(storage, items, true)
			expect(grouped.Weapon).never.toBeNil()
			expect(#grouped.Weapon).toBe(2)
			expect(grouped.Weapon[1].uuid).toBe("a")
			expect(grouped.Weapon[2].uuid).toBe("c")
			expect(grouped.Food[1].uuid).toBe("b")
		end)

		it("flat mode returns UNGROUPED_KEY", function()
			local items = { a = { UUID = "a", Id = "X", Amount = 1, Metadata = {} } }
			local grouped = ClientQuery.groupStorageByType({ "a" }, items, false)
			expect(grouped[ClientQuery.UNGROUPED_KEY]).never.toBeNil()
			expect(#grouped[ClientQuery.UNGROUPED_KEY]).toBe(1)
		end)

		it("orderedGroupKeys respects Categories.Order", function()
			local groups = { Weapon = {}, Food = {}, Material = {} }
			local categories = {
				Weapon = { DisplayName = "Weapons", Color = Color3.new(1, 0, 0), Order = 1 },
				Food = { DisplayName = "Food", Color = Color3.new(0, 1, 0), Order = 2 },
				Material = { DisplayName = "Mats", Color = Color3.new(0, 0, 1), Order = 3 },
			}
			local keys = ClientQuery.orderedGroupKeys(groups, categories)
			expect(keys[1]).toBe("Weapon")
			expect(keys[2]).toBe("Food")
			expect(keys[3]).toBe("Material")
		end)

		it("unknown type sorts after known categories", function()
			local groups = { Weapon = {}, Trinket = {} }
			local categories = { Weapon = { DisplayName = "W", Color = Color3.new(1, 1, 1), Order = 1 } }
			local keys = ClientQuery.orderedGroupKeys(groups, categories)
			expect(keys[1]).toBe("Weapon")
			expect(keys[2]).toBe("Trinket")
		end)
	end)

	describe("ClientQuery - search & sortRecords", function()
		it("matchesSearch is case-insensitive on Id and Description", function()
			expect(ClientQuery.matchesSearch({ UUID = "a", Id = "IronSword", Amount = 1, Metadata = { Description = "Sharp" } }, "iron")).toBe(true)
			expect(ClientQuery.matchesSearch({ UUID = "a", Id = "IronSword", Amount = 1, Metadata = { Description = "Sharp" } }, "SHARP")).toBe(true)
			expect(ClientQuery.matchesSearch({ UUID = "a", Id = "IronSword", Amount = 1, Metadata = {} }, "bow")).toBe(false)
		end)

		it("filterRecordsBySearch filters correctly", function()
			local items = {
				a = { UUID = "a", Id = "Sword", Amount = 1, Metadata = {} },
				b = { UUID = "b", Id = "Apple", Amount = 2, Metadata = {} },
			}
			local records = { { index = 1, uuid = "a" }, { index = 2, uuid = "b" } }
			local filtered = ClientQuery.filterRecordsBySearch(records, items, "app")
			expect(#filtered).toBe(1)
			expect(filtered[1].uuid).toBe("b")
		end)

		it("sortRecords by Name is stable", function()
			local items = {
				a = { UUID = "a", Id = "Zebra", Amount = 1, Metadata = {} },
				b = { UUID = "b", Id = "Apple", Amount = 1, Metadata = {} },
			}
			local records = { { index = 2, uuid = "a" }, { index = 1, uuid = "b" } }
			local sorted = ClientQuery.sortRecords(records, items, "Name")
			expect(sorted[1].uuid).toBe("b")
			expect(sorted[2].uuid).toBe("a")
		end)

		it("sortRecords by Rarity is descending", function()
			-- Requires Colors.getRarityRank to be available in Studio
			local items: { [string]: ClientTypes.Item } = {
				a = { UUID = "a", Id = "S", Amount = 1, Metadata = { Rarity = "Common" } },
				b = { UUID = "b", Id = "S", Amount = 1, Metadata = { Rarity = "Legendary" } },
				c = { UUID = "c", Id = "S", Amount = 1, Metadata = { Rarity = "Rare" } },
			}
			local records = { { index = 1, uuid = "a" }, { index = 2, uuid = "b" }, { index = 3, uuid = "c" } }
			local sorted = ClientQuery.sortRecords(records, items, "Rarity")
			expect(sorted[1].uuid).toBe("b")
			expect(sorted[2].uuid).toBe("c")
			expect(sorted[3].uuid).toBe("a")
		end)
	end)

	describe("ClientQuery - packedHotbarOrder & format", function()
		it("packedHotbarOrder Static returns slot", function()
			local hotbar: { [number]: string? } = { [1] = "a", [3] = "b" }
			local items: { [string]: ClientTypes.Item } = {
				a = { UUID = "a", Id = "S", Amount = 1, Metadata = {} },
				b = { UUID = "b", Id = "S", Amount = 1, Metadata = {} },
			}
			expect(ClientQuery.packedHotbarOrder(hotbar, items, 3, false)).toBe(3)
		end)

		it("packedHotbarOrder Dynamic packs holes", function()
			local hotbar: { [number]: string? } = { [1] = "a", [3] = "b" }
			local items: { [string]: ClientTypes.Item } = {
				a = { UUID = "a", Id = "S", Amount = 1, Metadata = {} },
				b = { UUID = "b", Id = "S", Amount = 1, Metadata = {} },
			}
			expect(ClientQuery.packedHotbarOrder(hotbar, items, 3, true)).toBe(2)
			expect(ClientQuery.packedHotbarOrder(hotbar, items, 2, true)).toBe(1002) -- hole maps past end
		end)

		it("formatAmount abbreviates", function()
			expect(ClientQuery.formatAmount(999)).toBe("999x")
			expect(ClientQuery.formatAmount(1500)).toBe("1.5k")
			expect(ClientQuery.formatAmount(1_500_000)).toBe("1.5m")
		end)

		it("formatWeight shows limit", function()
			expect(ClientQuery.formatWeight(5, 10)).toBe("5/10")
			expect(ClientQuery.formatWeight(5, 0)).toBe("5")
		end)
	end)

	describe("Shared CoreStore - MetadataIndex & sort", function()
		it("MetadataIndex tracks Rarity/Type on add and evicts on remove", function()
			local state = SharedCore.new({ Limit = 100 })
			SharedCore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary", Type = "Weapon" } })
			expect(state.MetadataIndex.Rarity.Legendary).never.toBeNil()
			expect(#state.MetadataIndex.Rarity.Legendary).toBe(1)
			local uuid = state.Hotbar[1]
			if not uuid then error("expected hotbar uuid after addToHotbar") end
			SharedCore.remove(state, uuid)
			expect(#(state.MetadataIndex.Rarity.Legendary or {})).toBe(0)
		end)

		it("Shared sortStorage by Rarity is descending via MetadataIndex", function()
			local state = SharedCore.new({ Limit = 100, Sorting = false, SortOrder = "Rarity" })
			SharedCore.addToBackpack(state, { Id = "Sword", Metadata = { Rarity = "Common" } })
			SharedCore.addToBackpack(state, { Id = "Axe", Metadata = { Rarity = "Legendary" } })
			SharedCore.addToBackpack(state, { Id = "Bow", Metadata = { Rarity = "Rare" } })
			SharedCore.sort(state)
			expect(state.Items[state.Storage[1]].Metadata.Rarity).toBe("Legendary")
			expect(state.Items[state.Storage[2]].Metadata.Rarity).toBe("Rare")
			expect(state.Items[state.Storage[3]].Metadata.Rarity).toBe("Common")
		end)
	end)
end
