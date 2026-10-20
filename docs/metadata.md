# Metadata

Metadata is the whole game. Four systems read the same open
`{ [string]: MetadataValue? }` dict: the **index** (O(1) find), **stacking
identity** (required fields), **visual contracts** (rarity/type/team/image),
and **showcase features** (cooldowns, locks, glow). Learn the dict and you can
extend Stoway without touching the engine.

## Canon keys

| Key | Type | Read by |
|-----|------|---------|
| `Rarity` | string | Stacking blacklist + required field, rarity sort (descending), rarity frame tint, O(1) index |
| `Type` | string | Required field, storage section key, O(1) index |
| `Image` | string | Slot button image (empty → `Id` fallback text) |
| `Description` | string | Storage search only |
| `Droppable` | boolean | `Drop` route (`false` → `NOT_DROPPABLE`), defaults from `DefaultDroppable` (true when unset) |
| `IsGamepass` | boolean | Reserved open key |
| `Team` | string | Slot ring + keybind tint (`Colors.getTeamColor`); `set-team` stamps it |
| `Id` / `Amount` | top-level | Fallback label / stack badge (not metadata) |

Plus two engine-level rules: `updateMetadata` merges keys and never
re-stacks; deleting a key needs the `CoreStore.METADATA_DELETE` sentinel
(`{ Key = nil }` is an empty table, not a deletion).

## Showcase keys (example branches)

| Keys | Idea |
|------|------|
| `Cooldown` + `FireOnEquip` / server-stamped `CooldownEnd` | [Cooldowns](examples/cooldowns.md): skills on metadata |
| `UnlocksHotbarSlot` + `Settings.LockedHotbarSlots` | [Locked Slots](examples/locked-slots.md): consume-to-unlock |
| `IsNew` (client-ephemera, server strips silently) | [New-Item Glow](examples/new-item-glow.md): first-seen shine |

Each works because the engine treats unknown keys as inert payload: features
add gates, stamps, and reads *around* `Operations`, never inside it.

## Wire note

Metadata crosses the wire as an open string map. Canon does not filter it:
client `AddItem` / `AddToBackpack` / `AddToHotbar` / `UpdateMetadata`
payloads reach the routes unfiltered — see the [trust model](trust.md)
before relying on any metadata-driven rule. FullSync carries full metadata,
so anything the server stamps eventually converges everywhere.
