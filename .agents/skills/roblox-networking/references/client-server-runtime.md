# Client-Server Runtime

## Key Concepts

- Roblox experiences run in a multiplayer client-server model by default.
- The server is the authority for shared experience state.
- Clients render local presentation, read local input, and observe replicated state.
- Replication covers the data model, relevant physics updates, and other synchronized systems.
- Real player latency is significant enough that networking design must tolerate delay and reordering.

## Rules

- Put authoritative rules, shared state transitions, and final decisions on the server.
- Put local input collection, camera, and UI response on the client.
- Assume a remote signal and a related replicated object may arrive in either order unless the API guarantees otherwise.
- Test with simulated replication lag instead of relying on zero-latency Studio defaults.
- Treat the client view as partial when streaming is enabled.

## Patterns

### Separate request from result

```lua
-- Client requests an action attempt.
OpenDoorRemote:FireServer(doorId)

-- Server validates and then changes replicated state.
```

### Handle eventual replication

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("SharedFolder")
```

- Use `WaitForChild()` or equivalent guards on the client when order is not guaranteed.
- Avoid assuming a server-created instance already exists locally when a remote arrives.

## Examples

### Server owns the outcome

```lua
ClaimCheckpointRemote.OnServerEvent:Connect(function(player, checkpointId)
    -- Server verifies order and updates progression.
end)
```

### Client owns presentation

```lua
CountdownRemote.OnClientEvent:Connect(function(secondsRemaining)
    print(secondsRemaining)
end)
```
