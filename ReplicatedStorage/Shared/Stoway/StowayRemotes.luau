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
local LayoutChangedPayload = { layout = data.String, skin = data.String }

local SlotRef = { Type = data.String, Slot = data.NumberU8 }

-- METADATA WIRE SCHEMA (open-ended)
-- -----------------------------
-- Metadata is { [string]: string | number | boolean } (see CoreStore/Types.luau). On the wire we
-- send it as an OPEN dynamic dict, so ANY consumer-defined field transmits
-- automatically. Tool attributes, custom stats, rarity, anything — no schema
-- edits needed.
--
-- CORE metadata fields (documented reference only — NOT enforced on the wire):
--   Description (string)   Image (string)     IsGamepass (boolean)
--   Rarity (string)        Droppable (bool)   Type (string)
-- On the client, read these by trusting the naming convention; do NOT runtime
-- type-check. Every value arrives decoded from its own type-tag byte,
-- so numbers stay numbers and strings stay strings through the round-trip.
local MetadataSchema = { [data.String] = data.Any }

-- QUICKNET SINGLE-USE RULE (Parser.luau: processSchema mutates optional
-- wrappers in place: schema[2] = processed. The first register() of a
-- shared table succeeds; the second reprocesses the processed wrapper,
-- descends into dictStatic internals (keys/template/123s) and dies with
-- "invalid data type". Bare-enum optionals are idempotent and safe to
-- share; anything nesting a TABLE inside optional() is not. Hence fresh
-- tables per registration below. Never share these across register().
local function makeItemInput()
	return {
		Id = data.optional(data.StringLong),
		Amount = data.optional(data.NumberU32),
		Metadata = data.optional(MetadataSchema),
	}
end

-- Full item for server-originated adds: the client inserts verbatim at
-- the given slot (never re-creates — the server UUID is authoritative).
-- Key is Metadata (not ItemMetadata): dictStatic deserializes back into
-- these key names, and CoreStore reads item.Metadata.
local function makeItemData()
	return {
		UUID = data.StringLong,
		Id = data.optional(data.StringLong),
		Amount = data.optional(data.NumberU32),
		Metadata = data.optional(MetadataSchema),
	}
end
local AddedPayload = { uuid = data.String, slotType = data.optional(data.String), slot = data.optional(data.NumberU8), item = makeItemData() }

-- Full-state resync for ops with no targeted push (Swap/Move/Split/
-- Sort/UpdateMetadata). Slot dicts ({[slot] = uuid}) survive hotbar
-- holes; indexes stay server-side, the client rebuilds them.
local SlotDict = { [data.NumberU8] = data.String }
local ItemDict = { [data.String] = makeItemData() }
local FullSyncPayload = {
	Items = ItemDict,
	Hotbar = SlotDict,
	Storage = SlotDict,
	EquippedItemUUID = data.optional(data.String),
	Weight = data.optional(data.NumberU32),
}

local function makeAddOptions()
	return {
		Placement = data.optional(data.String),
		Slot = data.optional(data.NumberU8),
		SlotRef = data.optional(SlotRef),
	}
end

-- WIRE CONVENTION (QuickNet register/fire): register() takes schemas
-- vararg and Fire passes varargs positionally, BUT multi-value payloads
-- must be a SINGLE static-dict table per event — FireServer(a, b) against
-- schema {A, B} misaligns (proven live: "index nil with 'Slot'"). Every
-- request below is one named table; FireServer sends exactly one table.
-- No-arg events (Unequip/Sort) register with NO schema and fire bare.
local ClientPayloads = {
	AddItem = { input = makeItemInput(), options = data.optional(makeAddOptions()) },
	AddToBackpack = { input = makeItemInput(), options = data.optional(makeAddOptions()) },
	AddToHotbar = { input = makeItemInput(), preferredSlot = data.optional(data.NumberU8) },
	RemoveItem = { uuid = data.StringLong, amount = data.optional(data.NumberU32) },
	SwapSlots = { from = SlotRef, to = SlotRef },
	SwapStack = { from = SlotRef, to = SlotRef },
	Move = { from = SlotRef, to = SlotRef },
	Split = { uuid = data.StringLong, amount = data.NumberU32, dest = data.optional(SlotRef) },
	-- Single-key named tables are illegal (parse as uniform dicts): pad
	-- to two fields with an always-nil optional. Callers send {uuid}.
	EquipSlot = { uuid = data.StringLong, _pad = data.optional(data.Boolean) },
	Drop = { uuid = data.StringLong, amount = data.optional(data.NumberU32) },
	UpdateMetadata = { uuid = data.StringLong, updates = MetadataSchema },
}

return {
	METADATA_DELETE = "__STOWAY_DELETE__",
	InventoryAdded = QuickNet:register("InventoryAdded", AddedPayload),
	InventoryUpdated = QuickNet:register("InventoryUpdated", Updated),
	InventoryRemoved = QuickNet:register("InventoryRemoved", SlotChange),
	InventoryEquipped = QuickNet:register("InventoryEquipped", EquippedPayload),
	InventoryUnequipped = QuickNet:register("InventoryUnequipped", EquippedPayload),
	InventoryRevert = QuickNet:register("InventoryRevert", RevertPayload),
	InventoryFullSync = QuickNet:register("InventoryFullSync", FullSyncPayload),
	LayoutChanged = QuickNet:register("LayoutChanged", LayoutChangedPayload),
	-- Client -> server requests. Registered under operation names; the
	-- server branch listens on this same module, so names stay in sync
	-- by construction. FireServer with no listener is a silent no-op.
	AddItem = QuickNet:register("AddItem", ClientPayloads.AddItem),
	AddToBackpack = QuickNet:register("AddToBackpack", ClientPayloads.AddToBackpack),
	AddToHotbar = QuickNet:register("AddToHotbar", ClientPayloads.AddToHotbar),
	RemoveItem = QuickNet:register("RemoveItem", ClientPayloads.RemoveItem),
	SwapSlots = QuickNet:register("SwapSlots", ClientPayloads.SwapSlots),
	SwapStack = QuickNet:register("SwapStack", ClientPayloads.SwapStack),
	Move = QuickNet:register("Move", ClientPayloads.Move),
	Split = QuickNet:register("Split", ClientPayloads.Split),
	EquipSlot = QuickNet:register("EquipSlot", ClientPayloads.EquipSlot),
	-- No-arg events register with NO schema: {} is not a valid schema
	-- (processSchema rejects it). FireServer() sends zero args.
	UnequipSlot = QuickNet:register("UnequipSlot"),
	UpdateMetadata = QuickNet:register("UpdateMetadata", ClientPayloads.UpdateMetadata),
	Sort = QuickNet:register("Sort"),
	Drop = QuickNet:register("Drop", ClientPayloads.Drop),
	RequestInventorySync = QuickNet:register("RequestInventorySync"),
}
