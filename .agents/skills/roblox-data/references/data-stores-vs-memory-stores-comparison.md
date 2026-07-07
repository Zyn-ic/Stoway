# Data Stores vs Memory Stores Comparison

## Key Concepts

- Data stores are durable. Memory stores are temporary.
- Both are cross-server and server-only.
- Data stores are the system of record for progress and permanent state.
- Memory stores are for coordination, fast shared state, caches, and expiring systems.

## Rules

- Use a data store when the value must survive player leaves, server shutdowns, and long time spans.
- Use a memory store when the value can expire, be rebuilt, or is mainly about coordination.
- Use an ordered data store only for permanent numeric ranking.
- Use a memory store sorted map only for temporary ordering.
- Do not store secrets, auth tokens, or unrelated cloud credentials in either design discussion here.

## Comparison

### Standard data store

- Durable across sessions.
- Supports structured values.
- Supports metadata and version history.
- Best for player profiles, durable inventories, and permanent settings.

### Ordered data store

- Durable across sessions.
- Numeric values only.
- Supports sorted retrieval.
- Best for all-time persistent leaderboards.

### Memory store

- Up to 45-day lifetime.
- Lower latency and higher throughput for shared temporary state.
- Best for matchmaking, temporary leaderboards, server registries, locks, queues, and caches.

## Patterns

### Durable plus ephemeral pair

- Data store holds the permanent profile.
- Memory store hash map mirrors a short-lived cache for active sessions.
- Messaging invalidates or refreshes cache entries when writes occur.

### Durable ranking plus temporary ranking

- Ordered data store for all-time score.
- Memory store sorted map for daily or weekly scoreboards.

## Examples

### Choose by requirement

- "Keep player inventory forever": standard data store.
- "Show top 100 all-time coins": ordered data store.
- "Track active match lobbies for the next 60 seconds": memory store hash map.
- "Process queued match requests across servers": memory store queue.
- "Broadcast that a new job is ready": messaging plus queue, not messaging alone.
