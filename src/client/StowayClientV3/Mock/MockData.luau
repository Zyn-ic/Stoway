--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Mock inventory snapshot for local testing.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreTypes = require(ReplicatedStorage.Shared.Stoway.CoreStore.Types)

local MockData = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function item(uuid: string, id: string, amount: number, rarity: string, itemType: string): CoreTypes.Item
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

function MockData.build(): CoreTypes.InventoryState
	local items: { [string]: CoreTypes.Item } = {
		["iron-sword-1"] = item("iron-sword-1", "IronSword", 1, "Rare", "Weapon"),
		["steel-dagger-1"] = item("steel-dagger-1", "SteelDagger", 1, "Common", "Weapon"),
		["fire-bow-1"] = item("fire-bow-1", "FireBow", 1, "Legendary", "Weapon"),
		["health-potion-1"] = item("health-potion-1", "HealthPotion", 3, "Common", "Consumable"),
		["health-potion-2"] = item("health-potion-2", "HealthPotion", 320, "Common", "Consumable"),
		["health-potion-3"] = item("health-potion-3", "HealthPotion", 520, "Mythic", "Consumable"),
		["mana-potion-1"] = item("mana-potion-1", "ManaPotion", 2, "Uncommon", "Consumable"),
		["iron-ingot-1"] = item("iron-ingot-1", "IronIngot", 1300, "Common", "Material"),
		["leather-1"] = item("leather-1", "Leather", 12345, "Common", "Material"),
		["greatshield-1"] = item("greatshield-1", "Greatshield", 1, "Epic", "Armor"),
		["platehelm-1"] = item("platehelm-1", "PlateHelm", 1, "Rare", "Armor"),
		["mystery-charm-1"] = item("mystery-charm-1", "MysteryCharm", 1, "Special", "Trinket"),
	}

	local weight = 0
	for _, it in items do
		weight += it.Amount
	end

	local settings: CoreTypes.Settings = {
		HotbarType = "Static",
		MaxHotbarSlots = 10,
		Limit = 15000,
		CanStack = true,
		MaxStackSize = 5,
		BackpackEnabled = true,
		Sorting = false,
		SortOrder = "None",
		StackOnSwap = false,
		StackRequiredFields = { "Rarity", "Type" },
		StackBlacklist = { Legendary = true, Mythic = true, Special = true },
		DefaultDroppable = true,
	}

	local hotbar: { [number]: string? } = {
		[1] = "iron-sword-1",
		[2] = "health-potion-1",
		[3] = "fire-bow-1",
	}
	local storage: { string } = {
		"steel-dagger-1", "health-potion-2", "mana-potion-1",
		"iron-ingot-1", "leather-1", "greatshield-1", "platehelm-1",
		"mystery-charm-1", "health-potion-3"
	}

	-- Hydrate CoreStore indices so Slots.swapSlots (which writes
	-- state.LocationByUUID[uuid]) does not hit nil. Mock bypasses State.new()
	-- on purpose to keep large Amounts for formatAmount demo, so we build
	-- the derived tables by hand.
	local locationByUUID: { [string]: CoreTypes.SlotRef } = {}
	local itemsByID: { [string]: { string } } = {}
	local metadataIndex: { [string]: { [string]: { string } } } = {}

	for slot, uuid in hotbar do
		if uuid then locationByUUID[uuid] = { Type = "Hotbar", Slot = slot } end
	end
	for idx, uuid in storage do
		locationByUUID[uuid] = { Type = "Storage", Slot = idx }
	end
	for uuid, it in items do
		local byId = itemsByID[it.Id]
		if not byId then byId = {}; itemsByID[it.Id] = byId end
		table.insert(byId, uuid)
		for _, field in { "Rarity", "Type" } do
			local v = it.Metadata[field]
			if v ~= nil then
				local sv = tostring(v)
				local fieldTab = metadataIndex[field]
				if not fieldTab then fieldTab = {}; metadataIndex[field] = fieldTab end
				local bucket = fieldTab[sv]
				if not bucket then bucket = {}; fieldTab[sv] = bucket end
				table.insert(bucket, uuid)
			end
		end
	end

	return {
		Items = items,
		ItemsByID = itemsByID,
		Hotbar = hotbar,
		Storage = storage,
		LocationByUUID = locationByUUID,
		MetadataIndex = metadataIndex,
		EquippedItemUUID = "iron-sword-1",
		Weight = weight,
		Settings = settings,
	}
end

-----------------------------
-- MAIN --
-----------------------------

return MockData
