## StowayServerV3_0_0 — Orchestration Layer

### What It Is

The glue between CoreStore (pure Luau engine) and the Roblox-specific layers (Communications, World, Client). Handles player lifecycle, operation routing, anti-exploit, and result dispatching.

### Module Structure

```
src/server/
├── StowayServerV3_0_0/
│   ├── init.luau           Orchestration layer (player store, locking, dispatching, routing)
│   ├── Communications.luau Network adapter (QuickNet handlers, Stoway adapter, validation)
│   └── CoreStore/          Pure Luau inventory engine (10 modules)
│       ├── init.luau       Public API facade
│       ├── Types.luau      Type exports
│       ├── Utils.luau      Utility functions
│       ├── State.luau      State creation, weight, capacity
│       ├── Metadata.luau   Input normalization, blacklisting
│       ├── Stack.luau      Stacking logic
│       ├── Slots.luau      Hotbar/storage slot operations
│       ├── Operations.luau Core mutation logic
│       ├── Query.luau      Item lookups
│       └── (no file — in-memory only)

src/client/
└── StowayClient/
    ├── init.luau           Client entry point, event listeners, local cache
    └── CoreStore/          Client-side CoreStore copy (for local operations)
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
CLIENT-INITIATED (user action):
  Client fires QuickNet event
      ↓
  Communications validates request
      ↓
  Stoway.Route (lock → CoreStore → dispatch → unlock)
      ↓
  Communications adapter checks result:
      ├──→ Success: client already applied locally → NO EVENT SENT BACK
      └──→ Failure: send targeted rollback to client → client reverts

SERVER-INITIATED (admin, system, loot):
  Server calls Stoway operation directly
      ↓
  Stoway.Route (lock → CoreStore → dispatch → unlock)
      ↓
  Communications adapter checks result:
      ├──→ Success: send operation details to client
      └──→ Failure: nothing changed → NO EVENT SENT

DESYNC RECOVERY:
  Client fires "RequestInventorySync"
      ↓
  Server sends full InventoryState
      ↓
  Client replaces local cache
```

### Inventory Sync Strategy — QuickNet Only

Inventory state is **not** replicated via RemoteTable-Light. RTL creates a deep copy (proxy table) that must be manually kept in sync with Stoway's canonical state — doubling mutation work for compound operations. Instead, inventory uses QuickNet events exclusively.

**Why not RTL for inventory:**
- RTL deep-copies the template, creating two separate canonical tables
- Every Stoway mutation requires corresponding RTL mutation calls (e.g., swap = 4+ `RTL.Set` calls)
- Compound operations (swap, move, split) mutate multiple subtables simultaneously — easy to miss a path
- No atomic multi-path updates in RTL — individual `Set` calls batched on Heartbeat

**Why QuickNet works:**
- One source of truth: Stoway's canonical `InventoryState`
- Operation results are sent as events — client applies the same operation locally
- No proxy table, no mutation syncing, no path tracking
- Admin changes: call Stoway ops → events auto-send to client
- Rejoin/desync recovery: send full state dump via QuickNet

**Where RTL IS used:** PlayerData (Cash, Experience, Perks) — simple scalar mutations where RTL's `Set`/`Increment` are a perfect fit.

### Operation Ownership

| Operation | Client can initiate | Server can initiate | Notes |
|---|---|---|---|
| AddItem | No | Yes | Item pickup, loot, admin — client never creates items |
| AddToBackpack | No | Yes | Same as AddItem |
| AddToHotbar | No | Yes | Same as AddItem |
| RemoveItem | Yes (drop) | Yes (admin) | Client remove triggers desync recovery on failure |
| SwapSlots | Yes | Yes | Drag-and-drop or admin |
| Move | Yes | Yes | Position transfer |
| Split | Yes | Yes | Stack split |
| Sort | Yes | Yes | Sort button or admin sort |
| EquipSlot | Yes | Yes | Equip action or admin equip |
| UnequipSlot | Yes | Yes | Unequip action or admin unequip |
| UpdateMetadata | No | Yes | Rename, tag — client can't modify directly |

### Replicate Decision

Communications tracks **origin** — whether the operation was triggered by a client QuickNet event or a direct server call.

| Origin | Result | Send to client? | What to send |
|---|---|---|---|
| Client request | Success | **No** | Nothing — client already applied locally |
| Client request | Failure | **Yes** | Targeted rollback (affected slots/items only) |
| Server/Admin | Success | **Yes** | Operation details (what changed) |
| Server/Admin | Failure | **No** | Nothing — nothing changed |
| Client RemoveItem failure | — | **Full sync** | Client state is unreliable, send complete InventoryState |

**Why client-success sends nothing:** The client applies the operation locally (optimistic update) before sending to server. If the server accepts it, both sides are in sync. Sending the result back would cause a ping-pong loop.

**Why client-failure sends targeted rollback:** The client's optimistic update was wrong. It needs to revert only the affected slots, not the entire inventory. Rollback payload contains only the slots/items that were involved in the failed operation.

**Why RemoveItem failure triggers full sync:** If the client tries to remove an item that doesn't exist (attack or desync), the client's local state is unreliable. A full sync ensures consistency.

### Rollback Format

On client-originated failure, the server sends:

```luau
{
  success = false,
  reason = "INVALID_SLOT",       -- or "ITEM_NOT_FOUND", "SWAP_NOT_ALLOWED", etc.
  rollback = {
    hotbar = { [slot] = item },  -- only affected slots
    storage = { [slot] = item }, -- only affected slots
    items = { [uuid] = item },   -- only affected items
  }
}
```

The client replaces only the referenced keys in its local cache. Unmentioned keys remain untouched.

**Not full snapshot.** During peak combat or high traffic, sending the entire inventory for a failed swap is wasteful. Targeted rollback sends 2-4 items instead of potentially hundreds.

#### Inventory Event Flow

```
Client → Server (QuickNet events):
  "InventorySwap"      → Communications → Stoway.SwapSlots
  "InventoryMove"      → Communications → Stoway.Move
  "InventorySplit"     → Communications → Stoway.Split
  "InventorySort"      → Communications → Stoway.Sort
  "InventoryEquip"     → Communications → Stoway.EquipSlot
  "InventoryUnequip"   → Communications → Stoway.UnequipSlot
  "InventoryRemove"    → Communications → Stoway.RemoveItem (desync on failure)
  "RequestInventorySync" → Communications → sends full state

Server → Client (QuickNet events):
  "InventoryAdded"       — item added (admin/system)
  "InventoryRemoved"     — item removed (admin/system)
  "InventoryUpdated"     — metadata or amount changed (admin/system)
  "InventoryEquipped"    — item equipped (admin/system)
  "InventoryUnequipped"  — item unequipped (admin/system)
  "InventoryRollback"    — targeted rollback on client failure
  "InventoryFullSync"    — complete state (join/desync recovery)
```

**Client cannot fire:** `InventoryAdded`, `InventoryRemove` (server-only paths), `InventoryUpdated`, `InventoryEquipped`, `InventoryUnequipped`. These are server→client only.

#### Client-Side State — StowayClient

The client has its own module: `StowayClient`. It maintains a local `InventoryCache` and handles all server→client events.

```
StowayClient/
├── init.luau           Client entry point, event listeners, local cache
└── CoreStore/          Client-side CoreStore copy (for local operations)
```

**StowayClient responsibilities:**
1. On join: fire `"RequestInventorySync"` → receive `"InventoryFullSync"` → populate local cache
2. On `"InventoryAdded"`: apply add to local cache → update UI
3. On `"InventoryRemoved"`: apply remove to local cache → update UI
4. On `"InventoryUpdated"`: update item metadata/amount in local cache → update UI
5. On `"InventoryEquipped"` / `"InventoryUnequipped"`: update equipped state → update UI
6. On `"InventoryRollback"`: replace only referenced keys in local cache → update UI
7. On `"InventoryFullSync"`: replace entire local cache → full UI rebuild

**StowayClient does NOT:**
- Send events in response to server events (prevents ping-pong)
- Validate server data (server is authoritative)
- Maintain its own inventory logic (uses CoreStore for local operations)

**Optimistic updates:**
When the user performs an action (drag, click), StowayClient:
1. Applies the operation to its local cache immediately (using CoreStore)
2. Fires the corresponding QuickNet event to the server
3. If server responds with `"InventoryRollback"` → reverts the local cache
4. If no rollback received → operation succeeded (implicit confirmation)

### Anti-Exploit

**Concurrency:**
- One active operation per player
- 3-second auto-timeout to prevent stuck locks
- Concurrent operations return `{ success = false, reason = "OPERATION_IN_PROGRESS" }`

**Validation (server-side, before every client-initiated operation):**

| Operation | Validation checks |
|---|---|
| SwapSlots | Both slot refs valid; slots exist; items exist at both; swap allowed |
| Move | Both slot refs valid; slots exist; move allowed |
| Split | UUID exists; `1 <= amount < item.Amount`; destination valid if provided; CanStack = true |
| Sort | `Settings.Sorting = true` |
| EquipSlot | UUID exists; not already equipped; item in inventory |
| UnequipSlot | Something is equipped |
| RemoveItem | UUID exists; `1 <= amount <= item.Amount` |

**Slot reference validation:**
- `Container` must be `"Hotbar"` or `"Storage"`
- If Hotbar + Static: `1 <= slot <= MaxHotbarSlots`
- If Hotbar + Dynamic: `1 <= slot <= #hotbar`
- If Storage: `1 <= slot <= #storage`

**Unauthorized operations:**
- Client fires `"InventoryAdd"` → reject immediately (server-only)
- Client fires `"InventoryAddToBackpack"` → reject immediately
- Client fires `"InventoryAddToHotbar"` → reject immediately
- Client fires `"InventoryUpdateMetadata"` → reject immediately

**Rate limiting:**
- QuickNet built-in rate limiting
- Max 10 client operations per second per player
- Lock contention rejects additional requests

### What's Intentionally NOT Here

| Concern | Where it lives |
|---|---|
| RemoteEvent creation | NetworkService (QuickNet) |
| Client payload formatting | Communications (uses NetworkService) |
| Inventory replication | QuickNet events (no RTL proxy) |
| PlayerData replication | NetworkService (RemoteTable-Light) |
| Tool spawning/despawning | World layer |
| DataStore save/load | Future adapter |
| Starter items | External caller |
| Debug commands | Separate module |

### How Other Layers Attach

**Loader mode** (NetworkService loaded by module loader):

```lua
-- NetworkService.Init wires Communications internally
-- Communications registers itself as Stoway adapter
-- QuickNet events are already set up by NetworkService
NetworkService.Init(Stoway)
```

**Standalone mode** (separate server scripts):

```lua
local Stoway = require(ServerScriptService.Server.StowayServerV3_0_0)
local CoreStore = require(ServerScriptService.Server.CoreStore)
Stoway.Init(CoreStore)

-- NetworkService creates Communications and registers adapter
-- Communications listens for QuickNet inventory events
-- On player join: sends InventoryFullSync via QuickNet
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
NetworkService   — QuickNet events for inventory, RTL for PlayerData only
Communications   — event handlers, validation, Stoway adapter, replicate logic
StowayClient     — local cache, optimistic updates, event listeners, UI signals
World Layer      — Tool spawning, equipping, dropping, ItemSpawner
PreBranch        — combines all layers for integration testing
```

### Mental Model

```
CoreStore = the engine (pure Luau, no Roblox)
StowayServerV3_0_0 = the driver (connects engine to Roblox)
Communications = the gatekeeper (validation, replicate decisions, event routing)
StowayClient = the mirror (local cache, optimistic updates, UI bridge)
NetworkService = the wire (QuickNet for inventory, RTL for PlayerData)
World Layer = the hands (physical world interaction)
```
