# Settings

Engine settings steer behavior; the client mirrors them into atoms. Two
default sets exist — know which one players get.

## The two defaults

Players get `Shared/Stoway/Settings.luau` (Dynamic hotbar, merging off,
backpack on, `Default` skin on `StandardHotbarStorage`). `CoreStore/State.luau`
holds engine fallbacks (Static, merging on, backpack on). `createPlayer` maps
the shared set onto the engine explicitly (`defaultOverrides`); explicit caller
overrides win.

## Every setting

| Setting | What it does | Kind |
|---|---|---|
| `HotbarType` | `Static` keeps fixed slots (holes allowed); `Dynamic` packs and auto-compacts. | Structural |
| `MaxHotbarSlots` | Number of hotbar slots (`1..N`). | Structural |
| `Limit` | Total `Amount` capacity. `0` = unlimited. | Structural-lite |
| `CanStack` | Allows merging into existing stacks. Does not cap new stacks. | Structural |
| `MaxStackSize` | Max `Amount` per stack. Caps new stacks and splits; existing stacks are not re-split. | Structural |
| `BackpackEnabled` | Allows Storage. `false` rejects storage operations. | Structural-lite |
| `StackOnSwap` | Allows `swap`/`swapStack` to merge. Requires `CanStack`; `move` and `split` never merge. | Structural |
| `StackRequiredFields` | Metadata fields that must match before merging. | Structural |
| `StackBlacklist` | Rarity values that never merge into existing stacks. | Structural |
| `DefaultDroppable` | `Droppable` default for new items that omit it. | Structural-lite |
| `Sorting` | Auto-sorts Storage after every mutation. Hotbar is never sorted. | Cosmetic |
| `SortOrder` | Sort key: `None`, `Name`, `Rarity` (descending), or `ItemType`. | Cosmetic |
| `DebugLogs` | System print/warn output. Console and hooks use their own paths. | Cosmetic |

Structural settings must match on both copies or client prediction diverges
from server decisions. Structural-lite fields affect capacity, gating, or
new-item defaults. Cosmetic fields only misrender until the next update.

**Stacking trap:** `CanStack = false` blocks merges into existing stacks. It
is not `MaxStackSize = 1` — a single add still creates stacks up to
`MaxStackSize`, so `add apple 5` with the default cap produces one stack of
5. Set `MaxStackSize = 1` when you want one item per unit.

## Sync

Changes push sparsely as `SettingsChanged` patches; every `FullSync` carries
the full snapshot as backstop. The client overlays patches onto its mirror
state first, then fans out — never writes atoms directly.

## How to add a setting

Touch all of these or it silently won't replicate: the `Settings` and
`SettingsOverrides` type blocks, the `FullSyncPayload.Settings` shape, both
default tables, `defaultOverrides`, the FullSync projection, the
`SettingsChanged` and FullSync wire schemas, the client get/set pair, and
`ApplyServerSettings`.
