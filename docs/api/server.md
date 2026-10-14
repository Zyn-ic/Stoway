# Server Routes & Wire

## Routes

`StowayServerV3_0_0/init.luau`: `Init(CoreStore)` injects the engine,
`createPlayer` / `get` / `removePlayer` manage per-player states, and 13
routes mutate through one locked `route()` (3s per-player lock, `pcall`
inside, adapters dispatched after).

| Route | Notes |
|-------|-------|
| `AddItem` / `AddToBackpack` / `AddToHotbar` | Template must exist (`ITEM_NOT_IN_TOOLS_FOLDER`); template attributes merge *under* caller metadata |
| `RemoveItem` | Partial or full |
| `SwapSlots` / `SwapStack` / `Move` / `Split` | Thin engine pass-through |
| `EquipSlot` | Clears character Tools, clones template, stamps attributes, parents to Character |
| `UnequipSlot` | Clears character Tools |
| `UpdateMetadata` | Engine merge/delete |
| `Sort` | Engine sort |
| `Drop` | Honors `Droppable`; reuses the equipped tool or clones; touch-stripped, tagged world drop 5 studs ahead |

`replicate` is opt-in everywhere: omitted means no echo.

## Replication

QuickNet events (`StowayRemotes` wire). Client ops run silent
(`replicate=false`) — the client already rendered them. Failures correct via
`FullSync`.

| Direction | Events |
|-----------|--------|
| Server → client deltas | `InventoryAdded` (full item, server UUID wins), `InventoryUpdated` (amount), `InventoryRemoved`, `InventoryEquipped` / `InventoryUnequipped` |
| Server → client wholesale | `InventoryFullSync` (items + slots + equipped + weight + full settings backstop) for swap/move/split/metadata/sort and every failure |
| Server → client revert | `InventoryRevert` on failed swap/stack (log-only on receipt) |
| Client → server | One `FireServer` per op + bare `RequestInventorySync` (15s per-player throttle; every push stamps the cooldown so join races coalesce) |
| Settings / layout | Sparse `SettingsChanged` patch + `LayoutChanged`, both live-applied |

## Tools

Templates live in `ServerStorage.Tools`; attributes become metadata defaults
(`Description`, `Image`, `Droppable`, `IsGamepass`, `Rarity`, `Type`).
Equipped clones carry `UUID`/`Amount`/`Id`/metadata attributes. Drops are
tagged world Tools; `StowayPickup` watches the tag and prompts the pickup
back into `AddToBackpack`.
