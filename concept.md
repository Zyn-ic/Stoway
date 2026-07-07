## StowayServerV3_0_0 — Orchestration Layer

### What It Is

The glue between CoreStore (pure Luau engine) and the Roblox-specific layers (Communications, World, Client). Handles player lifecycle, operation routing, anti-exploit, and result dispatching.

### Module Structure

```
StowayServerV3_0_0/
├── init.luau           Orchestration layer (player store, locking, dispatching, routing)
├── Communications.luau Network adapter (sends/receives via NetworkService)
└── CoreStore/          Pure Luau inventory engine (10 modules)
    ├── init.luau       Public API facade
    ├── Types.luau      Type exports
    ├── Utils.luau      Utility functions
    ├── State.luau      State creation, weight, capacity
    ├── Metadata.luau   Input normalization, blacklisting
    ├── Stack.luau      Stacking logic
    ├── Slots.luau      Hotbar/storage slot operations
    ├── Operations.luau Core mutation logic
    ├── Query.luau      Item lookups
    └── (no file — in-memory only)
```

Luau CLI resolves `require` paths from the entry script directory, not the requiring module. All cross-module requires use `.luaurc` aliases (`@CoreStore`, `@Stoway`) to bypass this quirk and work identically in both CLI and luau-lsp.

### Require Aliases

Defined in root `.luaurc`:

```json
{
  "aliases": {
    "CoreStore": "./src/server/StowayServerV3_0_0/CoreStore",
    "Stoway": "./src/server/StowayServerV3_0_0"
  }
}
```

Usage:

```luau
local Types = require("@CoreStore/Types")      -- from any module
local CoreStore = require("@CoreStore")         -- from test files
local Stoway = require("@Stoway")               -- from test files
```

### Public API

```luau
-- Init (inject CoreStore dependency)
Stoway.Init(CoreStore)

-- Player lifecycle
Stoway.createPlayer(player, settingsOverrides?) → InventoryState
Stoway.get(player) → InventoryState?
Stoway.removePlayer(player) → InventoryState?
Stoway.getAll() → { [Player]: InventoryState }

-- Adapter registration
Stoway.registerAdapter(adapter: (player, operation, result) → ())

-- Operation routes (each: lock → CoreStore op → dispatch → unlock)
Stoway.AddItem(player, itemData, options?) → AddResult
Stoway.AddToBackpack(player, itemData, options?) → AddResult
Stoway.AddToHotbar(player, itemData, slot?) → AddResult
Stoway.RemoveItem(player, uuid, amount?) → RemoveResult
Stoway.SwapSlots(player, fromRef, toRef) → SwapResult
Stoway.Move(player, fromRef, toRef) → MoveResult
Stoway.Split(player, uuid, amount, destination?) → SplitResult
Stoway.EquipSlot(player, uuid) → EquipResult
Stoway.UnequipSlot(player) → UnequipResult
Stoway.UpdateMetadata(player, uuid, updates) → MetadataUpdateResult
Stoway.Sort(player) → SortResult
```

### Data Flow

```
Client fires RemoteEvent (via NetworkService)
    ↓
Communications translates → Stoway operation route
    ↓
Stoway.Route (lock → CoreStore → dispatch → unlock)
    ↓
    ├──→ Communications adapter (sends to client via NetworkService)
    ├──→ WorldAdapter (spawns/despawns Tools) — future
    └──→ (future: DataStore adapter)
```

### Anti-Exploit

- One active operation per player
- 3-second auto-timeout to prevent stuck locks
- Concurrent operations return `{ success = false, reason = "OPERATION_IN_PROGRESS" }`

### What's Intentionally NOT Here

| Concern | Where it lives |
|---|---|
| RemoteEvent creation | NetworkService (QuickNet) |
| Client payload formatting | Communications (uses NetworkService) |
| Table replication | NetworkService (RemoteTable-Light) |
| Tool spawning/despawning | World layer |
| DataStore save/load | Future adapter |
| Starter items | External caller |
| Debug commands | Separate module |

### How Other Layers Attach

**Loader mode** (NetworkService loaded by module loader):

```lua
-- NetworkService.Init wires Communications internally
-- Communications registers itself as Stoway adapter
NetworkService.Init(Stoway)
```

**Standalone mode** (separate server scripts):

```lua
local Stoway = require(ServerScriptService.Server.StowayServerV3_0_0)
local CoreStore = require(ServerScriptService.Server.CoreStore)
Stoway.Init(CoreStore)

-- NetworkService creates Communications and registers adapter
-- Communications uses NetworkService for all send/receive
```

### CoreStore Additions

This branch added `equip()` and `unequip()` to CoreStore:

```luau
CoreStore.equip(state, uuid) → EquipResult
CoreStore.unequip(state) → UnequipResult
```

Both are pure state changes. Auto-unequip on `remove()` and `swap` with StackOnSwap already existed.

### What Comes After This Branch

```
NetworkService   — QuickNet + RTL integration, Communications wiring
World Layer      — Tool spawning, equipping, dropping, ItemSpawner
Client Layer     — UI rendering, drag-and-drop, hotbar visuals
PreBranch        — combines all layers for integration testing
```

### Mental Model

```
CoreStore = the engine (pure Luau, no Roblox)
StowayServerV3_0_0 = the driver (connects engine to Roblox)
Communications = the translator (inventory ops ↔ network messages)
NetworkService = the wire (QuickNet + RTL, raw send/receive)
World Layer = the hands (physical world interaction)
Client Layer = the eyes (visual display)
```
