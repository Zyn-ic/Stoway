## What Is This Branch?

This branch is for rebuilding the inventory system around a pure Luau inventory core called `CoreStore`.

The goal is not to polish the old server code. The goal is to extract the useful inventory ideas from the previous Stoway server implementation and rebuild them as a clean, testable, framework-like inventory system.

This branch exists because the previous implementation grew into a full Roblox inventory framework with server logic, client UI, networking, tool spawning, metadata parsing, debug commands, and replication all connected together. That made the project harder to reason about, harder to test, and harder to safely change.

`CoreStore` is the attempt to separate the actual inventory logic from everything else.

---

## Why Are We Making CoreStore?

The old system had useful inventory behavior:

- items were stored as data instead of persistent Tool instances
- items had UUIDs
- items could stack
- hotbar and storage were separate containers
- the server tracked inventory weight
- the hotbar could be static or dynamic
- remove, swap, equip, and add operations already existed

However, the old server mixed inventory logic with Roblox-specific systems.

For example, the old `InventoryState` stored the player object and loaded settings from `ReplicatedStorage`, which means it was not truly pure data. The state contained useful tables like `Items`, `ItemsByID`, `Hotbar`, `Storage`, `EquippedItemUUID`, `Weight`, and `Settings`, but it also depended on Roblox objects. 

The old `SlotManager` had useful slot behavior, including hotbar slots, storage slots, UUID lookup, and hotbar compaction, but it also depended on global Roblox settings through `ReplicatedStorage`. 

The old `AddOperation` handled inventory adding, metadata normalization, stacking, capacity checks, hotbar placement, storage placement, backpack-disabled behavior, dropping, and equipping all in one flow. That made the add operation powerful, but too coupled for a clean core. 

`CoreStore` exists to keep the inventory system focused on only this:

```txt
data in
inventory state changes
result out
````

No Roblox instances.  
No remotes.  
No UI.  
No physical Tools.  
No player object.  
No world spawning.

***

## What CoreStore Is Supposed To Be

`CoreStore` is a pure Luau inventory engine.

It should be able to run in:

* Roblox Studio
* server-side Luau
* headless tests
* Lune
* Luau CLI-style test environments

The core should only care about tables.

Example input:

```lua
CoreStore.add(state, {
	Id = "Potion",
	Amount = 5,
	Metadata = {
		Rarity = "Common",
		Type = "Consumable",
		Heal = 25,
	},
})
```

Example stored item:

```lua
{
	UUID = "uuid_potion_1",
	Id = "Potion",
	Amount = 5,
	Metadata = {
		Rarity = "Common",
		Type = "Consumable",
		Heal = 25,
		Droppable = true,
	},
}
```

The core should not care whether that data originally came from:

* a Roblox Tool
* a datastore
* a chest
* a shop
* a test file
* a command
* another system

That conversion should happen outside of `CoreStore`.

***

## Why There Is No Networking In CoreStore

The previous Stoway server had a replication layer with action payloads such as:

* `Init`
* `Add`
* `Remove`
* `Swap`
* `Equip`
* `UpdateMeta`
* `UpdateSettings`
* `Reload`

The old `Actions` module built delta payloads for client replication. [\[init.server \| Txt\]](https://belizebank-my.sharepoint.com/personal/drosales_belizebank_com/Documents/Microsoft%20Copilot%20Chat%20Files/init.server.txt)

The old `Replicator` module created Roblox remotes and fired updates to clients using `RemoteEvent` and `RemoteFunction`. [\[SwapOperation \| Txt\]](https://belizebank-my.sharepoint.com/personal/drosales_belizebank_com/Documents/Microsoft%20Copilot%20Chat%20Files/SwapOperation.txt)

That belongs to a Roblox integration layer, not the inventory core.

`CoreStore` does not communicate with the client because communication is not inventory logic.

Instead, `CoreStore` should return result objects.

Example:

```lua
local result = CoreStore.add(state, itemData)
```

Then a future Roblox adapter can decide what to do:

```lua
if result.success then
	ReplicationAdapter.sendAdd(player, result)
end
```

This keeps the dependency direction clean:

```txt
Roblox Server Adapter -> CoreStore
```

Not:

```txt
CoreStore -> Roblox Remotes
```

***

## Why There Is No Roblox Tool Parser In CoreStore

The old system supported turning Roblox Tools and attributes into inventory data.

That idea is still useful, but it does not belong inside the core.

A Tool parser is Roblox-specific because it depends on things like:

* `Instance`
* `Tool`
* Attributes
* children
* folders
* Roblox services

`CoreStore` should never need to know what a Roblox Tool is.

Instead, the future architecture should look like this:

```txt
Roblox Tool
   ↓
ToolParser
   ↓
ItemInput table
   ↓
CoreStore.add(...)
```

`CoreStore` only receives this:

```lua
{
	Id = "Sword",
	Amount = 1,
	Metadata = {
		Damage = 12,
		Rarity = "Common",
		Type = "Weapon",
	},
}
```

That makes the core testable without Roblox.

***

## Why The Client Folder Might Be Deleted In This Branch

The client folder may be deleted or ignored in this branch because this branch is not focused on UI.

The old Stoway project included client-side concerns such as:

* Fusion UI
* hotbar rendering
* drag and drop
* backpack interface
* input binds
* UI skins
* client hydration
* selection mode
* console support

Those are important for the full Stoway framework, but they are not needed while rebuilding the inventory core.

Keeping the client folder during the core rewrite can create confusion because it may still expect:

* old replication payloads
* old compact hotbar structures
* old server events
* old settings paths
* old UI hydration behavior

The point of this branch is to rebuild the inventory state and operations first.

Once `CoreStore` is stable, a new client adapter can be built on top of the new result shapes.

Current priority:

```txt
Core inventory correctness > UI compatibility
```

***

## Why `StowayServerV1_2` Might Be Deleted Later

The old `StowayServerV1_2` folder may be deleted in future commits because it represents the previous architecture.

That code is useful as a reference, but it should not remain as the active system once `CoreStore` replaces it.

The previous server implementation included:

* inventory state
* slot management
* add/remove/swap/drop/equip operations
* replication
* remote setup
* Roblox player handling
* Tool spawning/despawning
* world item dropping
* settings loading from `ReplicatedStorage`

For example, the old `DropOperation` removed inventory items and then spawned dropped tools into the world through `ItemSpawner.DropTool`. [\[SwapOperation \| Txt\]](https://belizebank-my.sharepoint.com/personal/drosales_belizebank_com/Documents/Microsoft%20Copilot%20Chat%20Files/SwapOperation.txt)

The old `EquipOperation` changed inventory state but also spawned physical tools and inspected the player's character for Tools. [\[DropOperation \| Txt\]](https://belizebank-my.sharepoint.com/personal/drosales_belizebank_com/Documents/Microsoft%20Copilot%20Chat%20Files/DropOperation.txt)

Those behaviors are not wrong for a Roblox game, but they should not live inside the pure inventory core.

Eventually, the old server folder may be replaced by smaller adapters:

```txt
server/
  CoreStore/
  RobloxInventoryService/
    ToolParser.luau
    PlayerInventoryRegistry.luau
    ReplicationAdapter.luau
    WorldDropAdapter.luau
```

That would make the final structure clearer:

```txt
CoreStore = pure inventory engine
RobloxInventoryService = Roblox-specific integration
Client = UI/interaction layer
```

***

## What CoreStore Does Not Do

`CoreStore` does not:

* create RemoteEvents
* fire clients
* listen to RemoteFunctions
* parse Roblox Tools
* spawn physical Tools
* destroy physical Tools
* inspect player characters
* manage Fusion UI
* know about keybinds
* know about `Color3`
* know about GUI folders
* know about Roblox `Player`
* directly save to DataStore
* directly load from DataStore

Those systems can exist later, but they should wrap around `CoreStore`.

***

## What CoreStore Does Do

`CoreStore` owns inventory data and inventory operations.

Core responsibilities:

```txt
State creation
Item creation
UUID-based item lookup
ItemId-based lookup
Hotbar placement
Storage placement
Stacking
Capacity / weight
Adding
Removing
Swapping
Splitting
Filtering
Finding
Metadata normalization
Slot lookup
```

The old system already tracked total item amount as `Weight`, and the limit checker treated `Limit = 0` as infinite capacity. [\[init.server \| Txt\]](https://belizebank-my.sharepoint.com/personal/drosales_belizebank_com/Documents/Microsoft%20Copilot%20Chat%20Files/init.server.txt)

In `CoreStore`, hotbar and storage both count toward inventory weight.

That means:

```txt
Weight = total Amount of all items in Hotbar + Storage
```

***

## Intended Inventory State Shape

The core state is designed for fast lookup.

Example:

```lua
local FredInventory = {
	Items = {
		["uuid_apple_1"] = {
			UUID = "uuid_apple_1",
			Id = "Apple",
			Amount = 3,
			Metadata = {
				Rarity = "Common",
				Type = "Food",
				Heal = 5,
			},
		},

		["uuid_potion_1"] = {
			UUID = "uuid_potion_1",
			Id = "Potion",
			Amount = 2,
			Metadata = {
				Rarity = "Uncommon",
				Type = "Consumable",
				Heal = 25,
			},
		},

		["uuid_sword_1"] = {
			UUID = "uuid_sword_1",
			Id = "Sword",
			Amount = 1,
			Metadata = {
				Rarity = "Common",
				Type = "Weapon",
				Damage = 12,
				Durability = 100,
			},
		},
	},

	ItemsByID = {
		Apple = {
			"uuid_apple_1",
		},

		Potion = {
			"uuid_potion_1",
		},

		Sword = {
			"uuid_sword_1",
		},
	},

	Hotbar = {
		[1] = "uuid_apple_1",
		[2] = "uuid_sword_1",
	},

	Storage = {
		"uuid_potion_1",
	},

	LocationByUUID = {
		["uuid_apple_1"] = {
			Type = "Hotbar",
			Slot = 1,
		},

		["uuid_sword_1"] = {
			Type = "Hotbar",
			Slot = 2,
		},

		["uuid_potion_1"] = {
			Type = "Storage",
			Slot = 1,
		},
	},

	EquippedItemUUID = "uuid_sword_1",

	Weight = 6,
}
```

Important lookup paths:

```lua
state.Items[uuid]
state.ItemsByID[itemId]
state.Hotbar[slot]
state.Storage[index]
state.LocationByUUID[uuid]
```

The goal is for important lookups to be O(1) or close to O(1).

Some operations, such as stacking into multiple existing stacks, may still loop over candidate stacks. That is acceptable because the lookup first narrows the search through `ItemsByID[itemId]`.

***

## Why UUID And Id Both Exist

`UUID` and `Id` are different on purpose.

```txt
UUID = unique inventory instance
Id = item definition/catalog name
```

Example:

```lua
{
	UUID = "uuid_potion_stack_a",
	Id = "Potion",
	Amount = 5,
}
```

You may have another stack:

```lua
{
	UUID = "uuid_potion_stack_b",
	Id = "Potion",
	Amount = 2,
}
```

Both have the same `Id`, but different `UUID`s.

This allows:

```lua
state.Items["uuid_potion_stack_a"]
```

for direct access to one exact stack.

And:

```lua
state.ItemsByID["Potion"]
```

for finding all potion stacks.

`ItemsByID` should store UUIDs, not copied item tables, because the real source of truth is `Items`.

Correct:

```lua
ItemsByID = {
	Potion = {
		"uuid_potion_stack_a",
		"uuid_potion_stack_b",
	},
}
```

Incorrect:

```lua
ItemsByID = {
	Potion = {
		{ Id = "Potion", Amount = 5 },
		{ Id = "Potion", Amount = 2 },
	},
}
```

Duplicating item tables can cause desync.

***

## Metadata Rules

The old system allowed metadata overrides and treated `Amount` and `StackAmount` as special values during add. The old add operation normalized metadata overrides, read `Amount` or `StackAmount`, removed those keys from metadata, and used the parsed number as the amount being added. [\[DropOperation \| Txt\]](https://belizebank-my.sharepoint.com/personal/drosales_belizebank_com/Documents/Microsoft%20Copilot%20Chat%20Files/DropOperation.txt)

`CoreStore` keeps that idea.

Input can look like this:

```lua
CoreStore.add(state, {
	Id = "Arrow",
	Metadata = {
		StackAmount = 20,
		Rarity = "Common",
		Type = "Ammo",
	},
})
```

Stored metadata should become:

```lua
{
	Rarity = "Common",
	Type = "Ammo",
}
```

Not:

```lua
{
	StackAmount = 20,
	Rarity = "Common",
	Type = "Ammo",
}
```

Reason:

```txt
Amount and StackAmount affect core inventory behavior.
They are not regular metadata after parsing.
```

Other metadata can be anything:

```lua
{
	Damage = 12,
	Uses = 5,
	Durability = 100,
	CustomTag = "QuestItem",
}
```

***

## Add Behavior

Default add should be automatic.

```lua
CoreStore.add(state, itemData)
```

Default behavior:

```txt
1. Normalize item data
2. Check capacity
3. Try stacking (reduces amountLeft)
4. Split remaining into multiple stacks (each capped at MaxStackSize)
5. Place stacks via placement chain (Auto -> Hotbar -> Storage)
6. If no space for next stack: overflow = remaining amount
7. Return result
```

### Overflow Handling

If the total amount exceeds what can fit (capacity or slot availability):

```txt
Add Apple x12, MaxStackSize = 5, Capacity = 10

Stack 1: Apple x5 -> placed
Stack 2: Apple x5 -> placed
No room for remainder

addedAmount = 10, overflow = 2
```

The overflow is returned in the result. The caller decides what to do with it (drop, notify, etc).

### Placement Modes

```txt
Auto      -> Hotbar first, then Storage
Backpack  -> Storage only
Hotbar    -> Hotbar only (optional slot)
Slot      -> Specific SlotRef (future)
```

### Explicit Add

```lua
CoreStore.addToBackpack(state, itemData)
CoreStore.addToHotbar(state, itemData, slot?)
CoreStore.addToSlot(state, itemData, slotRef)
```

Use default add for normal pickup behavior.

Use explicit add when another system knows where the item should go, such as:

* chest looting
* admin grants
* shop rewards
* drag and drop
* scripted placement
* storage-only transfers

***

## Remove Behavior

Remove should only alter inventory data.

A remove operation should:

```txt
1. Find item by UUID
2. Remove requested amount
3. If amount remains, reduce stack
4. If amount reaches zero, destroy stack
5. Update weight
6. Update indexes
7. Update slot references
8. Return removed item data
```

The old remove operation already followed this broad idea by reducing or destroying the item, removing it from `Items`, removing it from `ItemsByID`, removing it from hotbar or storage, and updating weight. [\[init.server \| Txt\]](https://belizebank-my.sharepoint.com/personal/drosales_belizebank_com/Documents/Microsoft%20Copilot%20Chat%20Files/init.server.txt)

In `CoreStore`, remove does not drop anything into the world.

A future Roblox adapter can do this:

```lua
local result = CoreStore.remove(state, uuid, amount)

if result.success then
	WorldDropAdapter.drop(player, result.removedItem)
end
```

***

## Swap Behavior

Swap exchanges the positions of two items in the inventory.

CoreStore supports four swap combinations:

```txt
Hotbar <-> Hotbar
Storage <-> Storage
Hotbar <-> Storage
Storage <-> Hotbar
```

### StackOnSwap

A system-level setting `StackOnSwap` controls whether swap can trigger stacking.

```txt
StackOnSwap = false (default):
  Swap is purely positional.
  Items exchange slots regardless of whether they could stack.

StackOnSwap = true AND CanStack = true:
  Before swapping, CoreStore checks if the items can stack.
  If they can, the source is absorbed into the destination stack.
  If not, positional swap occurs as normal.

StackOnSwap = true AND CanStack = false:
  StackOnSwap is ignored. Swap is purely positional.
```

### Equipped Item Behavior

EquippedItemUUID follows the UUID, not the slot. Swapping an equipped item from one slot to another does not unequip it.

### Backpack Disabled

If `BackpackEnabled = false`, any swap involving Storage is rejected.

Full swap specification: `docs/SwapRules.md`

***

## Move Behavior

Move transfers an item from one slot to another. Move is purely positional. Move never triggers stacking.

```txt
Move = swap where destination is empty
Move = purely positional, no stacking
```

### Hotbar -> Hotbar

Move item from one hotbar slot to another empty hotbar slot.

### Hotbar -> Storage

Move item from hotbar to storage. Appends to Storage array.

### Storage -> Hotbar

Move item from storage to an empty hotbar slot. Storage shifts left.

### Storage -> Storage

Reorder within storage by removing from one index and inserting at another.

### Why Move Does Not Stack

Stacking during slot operations only happens via add (always) or swap with `StackOnSwap = true`. Move is purely positional.

Example:
```
Apple x3 in Storage, Apple x2 in Hotbar[1], Hotbar[2] is empty

Move Storage -> Hotbar[2]:
  Apple x3 moves to Hotbar[2]
  Hotbar[1] still has Apple x2
  Two separate stacks, no merging

Swap Storage -> Hotbar[1] (with StackOnSwap = true):
  Apple x3 absorbs into Apple x2
  Stacked
```

Full move specification: `docs/MoveRules.md`

***

## Split Behavior

Split divides an existing stack into two stacks.

```txt
1. Reduce source stack by split amount
2. Create new stack with split amount
3. New stack gets new UUID, same Id, deep-copied Metadata
4. Place new stack following placement chain (Auto -> Hotbar -> Storage)
5. If destination specified, place there instead
```

### Rules

```txt
Split amount must be >= 1
Split amount must be < source stack amount
Source keeps its UUID (important if equipped)
New stack follows standard placement chain
```

### Stacking Interaction

Before creating a new stack, split attempts to stack the split amount into existing stacks at the destination. If stacking absorbs the full amount, no new stack is created.

Full split specification: `docs/SplitRules.md`

***

## Metadata Update Behavior

All metadata is mutable in CoreStore. This allows external systems (shops, luck systems, admin commands) to modify items after creation.

```lua
CoreStore.updateMetadata(state, uuid, {
    Rarity = "Legendary",
    Damage = 50,
    Description = "The sword of a thousand truths",
})
```

### Stacking Impact

Metadata changes do not automatically re-stack or un-stack items. If a metadata change makes an item no longer stackable with its siblings, the stack remains as-is until a future operation separates it.

```txt
Example:
  Item has Rarity = "Common", stacked with other Commons
  Update Rarity to "Legendary" (blacklisted)
  Stack remains. Next add operation will not merge into this stack.
```

This avoids cascading side effects. Callers should explicitly split if they want separation.

### Use Cases

```txt
Luck-based systems: Rare drop gets buffed stats
Admin commands: Change item properties
Quest systems: Upgrade item metadata on completion
Shop systems: Apply modifiers on purchase
```

Full metadata update specification: `docs/MetadataUpdateRules.md`

***

## Sorting Behavior

Sorting is automatic when `Settings.Sorting = true`. Any operation that modifies slot contents triggers a sort after completion.

### Triggered By

```txt
add, addToBackpack, addToHotbar, remove, swap, move, split
```

### Scope

```txt
Hotbar: Only sorted if HotbarType = "Dynamic"
Storage: Always sorted when enabled
```

### Sort Criteria

Determined by `Settings.SortOrder`:

```txt
Name     -> Sort by item.Id alphabetically
Rarity   -> Sort by Metadata.Rarity (Common < Uncommon < ... < Legendary)
ItemType -> Sort by Metadata.Type alphabetically
None     -> No sorting
```

### Sort Stability

When two items have the same sort key, their relative order is preserved (stable sort).

Full sorting specification: `docs/SortingRules.md`

***

## Equip Behavior

Core equip should only be state.

```lua
state.EquippedItemUUID = uuid
```

The old equip operation also spawned physical tools and inspected the player's character. [\[DropOperation \| Txt\]](https://belizebank-my.sharepoint.com/personal/drosales_belizebank_com/Documents/Microsoft%20Copilot%20Chat%20Files/DropOperation.txt)

That should not happen inside `CoreStore`.

Future architecture:

```txt
CoreStore.equip(...)
   ↓ result
RobloxEquipAdapter.spawnTool(...)
```

***

## Drop Behavior

Core drop probably should not exist as a world operation.

Dropping is really:

```txt
remove item from inventory
then spawn item in world
```

The old drop operation did both inventory removal and world spawning. [\[SwapOperation \| Txt\]](https://belizebank-my.sharepoint.com/personal/drosales_belizebank_com/Documents/Microsoft%20Copilot%20Chat%20Files/SwapOperation.txt)

In the new architecture:

```txt
CoreStore.remove = inventory data change
WorldDropAdapter.drop = Roblox world behavior
```

This separation makes tests much easier.

***

## Why Tests Matter

The old system was hard to test outside Roblox because the server code depended on:

* `game:GetService`
* `ReplicatedStorage`
* `Player`
* `RemoteEvent`
* `RemoteFunction`
* `Tool`
* character models
* world spawners

`CoreStore` should be testable with simple Luau tables.

Example test:

```lua
local state = CoreStore.new()

local result = CoreStore.add(state, {
	Id = "Potion",
	Amount = 2,
	Metadata = {
		Rarity = "Common",
		Type = "Consumable",
	},
})

assert(result.success)
assert(state.Weight == 2)
assert(state.Hotbar[1] ~= nil)
```

No Roblox environment should be required for this kind of test.

***

## Current Rewrite Direction

The current intended folder is:

```txt
server/
  CoreStore/
    init.luau
    Metadata.luau
    Operations.luau
    Query.luau
    Slots.luau
    Stack.luau
    State.luau
    Types.luau
    Utils.luau

  tests/
```

This branch should focus on these features first:

```txt
1. State.new
2. CoreStore.add
3. CoreStore.addToBackpack
4. CoreStore.addToHotbar
5. CoreStore.remove
6. CoreStore.getItem
7. CoreStore.find
8. CoreStore.filter
9. CoreStore.getAllItems
```

Then add:

```txt
10. CoreStore.addToSlot
11. CoreStore.swap
12. CoreStore.move
13. CoreStore.split
14. CoreStore.updateMetadata
15. CoreStore.sort
16. CoreStore.serialize / deserialize
```

***

## What Happens Later?

Later, after `CoreStore` is stable, we can build separate integration layers.

Possible future structure:

```txt
server/
  CoreStore/
    pure inventory engine

  RobloxInventoryService/
    PlayerInventoryRegistry.luau
    ToolParser.luau
    ReplicationAdapter.luau
    EquipAdapter.luau
    DropAdapter.luau
    DataStoreAdapter.luau

client/
  StowayClient/
    UI
    input
    drag/drop
    hotbar rendering
    backpack rendering
```

This keeps the responsibilities clean.

***

## Simple Mental Model

If a file needs Roblox services, it should not be in `CoreStore`.

If a file needs `Player`, it should not be in `CoreStore`.

If a file needs `RemoteEvent`, it should not be in `CoreStore`.

If a file needs `Tool`, it should not be in `CoreStore`.

If a file only needs tables, item data, slots, stack rules, and inventory state, it probably belongs in `CoreStore`.

***

## Final Goal

The goal is to make Stoway easier to work on by splitting it into layers:

```txt
CoreStore
  Pure inventory engine.
  No Roblox.
  No UI.
  No networking.

Roblox Server Adapter
  Converts Roblox concepts into CoreStore calls.
  Handles players, tools, remotes, world drops, equips, and saving.

Client/UI
  Displays inventory.
  Sends user intent.
  Does not own inventory truth.
```

This rewrite is not deleting Stoway.

This rewrite is trying to save Stoway from becoming too coupled to safely maintain.


---

