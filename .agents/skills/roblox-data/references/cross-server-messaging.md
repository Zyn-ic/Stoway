# Cross-Server Messaging

## Key Concepts

- `MessagingService` broadcasts short messages across servers through named topics.
- It is a coordination tool, not durable storage.
- Topic subscribers react to events; durable or ephemeral state should live elsewhere.
- Messages should be small, self-describing, and safe to process more than once.

## Rules

- Use `SubscribeAsync()` to register a topic handler and keep the returned connection so you can disconnect it when appropriate.
- Use `PublishAsync()` for notifications, invalidation signals, and wake-up events.
- Keep topic names short and stable.
- Keep message payloads compact and serializable.
- Assume message delivery timing is variable; re-check authoritative state before acting on a message that changes important data.
- Design handlers to tolerate duplicates or races.
- Do not use messaging as the sole recovery path for durable workflows.

## Patterns

### Cache invalidation

1. Write the authoritative state to a data store or memory store.
2. Publish a topic like `profile-invalidated`.
3. Receivers re-read or refresh their local cache.

### Queue wake-up

1. Add work to a memory-store queue.
2. Publish a topic like `jobs-available`.
3. Workers react by reading the queue.

### Cross-server announcement

- Publish a simple payload with event type and timestamp.
- Receivers fan it into local presentation or server-side handling.

## Examples

### Subscribe and react

```lua
local MessagingService = game:GetService("MessagingService")

local connection = MessagingService:SubscribeAsync("jobs-available", function(message)
    print(message.Data)
    -- Re-check queue or map here.
end)
```

### Publish after state change

```lua
local MessagingService = game:GetService("MessagingService")

MessagingService:PublishAsync("profile-invalidated", {
    key = "player/12345/profile",
    reason = "save-complete",
})
```
