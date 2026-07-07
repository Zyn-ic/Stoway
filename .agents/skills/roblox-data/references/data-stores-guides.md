# Data Stores Guides

## Key Concepts

- `DataStoreService` is for durable cross-session data.
- Standard data stores hold numbers, strings, booleans, tables, and buffers.
- Ordered data stores hold numeric values and support sorted retrieval.
- Standard data stores support metadata and version history. Ordered data stores do not.
- Data-store calls are networked and should be wrapped in `pcall()`.

## Rules

- Access data stores from server code only.
- Prefer one self-contained object per durable key when the fields should stay in sync.
- Use `UpdateAsync()` when the next value depends on the current value or multiple servers might write the same key.
- Use `SetAsync()` only when blind overwrite is acceptable.
- Keep store names, scopes, and keys within platform limits.
- Store only serializable Luau data. Do not store `nan`, `inf`, or unsupported userdata.

## Patterns

### Durable profile object

- Key: `player/<userId>`
- Value:

```lua
{
    schemaVersion = 3,
    coins = 1250,
    inventory = {"sword", "potion"},
    settings = {
        music = true,
        sensitivity = 0.8,
    },
}
```

- Benefit: one read and one write keep related fields consistent.

### Ordered leaderboard split from profile

- Standard store keeps the full profile.
- Ordered store keeps only the ranked numeric metric.
- Benefit: rich durable data stays in the standard store while the leaderboard stays queryable.

### Metadata-aware save

- Use metadata for lightweight tags, provenance, or migration notes.
- Preserve existing metadata when the write is not meant to clear it.

## Examples

### Standard store write with update semantics

```lua
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerProfiles")

local function awardCurrency(userId, amount)
    return store:UpdateAsync(("player/%d"):format(userId), function(current, keyInfo)
        current = current or {schemaVersion = 1, currency = 0}
        current.currency += amount
        return current, keyInfo:GetUserIds(), keyInfo:GetMetadata()
    end)
end
```

### Ordered store for persistent ranking

```lua
local DataStoreService = game:GetService("DataStoreService")
local leaderboard = DataStoreService:GetOrderedDataStore("CoinsLeaderboard")

local function setCoins(userId, coins)
    return leaderboard:SetAsync(("player/%d"):format(userId), coins)
end
```
