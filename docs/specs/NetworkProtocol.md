# Network Protocol Specification

Describes the QuickNet event names, payloads, and validation rules for Stoway inventory networking.

---

## Event Naming Convention

- **Client → Server:** `"Inventory" + Verb` (e.g., `"InventorySwap"`)
- **Server → Client:** `"Inventory" + Noun` (e.g., `"InventoryAdded"`) or `"Inventory" + Description` (e.g., `"InventoryRollback"`, `"InventoryFullSync"`)

All events are fired via QuickNet. No raw RemoteEvents.

## Internal Routed Operations

`SwapStack` is a Stoway/adapter protocol operation that invokes
`CoreStore.swapStack`. It currently has no distinct client-to-server QuickNet
event; client networking remains limited to the events documented below.

---

## Client → Server Events

### InventorySwap

User drags item from one slot to another.

```luau
-- Client fires:
NetworkService:Send("InventorySwap", {
    from = { Container = "Hotbar", Slot = 3 },
    to = { Container = "Storage", Slot = 7 },
})

-- Server validates:
-- 1. from.Container is "Hotbar" or "Storage"
-- 2. from.Slot is within valid range for that container
-- 3. Same checks for to
-- 4. Items exist at both slots
-- 5. Swap is allowed (not swapping equipped item unless unequipping)
```

### InventoryMove

User moves item positionally (never stacks).

```luau
-- Client fires:
NetworkService:Send("InventoryMove", {
    from = { Container = "Hotbar", Slot = 3 },
    to = { Container = "Storage", Slot = 1 },
})

-- Server validates: same as SwapSlots (minus the stacking check)
```

### InventorySplit

User splits a stack.

```luau
-- Client fires:
NetworkService:Send("InventorySplit", {
    uuid = "abc-123",
    amount = 5,
    destination = { Container = "Storage", Slot = 3 }, -- optional
})

-- Server validates:
-- 1. UUID exists in player inventory
-- 2. 1 <= amount < item.Amount
-- 3. destination valid if provided
-- 4. item.CanStack = true
```

### InventorySort

User clicks sort button.

```luau
-- Client fires:
NetworkService:Send("InventorySort")

-- Server validates:
-- 1. Settings.Sorting = true
```

### InventoryEquip

User equips an item.

```luau
-- Client fires:
NetworkService:Send("InventoryEquip", {
    uuid = "abc-123",
})

-- Server validates:
-- 1. UUID exists in inventory
-- 2. Not already equipped
```

### InventoryUnequip

User unequips current item.

```luau
-- Client fires:
NetworkService:Send("InventoryUnequip")

-- Server validates:
-- 1. Something is equipped (state.EquippedItemUUID ~= nil)
```

### InventoryRemove

User drops an item.

```luau
-- Client fires:
NetworkService:Send("InventoryRemove", {
    uuid = "abc-123",
    amount = 1, -- optional, defaults to full
})

-- Server validates:
-- 1. UUID exists
-- 2. 1 <= amount <= item.Amount
-- NOTE: On failure, triggers FULL SYNC (client state unreliable)
```

### RequestInventorySync

Client requests full state (on join or desync).

```luau
-- Client fires:
NetworkService:Send("RequestInventorySync")

-- Server responds:
NetworkService:SendToClient("InventoryFullSync", player, state)
```

---

## Server → Client Events

### InventoryAdded

Server adds an item (loot, admin, system).

```luau
-- Server sends:
NetworkService:SendToClient("InventoryAdded", player, {
    uuid = "abc-123",
    item = { -- full item data
        UUID = "abc-123",
        ItemId = "Sword",
        Amount = 1,
        Rarity = "Rare",
        Type = "Weapon",
        -- ... other metadata
    },
    slotType = "Hotbar", -- or "Storage"
    slot = 3,
})
```

### InventoryRemoved

Server removes an item (admin, system).

```luau
-- Server sends:
NetworkService:SendToClient("InventoryRemoved", player, {
    uuid = "abc-123",
    slotType = "Hotbar",
    slot = 3,
})
```

### InventoryUpdated

Server updates item metadata or amount.

```luau
-- Server sends:
NetworkService:SendToClient("InventoryUpdated", player, {
    uuid = "abc-123",
    updates = { Amount = 5 }, -- or metadata changes
})
```

### InventoryEquipped

Server equips an item (admin, system).

```luau
-- Server sends:
NetworkService:SendToClient("InventoryEquipped", player, {
    uuid = "abc-123",
})
```

### InventoryUnequipped

Server unequips an item (admin, system).

```luau
-- Server sends:
NetworkService:SendToClient("InventoryUnequipped", player, {
    uuid = "abc-123", -- previously equipped item
})
```

### InventoryRollback

Server sends targeted rollback on client failure.

```luau
-- Server sends:
NetworkService:SendToClient("InventoryRollback", player, {
    reason = "INVALID_SLOT",
    rollback = {
        hotbar = { [3] = itemA },      -- only affected slots
        storage = { [7] = itemB },     -- only affected slots
        items = { ["uuid-a"] = itemA, ["uuid-b"] = itemB }, -- only affected items
    },
})
```

**Client behavior:** Replace only the referenced keys in local cache. Unmentioned keys remain untouched.

### InventoryFullSync

Server sends complete state (join, desync, RemoveItem failure).

```luau
-- Server sends:
NetworkService:SendToClient("InventoryFullSync", player, {
    Items = state.Items,
    ItemsByID = state.ItemsByID,
    Hotbar = state.Hotbar,
    Storage = state.Storage,
    LocationByUUID = state.LocationByUUID,
    EquippedItemUUID = state.EquippedItemUUID,
    Weight = state.Weight,
    Settings = state.Settings,
})
```

**Client behavior:** Replace entire local cache. Trigger full UI rebuild.

---

## Slot Reference Format

```luau
type SlotRef = {
    Container: "Hotbar" | "Storage",
    Slot: number,
}
```

**Validation:**
- Hotbar + Static: `1 <= Slot <= MaxHotbarSlots`
- Hotbar + Dynamic: `1 <= Slot <= #hotbar`
- Storage: `1 <= Slot <= #storage`

---

## Error Reasons

| Reason | When |
|---|---|
| `OPERATION_IN_PROGRESS` | Lock held by another operation |
| `NO_STATE` | Player has no inventory state |
| `OPERATION_FAILED` | CoreStore threw an error |
| `INVALID_SLOT` | Slot reference out of range or nonexistent |
| `ITEM_NOT_FOUND` | UUID not in inventory |
| `SWAP_NOT_ALLOWED` | Swap violates rules (equipped item, etc.) |
| `SORT_DISABLED` | Settings.Sorting = false |
| `ALREADY_EQUIPPED` | Item is already equipped |
| `NOTHING_EQUIPPED` | No item is equipped |
| `UNAUTHORIZED` | Client fired server-only event |
