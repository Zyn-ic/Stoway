# Settings

Engine settings steer behavior; the client mirrors them into atoms. Two
default sets exist — know which one players get.

## The two defaults

Players get `Shared/Stoway/Settings.luau` (Dynamic hotbar, stacking off,
backpack off, Jailbreak). `CoreStore/State.luau` holds engine fallbacks
(Static, stacking on, backpack on). `createPlayer` maps the shared set onto
the engine explicitly (`defaultOverrides`); explicit caller overrides win.

## Every setting

| Setting | Does | Structural? |
|---|---|---|
| `HotbarType` | `Static` holes vs `Dynamic` packed (auto-compacts) | Yes — stale values fork prediction |
| `MaxHotbarSlots` | Hotbar size (10) | Yes |
| `Limit` | Total capacity (15, 0 = infinite) | Yes |
| `CanStack` | Merging allowed at all | Yes |
| `MaxStackSize` | Cap per stack (5), enforced unconditionally | Yes |
| `BackpackEnabled` | Storage usable | Yes |
| `StackOnSwap` | Swap absorbs (move never does) | Yes |
| `StackRequiredFields` | Identity for merging (`Rarity`, `Type`) | Yes |
| `StackBlacklist` | Rarities that never stack | Yes |
| `Sorting` / `SortOrder` | Auto-sort Storage (`None`/`Name`/`Rarity`/`ItemType`, rarity descending) | No (order-only) |
| `DebugLogs` | System print/warn output on/off (default on; hooks and console output stay on their own paths) | No (diagnostic-only) |

Structural settings must match on both copies or client prediction diverges
from server decisions.

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
