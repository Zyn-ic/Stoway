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

**Output:** `docs/specs/CoreStoreSpecification.md`

## Invariants

- [x] Create Invariants.md
- [x] Define all state guarantees
- [x] Define index guarantees
- [x] Define weight guarantees
- [x] Define verification function

**Output:** `docs/specs/Invariants.md`

## Missing Specifications

### Swap
- [x] Define swap behavior
- [x] Define conflict handling
- [x] Define stacking interaction (StackOnSwap system setting)

**Output:** `docs/specs/SwapRules.md`

### Move
- [x] Define move behavior (= swap with empty destination)
- [x] Define destination rules
- [x] Define merge behavior (stacking into storage)

**Output:** `docs/specs/MoveRules.md`

### Split
- [x] Define split behavior
- [x] Define destination rules (follows placement chain)
- [x] Define placement rules

**Output:** `docs/specs/SplitRules.md`

### Metadata Updates
- [x] Define mutable metadata (all metadata is mutable)
- [x] Define stack interaction (no auto re-stack/un-stack)

**Output:** `docs/specs/MetadataUpdateRules.md`

### Sorting
- [x] Define sort scope (auto-triggered on mutation)
- [x] Define sort orders (Name, Rarity, ItemType)
- [x] Define automatic/manual behavior (automatic when enabled)
- [x] Rarity sort order: descending (highest first)

**Output:** `docs/specs/SortingRules.md`

---

# Phase 1 - Core Completion Code

### Add To Slot
- [x] Implement CoreStore.addToSlot()
- [x] Support SlotRef placement
- [x] Validate destination slot

### Swap
- [x] Hotbar <-> Hotbar
- [x] Storage <-> Storage
- [x] Hotbar <-> Storage (occupied and empty destination)
- [x] Update LocationByUUID
- [x] StackOnSwap system setting

### Move
- [x] Move item to slot
- [x] Move item to hotbar
- [x] Move item to storage
- [x] Validate destination (must be empty)
- [x] Storage -> Storage reorder (occupied destination allowed)

### Split
- [x] Split stack by amount
- [x] Create new UUID
- [x] Place new stack (follows placement chain)
- [x] MaxStackSize cap enforced unconditionally
- [x] Split equipped item keeps equipped state

### Metadata Updates
- [x] updateMetadata()
- [x] Apply metadata changes
- [x] Trigger auto-sort if enabled

### Sorting
- [x] Auto-trigger after mutating operations
- [x] Sort by Name
- [x] Sort by Rarity (descending: highest first)
- [x] Sort by ItemType
- [x] Skip hotbar sort if Static
- [x] Update Storage ordering
- [x] Update LocationByUUID

### Settings
- [x] Add StackOnSwap to Settings (system-level, default false)
- [x] Add SortOrder to Settings

### Trivial Wrappers
- [x] removeBySlot()
- [x] getHotbarItemCount()
- [x] getStorageItemCount()
- [x] isEquipped()
- [x] isFull()
- [x] hasHotbarSpace()

### MetadataIndex
- [x] MetadataIndex field in InventoryState
- [x] addToMetadataIndex / removeFromMetadataIndex / updateMetadataIndex
- [x] Indexed fields: Rarity, Type
- [x] Wired into createItem, destroyUnplacedItem, remove, updateMetadata
- [x] Optimized find() queries using MetadataIndex buckets

### Dynamic Hotbar Slot Enforcement
- [x] Reject swap Hotbar→Hotbar with empty destination (DESTINATION_UNAVAILABLE)
- [x] Reject move Hotbar→Hotbar in Dynamic mode (DESTINATION_UNAVAILABLE)
- [x] Reject move Storage→Hotbar at non-append slot (DESTINATION_UNAVAILABLE)
- [x] Ignore preferred slot in add — always append to end
- [x] Reject split to non-append hotbar destination (DESTINATION_UNAVAILABLE)
- [x] Expose CoreStore.compact() for explicit compaction after HotbarType change
- [x] Same 5 fixes ported to JS test tool
- [x] 8 new tests covering all Dynamic rejection paths
- [x] Updated SwapRules, MoveRules, SplitRules, CoreStoreSpecification, Invariants

### Serialization
- [ ] serialize()
- [ ] deserialize()
- [ ] Validation

---

## Testing

### Unit Tests
- [x] Swap tests (7 tests)
- [x] Move tests (5 tests)
- [x] Split tests (5 tests)
- [x] Metadata tests (5 tests)
- [x] Sorting tests (5 tests)
- [x] StackOnSwap tests (2 tests)
- [x] MetadataIndex tests (7 tests)
- [ ] Serialization tests

### Invariant Tests
- [x] Every UUID in Hotbar exists in Items
- [x] Every UUID in Storage exists in Items
- [x] Every Item exists in ItemsByID
- [x] Every Item has LocationByUUID
- [x] Weight matches inventory contents
- [x] verifyInvariants() debug function

### Test Results
- 47/47 tests passing (corestore_operations_test.luau)
- 25/25 tests passing (corestore_addtest.luau)

---

## Web Test Tool

### Core
- [x] Full JS port of all 9 CoreStore modules
- [x] All 22 public functions ported 1:1 from Luau
- [x] Multi-player management
- [x] Rarity color coding on all item slots/cards
- [x] 12 one-click test scenarios

### UI
- [x] Player sidebar with add/remove
- [x] Hotbar grid with filled/empty slot display
- [x] Storage grid with cards
- [x] Selected item detail panel
- [x] Operation forms (add/remove/swap/move/split/metadata/sort/settings)
- [x] Color-coded operation log
- [x] Dynamic hotbar: occupied slots only (no empty placeholders)
- [x] Storage drop bar for appending items

### Drag and Drop
- [x] Document-level event delegation (survives DOM re-renders)
- [x] Drag between hotbar slots
- [x] Drag from hotbar to storage
- [x] Drag from storage to hotbar
- [x] Drag from storage to storage
- [x] Visual indicators: green=move, yellow=stack, blue=swap
- [x] Source item visible at 30% opacity during drag
- [x] Storage drop bar as append target
- [x] Dynamic hotbar: green drop zone indicators during drag
- [x] Fix: Multiple drop events per release (setupDragHandlers called per render)
- [x] Fix: Stale state in dragover handlers (call getState() fresh each time)

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
