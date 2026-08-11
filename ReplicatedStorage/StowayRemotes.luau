local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuickNet = require(ReplicatedStorage.Packages.QuickNet)
local data = QuickNet.Data

local SlotChange = { uuid = data.String, slotType = data.optional(data.String), slot = data.optional(data.NumberU8) }
local Updated = { uuid = data.String, newAmount = data.NumberU32 }
-- QuickNet limitation: a single-key named table parses as a uniform dict
-- {[type]=type} and fails register(). Static dicts need >=2 named fields.
local EquippedPayload = {
	uuid = data.optional(data.String),
	previousUUID = data.optional(data.String),
}
local RevertPayload = { success = data.Boolean, fromSlot = data.optional(data.String) }

local SlotRef = { Type = data.String, Slot = data.NumberU8 }

-- METADATA WIRE SCHEMA (open-ended)
-- -----------------------------
-- Metadata is { [string]: any } (see CoreStore/Types.luau). On the wire we
-- send it as an OPEN dynamic dict, so ANY consumer-defined field transmits
-- automatically. Tool attributes, custom stats, rarity, anything — no schema
-- edits needed.
--
-- CORE metadata fields (documented reference only — NOT enforced on the wire):
--   Description (string)   Image (string)     IsGamepass (boolean)
--   Rarity (string)        Droppable (bool)   Type (string)
-- On the client, read these by trusting the naming convention; do NOT runtime
-- type-check. Every value arrives as `any` and carries its own type-tag byte,
-- so numbers stay numbers and strings stay strings through the round-trip.
local MetadataSchema = { [data.String] = data.any }

local ItemInput = {
	Id = data.optional(data.StringLong),
	Amount = data.optional(data.NumberU32),
	Metadata = data.optional(MetadataSchema),
}

local AddOptions = {
	Placement = data.optional(data.String),
	Slot = data.optional(data.NumberU8),
	SlotRef = data.optional(SlotRef),
}

local ClientPayloads = {
	AddItem = { ItemInput, data.optional(AddOptions) },
	AddToBackpack = { ItemInput, data.optional(AddOptions) },
	AddToHotbar = { ItemInput, data.optional(data.NumberU8) },
	RemoveItem = { data.StringLong, data.optional(data.NumberU32) },
	SwapSlots = { SlotRef, SlotRef },
	Move = { SlotRef, SlotRef },
	Split = { data.StringLong, data.NumberU32, data.optional(SlotRef) },
	EquipSlot = { data.StringLong },
	UnequipSlot = {},
	UpdateMetadata = { data.StringLong, data.any },
	Sort = {},
}

return {
	METADATA_DELETE = "__STOWAY_DELETE__",
	InventoryAdded = QuickNet:register("InventoryAdded", SlotChange),
	InventoryUpdated = QuickNet:register("InventoryUpdated", Updated),
	InventoryRemoved = QuickNet:register("InventoryRemoved", SlotChange),
	InventoryEquipped = QuickNet:register("InventoryEquipped", EquippedPayload),
	InventoryUnequipped = QuickNet:register("InventoryUnequipped", EquippedPayload),
	InventoryRevert = QuickNet:register("InventoryRevert", RevertPayload),
}
