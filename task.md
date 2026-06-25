# CoreStore Remaining Tasks

# Phase 0 - Specification Pass

## Current Rule Audit

- [x] Document InventoryState rules
- [x] Document Add rules
- [x] Document Remove rules
- [x] Document Stack rules
- [x] Document Query rules
- [x] Document Slot rules
- [x] Document existing placement rules
- [x] Document current complexity targets

**Output:** `docs/CoreStoreSpecification.md`

## Invariants

- [x] Create Invariants.md
- [x] Define all state guarantees
- [x] Define index guarantees
- [x] Define weight guarantees
- [x] Define verification function

**Output:** `docs/Invariants.md`

## Missing Specifications

### Swap
- [x] Define swap behavior
- [x] Define conflict handling
- [x] Define stacking interaction (StackOnSwap system setting)

**Output:** `docs/SwapRules.md`

### Move
- [x] Define move behavior (= swap with empty destination)
- [x] Define destination rules
- [x] Define merge behavior (stacking into storage)

**Output:** `docs/MoveRules.md`

### Split
- [x] Define split behavior
- [x] Define destination rules (follows placement chain)
- [x] Define placement rules

**Output:** `docs/SplitRules.md`

### Metadata Updates
- [x] Define mutable metadata (all metadata is mutable)
- [x] Define stack interaction (no auto re-stack/un-stack)

**Output:** `docs/MetadataUpdateRules.md`

### Sorting
- [x] Define sort scope (auto-triggered on mutation)
- [x] Define sort orders (Name, Rarity, ItemType)
- [x] Define automatic/manual behavior (automatic when enabled)

**Output:** `docs/SortingRules.md`

---

# Phase 1 - Core Completion Code

### Add To Slot
- [ ] Implement CoreStore.addToSlot()
- [ ] Support SlotRef placement
- [ ] Validate destination slot

### Swap
- [ ] Hotbar <-> Hotbar
- [ ] Storage <-> Storage
- [ ] Hotbar <-> Storage
- [ ] Update LocationByUUID
- [ ] StackOnSwap system setting

### Move
- [ ] Move item to slot
- [ ] Move item to hotbar
- [ ] Move item to storage
- [ ] Validate destination (must be empty)
- [ ] Stack into existing on Hotbar -> Storage

### Split
- [ ] Split stack by amount
- [ ] Create new UUID
- [ ] Place new stack (follows placement chain)
- [ ] Respect stack rules at destination

### Metadata Updates
- [ ] updateMetadata()
- [ ] Apply metadata changes
- [ ] Trigger auto-sort if enabled

### Sorting
- [ ] Auto-trigger after mutating operations
- [ ] Sort by Name
- [ ] Sort by Rarity
- [ ] Sort by ItemType
- [ ] Skip hotbar sort if Static
- [ ] Update Storage ordering
- [ ] Update LocationByUUID

### Settings
- [ ] Add StackOnSwap to Settings (system-level, default false)
- [ ] Add SortOrder to Settings

### Serialization
- [ ] serialize()
- [ ] deserialize()
- [ ] Validation

---

## Testing

### Unit Tests
- [ ] Swap tests
- [ ] Move tests
- [ ] Split tests
- [ ] Metadata tests
- [ ] Sorting tests
- [ ] Serialization tests
- [ ] StackOnSwap tests

### Invariant Tests
- [ ] Every UUID in Hotbar exists in Items
- [ ] Every UUID in Storage exists in Items
- [ ] Every Item exists in ItemsByID
- [ ] Every Item has LocationByUUID
- [ ] Weight matches inventory contents
- [ ] verifyInvariants() debug function

---

## Future (Not CoreStore)

### Roblox Adapter Layer
- [ ] PlayerInventoryRegistry
- [ ] ReplicationAdapter
- [ ] EquipAdapter
- [ ] DropAdapter
- [ ] ToolParser
- [ ] DataStoreAdapter

### Client
- [ ] New UI layer
- [ ] Hotbar rendering
- [ ] Backpack rendering
- [ ] Drag/drop

### Legacy Cleanup
- [ ] Remove dependency on StowayServerV1_2
- [ ] Delete old server implementation
- [ ] Delete obsolete client implementation
