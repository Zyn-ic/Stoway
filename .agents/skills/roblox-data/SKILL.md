---
name: roblox-data
description: "Use for Roblox persistent data and cross-server state design: choosing between DataStoreService, OrderedDataStore, MemoryStoreService, and MessagingService; designing save and load flows, schema shape, versioning, metadata, retries, quotas, observability, and concurrency-safe coordination across servers."
---

# roblox-data

## When to Use

Use this skill when the task is mainly about Roblox data durability, shared cross-server state, or quota-aware coordination:

- Designing persistent player saves, global config-like records, or other `DataStoreService` usage.
- Choosing between standard data stores and ordered data stores.
- Structuring save payloads, schema versions, migrations, and metadata.
- Deciding when to use `SetAsync()`, `UpdateAsync()`, `IncrementAsync()`, or version APIs.
- Designing ephemeral cross-server systems with `MemoryStoreService`.
- Choosing between memory store queues, sorted maps, and hash maps.
- Coordinating multiple servers with `MessagingService`.
- Handling throttling, request budgets, retries, backoff, contention, and observability.
- Reasoning about stale reads, cache behavior, idempotency, and multi-server correctness.

Do not use this skill when the task is mainly about:

- Remote-event security, client-to-server validation, or general gameplay networking.
- OAuth flows, API key setup, or general Open Cloud authentication.
- Broad engine API lookup outside data services.

## Decision Rules

- Use standard data stores for durable cross-session data that can be represented as numbers, strings, booleans, tables, or buffers.
- Use ordered data stores only when the stored value is numeric and the main requirement is persistent ranking or sorted retrieval.
- Prefer storing one related object per durable key instead of scattering related fields across many durable keys.
- Prefer `UpdateAsync()` when multiple servers might write the same key or when the new value depends on the current value.
- Use memory stores for shared data that is frequent, temporary, or coordination-oriented and can expire.
- Use a memory store hash map for keyed lookups and high fan-out across many keys.
- Use a memory store sorted map when ordering matters or when you need range reads by sort key.
- Use a memory store queue for ordered work processing, matchmaking queues, or claim-and-remove workflows.
- Use `MessagingService` for short-lived broadcast signals, fan-out notifications, or wake-up coordination, not as the durable system of record.
- If the task is mostly about remotes, replication to clients, or trust boundaries, hand off to `roblox-networking`.
- If the task is mostly about general runtime structure or script placement, hand off to `roblox-core`.
- If the task is mostly about member lookup, signatures, or class discovery, hand off to `roblox-api`.
- If a request mixes in out-of-scope material, answer only the data-service portion and exclude the rest.

## Instructions

1. Classify the state before choosing a service:
   - Durable across sessions.
   - Temporary but cross-server.
   - Broadcast-only coordination.
   - Numeric ranking versus arbitrary structured data.
2. Choose the narrowest primitive that fits:
   - Standard data store for durable objects.
   - Ordered data store for durable numeric rankings.
   - Hash map for keyed ephemeral state.
   - Sorted map for ordered ephemeral state.
   - Queue for claim-and-process work items.
   - Messaging for notifications that can be regenerated from other state.
3. For persistent saves, define a stable schema:
   - Keep one self-contained object per key when possible.
   - Include a schema version field inside the value.
   - Reserve migrations for load time or first write after load.
   - Keep keys, scopes, and store names short and predictable.
4. Design writes for concurrency:
   - Prefer `UpdateAsync()` for contested keys.
   - Make callbacks deterministic and non-yielding.
   - Return `nil` to abort invalid updates.
   - Preserve existing metadata and user IDs when you do not intend to clear them.
5. Design reads with cache behavior in mind:
   - Treat `GetAsync()` as locally cached for a short window.
   - Use uncached reads only when freshness matters enough to justify extra budget use.
   - Avoid reading immediately after writing from a different server unless the design accounts for staleness.
6. Treat quotas as part of the design:
   - Check request budgets before bursty durable writes.
   - Batch related durable data into one object where it improves atomicity and budget use.
   - Keep memory-store TTLs as short as the use case allows.
   - Remove queue and sorted-map items promptly after processing.
7. Design for retries and failure:
   - Wrap network calls in `pcall()`.
   - Retry transient failures with exponential backoff.
   - Add jitter or spreading when many servers may retry together.
   - Make retryable operations idempotent whenever possible.
8. Use observability to close the loop:
   - Watch request counts, throttles, and quota usage for data stores.
   - Watch memory usage, request-unit usage, and throttle statuses for memory stores.
   - Use dashboards to confirm whether the bottleneck is global quota, per-key contention, or hot partitions.
9. Use messaging as a coordination layer, not storage:
   - Publish compact events.
   - Re-read or update authoritative state in data or memory stores as needed.
   - Assume messages can be delayed or duplicated and make handlers safe.
10. Keep guidance inside scope:
   - Focus on persistence, ephemeral shared state, quotas, and concurrency.
   - Do not drift into remote security, gameplay networking, or auth flows.

## Using References

- Open `references/data-stores-guides.md` for standard versus ordered data stores, core CRUD patterns, metadata, serialization, and save-shape decisions.
- Open `references/data-store-best-practices.md` for durable schema layout, key organization, storage hygiene, and cleanup strategy.
- Open `references/versioning-listing-caching-limits-and-observability.md` for version history, prefix listing, cache behavior, limits, request budgets, throttling, and dashboards.
- Open `references/memory-stores-guides.md` for choosing between queues, sorted maps, and hash maps and for the core API patterns of each.
- Open `references/memory-store-best-practices-limits-and-observability.md` for TTL strategy, sharding, partition pressure, request-unit budgeting, contention handling, and dashboards.
- Open `references/cross-server-messaging.md` for topic design, publish-subscribe flow, and coordination patterns that pair messaging with durable or ephemeral state.
- Open `references/data-stores-vs-memory-stores-comparison.md` when the first decision is which service class should own the data.

## Checklist

- The state is classified as durable, ephemeral cross-server, or broadcast-only.
- The chosen service matches the durability and ordering requirements.
- Persistent keys use a stable schema with an explicit version field.
- Durable writes use `UpdateAsync()` when contention is possible.
- Ordered data stores are only used for numeric ranking data.
- Cache behavior and stale-read risk are accounted for.
- Request budgets, quotas, and throttling behavior are part of the design.
- Memory-store TTLs are intentionally short and cleanup paths are explicit.
- Queue items are removed after processing and sorted-map or hash-map items are pruned when stale.
- Messaging is used for coordination, not as the system of record.
- Retry logic uses `pcall()` plus backoff rather than tight loops.
- No remote security, OAuth, or general API-lookup material is included.

## Common Mistakes

- Using `SetAsync()` on hot keys that multiple servers can write concurrently.
- Splitting one durable player profile across many unrelated keys without a strong reason.
- Using ordered data stores for structured blobs or metadata-heavy records.
- Forgetting that `GetAsync()` can return a cached value for a few seconds.
- Treating memory stores as durable storage.
- Using a queue when random keyed access or scans would fit a hash map better.
- Putting all hash-map traffic on one hot key and then hitting partition throttles.
- Keeping long TTLs on temporary memory-store items and filling quota with stale data.
- Using `MessagingService` as the only source of truth for recoverable state.
- Retrying immediately on throttles or conflicts and causing coordinated retry storms.

## Examples

### Choose the right service

- Player profile save: standard data store with one object per player key.
- All-time coins leaderboard: ordered data store keyed by player identifier with numeric values.
- Matchmaking pool: memory store queue.
- Cross-server auction board with ranking: memory store sorted map.
- Shared ephemeral room registry keyed by server id: memory store hash map.
- Force a cache refresh workflow across servers: message plus data-store or memory-store re-read.

### Use `UpdateAsync()` for contested durable saves

```lua
local DataStoreService = game:GetService("DataStoreService")
local profileStore = DataStoreService:GetDataStore("PlayerProfiles")

local function saveCoins(userId, delta)
    return profileStore:UpdateAsync(("player/%d"):format(userId), function(current, keyInfo)
        current = current or {schemaVersion = 1, coins = 0}
        current.coins += delta
        return current, keyInfo:GetUserIds(), keyInfo:GetMetadata()
    end)
end
```

### Use messaging to wake workers, not to hold state

```lua
-- Publish: "queue has work"
-- Receiver: read the queue or map, then process authoritative state there.
```
