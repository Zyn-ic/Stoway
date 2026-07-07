# Memory Store Best Practices, Limits, and Observability

## Key Concepts

- Memory-store design is dominated by TTL, hot partitions, request units, and contention.
- Sorted maps and queues sit on a single partition each.
- Hash maps are automatically spread across partitions, but hot keys can still throttle.
- Request and memory quotas are experience-wide, not per server.

## Rules

- Remove processed queue items immediately.
- Remove stale sorted-map and hash-map entries instead of leaving long-lived clutter.
- Set the shortest practical TTL.
- Shard sorted maps or queues when one structure becomes a hotspot.
- Split hot hash-map traffic across multiple keys when one key is overloaded.
- Use exponential backoff on conflicts and throttles.
- Keep values small; each memory-store item value is limited to 32 KB.

## Limits

### Experience-wide quotas

- Memory quota: `64 KB + 1.2 KB * concurrent users`.
- Request-unit quota: `1000 + 120 * concurrent users` per minute.

### Structure and item limits

- Sorted map or queue: 1,000,000 items max.
- Sorted map or queue: 100 MB total size max.
- Hash map key size: 128 characters max.
- Sorted map key size: 128 characters max.
- Sorted map sort key size: 128 characters max.
- Value size: 32 KB max.
- Expiration time: 0 to 3,888,000 seconds.

### Request-unit notes

- `MemoryStoreSortedMap:GetRangeAsync()` costs based on items returned.
- `MemoryStoreQueue:ReadAsync()` costs based on items returned and wait time.
- `MemoryStoreHashMap:UpdateAsync()` costs at least two units.
- `MemoryStoreHashMap:ListItemsAsync()` costs partitions scanned plus items returned.

## Patterns

### Shard a sorted map

- Split by prefix or bucket range.
- Example buckets: `A-G`, `H-N`, `O-T`, `U-Z`.
- Route each key to a bucket helper.

### Shard a queue

- Use several queues and rotate reads and writes across them.
- Readers merge results from all shards.

### De-hotspot a hash map

- Avoid one `metadata` key that every server reads.
- Store separate keys like `metadata/playerCount`, `metadata/mode`, `metadata/season`.
- If one value is still too hot, replicate it across several equivalent keys and distribute reads.

## Observability

- Use Memory Stores dashboard charts for memory usage, request-unit usage, request count by API, and request count by status.
- Watch for `PartitionRequestsOverLimit`, `DataStructureRequestsOverLimit`, `TotalRequestsOverLimit`, and `DataUpdateConflict`.
- Warning and critical alerts indicate sustained pressure, not isolated blips.

## Examples

### Conflict-safe sorted-map update

```lua
local board = game:GetService("MemoryStoreService"):GetSortedMap("AuctionBoard")

board:UpdateAsync("item/42", function(current, sortKey)
    current = current or {highestBid = 0}
    if current.highestBid >= 500 then
        return nil
    end

    current.highestBid = 500
    return current, 500
end, 120)
```

### Backoff sketch

```lua
local delaySeconds = 1
for attempt = 1, 5 do
    local ok, result = pcall(operation)
    if ok then
        return result
    end

    task.wait(delaySeconds)
    delaySeconds *= 2
end
```
