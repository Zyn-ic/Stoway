--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Seeded mock inventory snapshot for running the client with no server
	round trip. Mirrors InventoryState exactly, so swapping this for a real
	NetworkReceiver payload later is a one-line change in init.luau.

	Includes one "Trinket" item deliberately outside Settings.Categories, to
	exercise StorageView's uncategorized-group fallback path (falls back to
	the raw type name, sorts after every known category).
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedTypes = require(ReplicatedStorage.Shared.Stoway.Types)
local Settings = require(ReplicatedStorage.Shared.Stoway.Settings)

local MockData = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function item(uuid: string, id: string, amount: number, rarity: string, itemType: string): SharedTypes.Item
	return {
		UUID = uuid,
		Id = id,
		Amount = amount,
		Metadata = {
			Description = `{id} - {rarity} {itemType}`,
			Image = "",
			IsGamepass = false,
			Rarity = rarity,
			Droppable = true,
			Type = itemType,
		},
	}
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function MockData.build(): SharedTypes.InventoryState
	local items: { [string]: SharedTypes.Item } = {
		["iron-sword-1"] = item("iron-sword-1", "IronSword", 1, "Rare", "Weapon"),
		["steel-dagger-1"] = item("steel-dagger-1", "SteelDagger", 1, "Common", "Weapon"),
		["fire-bow-1"] = item("fire-bow-1", "FireBow", 1, "Legendary", "Weapon"),
		["health-potion-1"] = item("health-potion-1", "HealthPotion", 3, "Common", "Consumable"),
		["health-potion-2"] = item("health-potion-2", "HealthPotion", 320, "Common", "Consumable"),
		["mana-potion-1"] = item("mana-potion-1", "ManaPotion", 2, "Uncommon", "Consumable"),
		["iron-ingot-1"] = item("iron-ingot-1", "IronIngot", 1300, "Common", "Material"),
		["leather-1"] = item("leather-1", "Leather", 12345, "Common", "Material"),
		["greatshield-1"] = item("greatshield-1", "Greatshield", 1, "Epic", "Armor"),
		["platehelm-1"] = item("platehelm-1", "PlateHelm", 1, "Rare", "Armor"),
		["mystery-charm-1"] = item("mystery-charm-1", "MysteryCharm", 1, "Special", "Trinket"),
	}

	return {
		Items = items,
		Hotbar = {
			[1] = "iron-sword-1",
			[2] = "health-potion-1",
			[3] = "fire-bow-1",
		},
		Storage = {
			"steel-dagger-1", "health-potion-2", "mana-potion-1",
			"iron-ingot-1", "leather-1", "greatshield-1", "platehelm-1",
			"mystery-charm-1",
		},
		EquippedItemUUID = "iron-sword-1",
		Weight = 22,
		Settings = Settings.getDefault(),
	}
end

-----------------------------
-- MAIN --
-----------------------------

return MockData
