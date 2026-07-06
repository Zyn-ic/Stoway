## StowayServerV3_0_0 — Orchestration Layer

### What It Is

The glue between CoreStore (pure Luau engine) and the Roblox-specific layers (Network, World, Client). Handles player lifecycle, operation routing, anti-exploit, and result dispatching.

### Module Structure

```
StowayServerV3_0_0/
└── init.luau    Everything in one module (player store, locking, dispatching, routing)
```

Luau CLI resolves `require` paths from the entry script directory, not the requiring module. This makes split modules with `../` paths impossible to test outside Roblox. The orchestration layer is kept as a single file for testability. In Roblox, this can be split into `PlayerRegistry`, `OperationGuard`, and `ResultDispatcher` submodules.

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
Client fires RemoteEvent
    ↓
Stoway.Route (lock → CoreStore → dispatch → unlock)
    ↓
    ├──→ NetworkAdapter (sends to client)
    ├──→ WorldAdapter (spawns/despawns Tools)
    └──→ (future: DataStore adapter)
```

### Anti-Exploit

- One active operation per player
- 3-second auto-timeout to prevent stuck locks
- Concurrent operations return `{ success = false, reason = "OPERATION_IN_PROGRESS" }`

### What's Intentionally NOT Here

| Concern | Where it lives |
|---|---|
| RemoteEvent creation | Network layer |
| Client payload formatting | Network layer |
| Tool spawning/despawning | World layer |
| DataStore save/load | Future adapter |
| Starter items | External caller |
| Debug commands | Separate module |

### How Other Layers Attach

```lua
local Stoway = require(ServerScriptService.Server.StowayServerV3_0_0)
local CoreStore = require(ServerScriptService.Server.CoreStore)

Stoway.Init(CoreStore)

-- Network layer:
Stoway.registerAdapter(function(player, operation, result)
    -- fire RemoteEvent to client
end)

-- World layer:
Stoway.registerAdapter(function(player, operation, result)
    if operation == "EquipSlot" then
        -- spawn Tool in character
    end
end)

-- External caller:
Stoway.Init(CoreStore)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        local state = Stoway.createPlayer(player)
        CoreStore.add(state, { Id = "Sword", Amount = 1 })
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    Stoway.removePlayer(player)
end)
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
Network Layer    — RemoteEvents, client payloads, delta replication
World Layer      — Tool spawning, equipping, dropping, ItemSpawner
Client Layer     — UI rendering, drag-and-drop, hotbar visuals
PreBranch        — combines all layers for integration testing
```

### Mental Model

```
CoreStore = the engine (pure Luau, no Roblox)
StowayServerV3_0_0 = the driver (connects engine to Roblox)
Network Layer = the dashboard (client communication)
World Layer = the hands (physical world interaction)
Client Layer = the eyes (visual display)
```
