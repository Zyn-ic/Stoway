# Security And Defensive Design

## Key Concepts

- Never trust the client; assume any client-controlled input can be fabricated or spammed.
- Defensive design is stronger than purely reactive exploit detection.
- The server should be the source of truth for rules, rewards, combat outcomes, and shared state.
- Abuse resistance includes both validation and limiting how often an action can run.

## Rules

- Threat-model every client-triggered feature before finalizing its network contract.
- Design features so cheating is impossible or low-value instead of only trying to detect it afterward.
- Keep sensitive logic and authoritative state on the server, not in replicated containers.
- Apply server-side cooldowns or token-bucket rate limits to abuse-prone operations.
- Reject malformed, oversized, or costly inputs before expensive work or fan-out broadcasts.

## Patterns

### Defend by changing the game rule

- Obby rewards: require ordered checkpoints, not just final-position claims.
- Combat: let the server compute damage from trusted weapon state.
- Economy: validate server-side inventory and cooldown state before granting items.

### Token bucket limiter

```lua
local function allow(bucket, now, capacity, refillPerSecond)
    local elapsed = now - bucket.last
    bucket.tokens = math.min(capacity, bucket.tokens + elapsed * refillPerSecond)
    bucket.last = now

    if bucket.tokens >= 1 then
        bucket.tokens -= 1
        return true
    end

    return false
end
```

- Allow short bursts.
- Block sustained spam.

## Examples

### Good design question

- If a player can call this 500 times per second, what breaks first?

### Better network contract

```lua
CastSpellRemote.OnServerEvent:Connect(function(player, spellId, targetPosition)
    -- Validate unlocks, cooldown, range, and value shape before broadcasting results.
end)
```
