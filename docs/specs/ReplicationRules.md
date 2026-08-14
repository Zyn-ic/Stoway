# Replication Rules Specification

Defines how Stoway decides whether to send data back to the client, how origin is tracked, and what rollback looks like.

---

## Core Principle

**One source of truth.** The server's `InventoryState` is the only canonical state. The client maintains a local cache that mirrors it. Replication is the process of keeping the client cache in sync with the server.

**No ping-pong.** The client never fires events in response to server events. Server events are read-only for the client. This breaks the recursive loop by design.

---

## Origin Tracking

Communications tracks whether each operation was initiated by:

1. **Client** — QuickNet event from a player (user action)
2. **Server** — Direct function call (admin, system, loot, DataStore load)

### How origin is tracked

```luau
-- In Communications, QuickNet handlers set a context flag:
local _origin: "client" | "server" = "server" -- default

-- QuickNet handler:
NetworkService:On("InventorySwap", function(player, payload)
    _origin = "client"
    -- validate, execute, decide replicate
end)

-- Server-initiated calls:
function Communications.AddItem(player, itemData)
    _origin = "server"
    -- execute, decide replicate
end
```

Alternatively, pass origin as a parameter to the adapter callback:

```luau
type Adapter = (Player, string, any, "client" | "server") -> ()
```

---

## Replicate Decision Matrix

| Origin | Result | Send to client? | What to send |
|---|---|---|---|
| Client | Success | **No** | Nothing |
| Client | Failure | **Yes** | `InventoryRollback` (targeted) |
| Client | RemoveItem failure | **Full sync** | `InventoryFullSync` |
| Server | Success | **Yes, only if `replicate = true`** | Operation-specific event |
| Server | Failure | **No** | Nothing |

### Replication is opt-in

Every Stoway operation route takes a `replicate` flag. `nil` (omitted) means **no** replication; pass `true` explicitly to echo a server-side change to a client. Passing `false` is equivalent to omitting it. Server-side admin commands that want clients to see the change must opt in.

### Why client-success sends nothing

The client applies the operation locally (optimistic update) before sending to the server. If the server accepts it, both sides are already in sync. Sending the result back would:

1. Cause the client to apply the same operation twice (double-swap)
2. Create a ping-pong loop if the client responds to the server event

### Why client-failure sends targeted rollback

The client's optimistic update was wrong. It needs to revert only the affected slots. Sending the full inventory would be wasteful during peak combat or high traffic.

### Why RemoveItem failure triggers full sync

If the client tries to remove an item that doesn't exist, the client's local state is unreliable. It could be an attack (fabricated UUID) or a desync (server removed the item, client didn't know). A full sync ensures consistency.

---

## Client-Side Behavior

### On success (no event received)

The client already applied the operation locally. Nothing to do. The absence of a rollback event is implicit confirmation.

### On InventoryRollback

```luau
NetworkService:On("InventoryRollback", function(payload)
    local reason = payload.reason
    local rollback = payload.rollback

    -- Replace only referenced keys in local cache
    if rollback.hotbar then
        for slot, item in rollback.hotbar do
            localCache.Hotbar[slot] = item
        end
    end

    if rollback.storage then
        for slot, item in rollback.storage do
            localCache.Storage[slot] = item
        end
    end

    if rollback.items then
        for uuid, item in rollback.items do
            localCache.Items[uuid] = item
        end
    end

    -- Fire UI update signal
    InventoryChanged:Fire()
end)
```

### On InventoryFullSync

```luau
NetworkService:On("InventoryFullSync", function(payload)
    -- Replace entire local cache
    localCache.Items = payload.Items
    localCache.ItemsByID = payload.ItemsByID
    localCache.Hotbar = payload.Hotbar
    localCache.Storage = payload.Storage
    localCache.LocationByUUID = payload.LocationByUUID
    localCache.EquippedItemUUID = payload.EquippedItemUUID
    localCache.Weight = payload.Weight
    localCache.Settings = payload.Settings

    -- Full UI rebuild
    InventoryChanged:Fire()
end)
```

### On server-initiated events (Added, Removed, Updated, Equipped, Unequipped)

```luau
NetworkService:On("InventoryAdded", function(payload)
    -- Apply add to local cache using CoreStore
    CoreStore.add(localCache, payload.item, {
        preferredSlot = { Container = payload.slotType, Slot = payload.slot },
    })
    InventoryChanged:Fire()
end)

NetworkService:On("InventoryRemoved", function(payload)
    CoreStore.remove(localCache, payload.uuid)
    InventoryChanged:Fire()
end)

-- ... similar for Updated, Equipped, Unequipped
```

**Client does NOT fire any event back.** This prevents ping-pong.

---

## Rollback Format

Targeted rollback contains only the affected data:

```luau
{
    reason: string,           -- error reason code
    rollback: {
        hotbar: { [number]: Item? },  -- only affected hotbar slots
        storage: { [number]: Item? }, -- only affected storage slots
        items: { [string]: Item? },   -- only affected items by UUID
    },
}
```

### What goes in rollback

| Operation | hotbar | storage | items |
|---|---|---|---|
| SwapSlots | Both slot values | Both slot values | Both items |
| SwapStack | Both slot values | Both slot values | Both items |
| Move | Source + dest slot values | Source + dest slot values | Moved item |
| Split | Source slot + dest slot | Source slot + dest slot | Source item + new item |
| Sort | Full hotbar (if hotbar sorted) | — | — |
| EquipSlot | Slot that held the item | — | The item |
| UnequipSlot | — | — | The item |
| RemoveItem | — | — | **Full sync instead** |

### What does NOT go in rollback

- `LocationByUUID` — derived from hotbar/storage, client can reconstruct
- `ItemsByID` — derived from Items, client can reconstruct
- `Weight` — derived from items, client can reconstruct
- `Settings` — never changes from client operations

---

## Ping-Pong Prevention

### Rule

The client **never** fires events in response to server events. Server events are read-only.

### Enforcement

1. **Code discipline:** Client event handlers (for `InventoryAdded`, `InventoryRemoved`, etc.) only update the local cache and fire UI signals. They never call `NetworkService:Send()`.

2. **No auto-sync requests:** The client only fires `"RequestInventorySync"` on join or when explicitly triggered by user action (e.g., "refresh" button). It never fires it in response to other server events.

3. **QuickNet rate limiting:** Built-in rate limiting prevents rapid-fire events. Max 10 client operations per second per player.

### What breaks the loop

```
Client fires "InventorySwap"
  → Server processes → success
  → Server sends NOTHING back
  → Done (no loop)

Client fires "InventorySwap"
  → Server processes → failure
  → Server sends "InventoryRollback"
  → Client reverts local cache
  → Client does NOT fire any event
  → Done (no loop)

Server (admin) adds item
  → Server sends "InventoryAdded"
  → Client applies to local cache
  → Client does NOT fire any event
  → Done (no loop)
```

---

## Full Sync Triggers

Full sync (`InventoryFullSync`) is sent in these cases:

1. **Player join** — client requests via `"RequestInventorySync"`
2. **Desync detected** — client requests via `"RequestInventorySync"`
3. **RemoveItem failure** — client state unreliable, server forces full sync
4. **Manual refresh** — user clicks "refresh inventory" button

Full sync replaces the entire client cache. It is expensive (sends full state) and should be used sparingly.

---

## Optimistic Update Flow

```
1. User performs action (drag, click)
2. StowayClient applies operation to local cache (using CoreStore)
3. StowayClient fires QuickNet event to server
4. Server validates → executes → decides replicate

  4a. Success + client origin → no event sent → client keeps optimistic state
  4b. Failure + client origin → "InventoryRollback" sent → client reverts
  4c. Success + server origin → operation event sent → client applies
  4d. Failure + server origin → nothing changed → no event sent
```

### Why optimistic updates feel responsive

The UI updates immediately on step 2, before the server responds. The user sees the result instantly. If the server rejects it (step 4b), the client reverts — but this is rare for valid operations.

### Rollback cost

Rollback is cheap: 2-4 items instead of the full inventory. The client replaces only the referenced keys in its local cache. UI updates are minimal (only affected slots re-render).
