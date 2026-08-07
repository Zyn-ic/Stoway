# Item Metadata on the Wire — Open-Ended Schema

How item metadata is transmitted between client and server over QuickNet, and
how it changed from a strict (closed) schema to an open dynamic dict.

---

## TL;DR

- Metadata is **always** `{ [string]: any }` at the storage layer (see
  `CoreStore/Types.luau` — `ItemMetadata`).
- On the wire it is sent as an **open dynamic dict** `{ [string]: any }`.
- Any consumer-defined custom field (tool attributes, stats, rarity, etc.)
  transmits automatically — **no schema edits needed ever**.
- On the client, read metadata values **by convention**, not by runtime
  type-checking.
- Only `ReplicatedStorage/StowayRemotes.luau` (the wire) is open. CoreStore
  storage logic is untouched.

---

## The problem (the old/naive way)

QuickNet schemas are generally *enumerative*: you list the fields and their
types. A strict metadata schema looks like:

```luau
local ItemMetadata = {
	Description = data.optional(data.String),
	Image = data.optional(data.String),
	IsGamepass = data.optional(data.Boolean),
	Rarity = data.optional(data.String),
	Droppable = data.optional(data.Boolean),
	Type = data.optional(data.String),
}
```

This serializes a **fixed set** of fields into fixed buffer offsets. Any key
**not** in the schema has no type-code, so QuickNet silently **does not send
it**. Because items may carry arbitrary custom metadata (e.g. `FireDmg`,
`Enchant`, `Skill`, or anything read from a tool's attributes), the strict form
forced a new line in the schema **every time** you added a custom field:

```luau
local ItemMetadata2 = {
	-- ...the six built-ins...
	FireDmg = data.optional(data.NumberU16),   -- hand-declared
	Enchant = data.optional(data.String),      -- hand-declared
}
```

This is brittle and annoying — exactly the friction a `[string]: any` metadata
contract was trying to avoid.

---

## The fix (how we do it now)

QuickNet supports dynamic dicts that carry their own **type-tag per value**
(`Serialize.luau` — `getDataType`, `encodeAny`, `encodeDict`). We use that so
metadata stays fully open on the wire:

```luau
-- StowayRemotes.luau — ONE definition covers every metadata payload.
local MetadataSchema = { [data.String]: data.any }
```

The six built-in fields remain a **documented reference only** — they are a
naming convention, not enforced wire fields:

```luau
--   Description (string)   Image (string)     IsGamepass (boolean)
--   Rarity (string)        Droppable (bool)   Type (string)
```

### Before vs. after

| | Old (strict) | New (open, current) |
|---|---|---|
| Declare custom fields | Required — one per field | Never |
| Unlisted key behavior | Silently dropped on the wire | Transmitted intact |
| Value typing on receive | Strong, per-field | `any` (per-value tag preserved) |
| Wire cost | Fixed offsets, fast paths | Type-tag byte per value (slightly larger/slower) |
| Schema shape | `dictStatic` | `dict` / `Any` |

---

## Example

A tool in-world carries attributes `Rarity`, `Damage`, `FireDmg`, `Skill`. The
client reads its attributes and sends an `AddItem` — **no schema edits**:

```luau
local attrs = {}
for k, v in pairs(tool:GetAttributes()) do
	attrs[k] = v
end

StowayRemotes.AddItem:FireServer({
	Id = "MagicSword",
	Metadata = attrs,   -- Rarity, Damage, FireDmg, Skill all transmitted
})
```

The server adds it and replicates it back via `InventoryAdded`, with every
metadata key intact:

```luau
Remotes.InventoryAdded:FireClient(player, {
	uuid = added.uuid,
	slotType = added.slotType,
	slot = added.slot,
	Metadata = item.Metadata,
})
```

Because each value carries its own type-tag byte, `FireDmg = 25` arrives as a
number and `Skill = "Flaming"` as a string — types survive the round-trip.

---

## Deleting a field

Lua tables cannot hold a nil value, so `{ Enchant = nil }` is an **empty**
table and deletes nothing. Setting a metadata key to the `"__STOWAY_DELETE__"`
sentinel removes it on the server.

```luau
StowayRemotes.UpdateMetadata:FireServer(
	uuid,
	{ Enchant = StowayRemotes.METADATA_DELETE }
)
-- Server: CoreStore.updateMetadata(state, uuid, { Enchant = METADATA_DELETE })
-- -> item.Metadata.Enchant == nil
```

The sentinel is a namespaced string, so it serializes through QuickNet's
`data.any` payload with no wire-schema changes. Both sides reference the same
constant from `StowayRemotes.luau`.

---

## Client-side guidelines (no runtime checks)

On the client, metadata arrives as `any`. Follow these conventions instead of
running runtime type-checks:

```lua
local meta = item.Metadata

local fireDmg  = meta.FireDmg   -- any: a number when present
local rarity   = meta.Rarity    -- any: one of the Rarity strings
local enchant  = meta.Enchant   -- any: a string
```

- Use `if v == nil` to test presence, not `type(v)`.
- Trust the **naming convention**: `Rarity` is a string, `Droppable` a boolean,
  `Type` a string — code against that assumption.
- If you need a specific type guarantee, `if type(v) == "number" then ... end`
  is the only place a check belongs (e.g., before math), but do not sprinkle
  checks over every read.
- Custom fields are yours to name and document for your own game; there is no
  enforced registry on the wire.

---

## Querying custom metadata (server-side reference)

Open metadata does not change how CoreStore indexes it:

- Only **Rarity** and **Type** are reverse-indexed into `MetadataIndex`
  (O(1) bucket lookups) via `INDEXED_METADATA_FIELDS` in
  `CoreStore/Operations.luau`.
- Custom fields are not indexed by default. Query via a predicate:

```luau
local fiery = CoreStore.filter(state, function(item)
	return (item.Metadata.Enchant or "") == "Fire"
end)
```

- Custom fields are stored **verbatim** in `Item.Metadata`; they are not
  dropped unless they collide with the reserved keys `Amount` / `StackAmount`
  (which CoreStore consumes as the stack amount).

---

## Scope

| Layer | Changed? |
|---|---|
| `ReplicatedStorage/StowayRemotes.luau` (wire schema) | Yes — open dict |
| `CoreStore/Types.luau` (`ItemMetadata`) | No — already `[string]: any` |
| CoreStore storage / communication adapter | No |
| Data persistence surfaces | No |