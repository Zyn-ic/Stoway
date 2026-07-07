# Memory Stores Guides

## Key Concepts

- `MemoryStoreService` is for temporary, cross-server, high-frequency state.
- Data expires by TTL, up to 45 days.
- Choose the data structure by access pattern, not by habit.
- Hash maps favor keyed access and broad partitioning.
- Sorted maps favor ordering and range reads.
- Queues favor claim-and-process workflows with invisibility timeout.

## Rules

- Use memory stores only for data that can expire or be rebuilt.
- Prefer hash maps if you do not need ordering or queue semantics.
- Prefer sorted maps for leaderboards, ranked boards, and order-dependent scans.
- Prefer queues when workers claim items and remove them after processing.
- Wrap calls in `pcall()` and expect transient failures or contention.
- Set explicit expiration times instead of leaning on the default long lifetime.

## Patterns

### Hash map

Use when:

- You read by known key.
- You need many keys.
- You want better partition spreading.

Examples:

- Server registry keyed by `server/<jobId>`.
- Shared temporary inventory keyed by item id.
- Cross-server cache of durable records.

### Sorted map

Use when:

- You need ordering by sort key.
- You need `GetRangeAsync()`.
- You are building global daily leaderboards, auctions, or ranked listings.

Examples:

- `leaderboard/<userId>` with score as sort key.
- Auction entries sorted by bid or expiration score.

### Queue

Use when:

- Work should be processed in FIFO or priority order.
- Consumers should claim items temporarily, then remove them on success.

Examples:

- Matchmaking pool.
- Retry work queue for background processing.

## Examples

### Hash map for server presence

```lua
local MemoryStoreService = game:GetService("MemoryStoreService")
local servers = MemoryStoreService:GetHashMap("ActiveServers")

servers:SetAsync(game.JobId, {
    playerCount = #game:GetService("Players"):GetPlayers(),
    region = "eu-west",
}, 60)
```

### Sorted map for temporary ranking

```lua
local board = MemoryStoreService:GetSortedMap("DailyDamage")
board:SetAsync("player/12345", {damage = 9000}, 86400, 9000)
```

### Queue for workers

```lua
local queue = MemoryStoreService:GetQueue("Matchmaking", 30)
queue:AddAsync({userId = 12345, rating = 1500}, 60)
```
