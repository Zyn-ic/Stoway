# Client-Server Boundary Guidance

## Key Concepts

- Every client-triggered action is a trust boundary.
- Validation has multiple layers: permission, type, structure, value, and timing.
- Client-triggered instances such as prompts or click detectors need the same skepticism as remotes.
- The server must be a gatekeeper, not a transparent relay to other clients.

## Rules

- Validate player context on the server: alive state, distance, ownership, cooldowns, and permissions.
- Validate argument type and structure before using values or instances.
- Reject `NaN`, `inf`, impossible coordinates, unknown ids, and oversized strings or tables.
- Confirm instance arguments are real instances of the expected class in an expected container.
- Never trust client-side cooldowns or distance checks as sufficient.
- Validate before rebroadcasting to other clients.

## Patterns

### Layered validation

```lua
local function isNaN(n)
    return n ~= n
end

local function isInf(n)
    return math.abs(n) == math.huge
end
```

- Type-check first.
- Then validate shape and ownership.
- Then validate value ranges and action timing.

### Server-side rebroadcast

```lua
LightningRemote.OnServerEvent:Connect(function(player, strikePosition)
    -- Validate type, cooldown, permission, and range.
    LightningRemote:FireAllClients(player, strikePosition)
end)
```

- Broadcast only after the request is proven safe.

### Secure client-triggered interactions

- `ProximityPrompt`: verify enabled state, distance, hold timing, and player state on the server.
- `ClickDetector`: add your own server checks; engine-side trust is minimal.
- `Touched`: validate contact independently, especially for client-owned assemblies.

## Examples

### Spoof-resistant instance check

```lua
if typeof(item) ~= "Instance" or not item:IsDescendantOf(ItemCatalog) then
    return
end
```

### Unsafe relay pattern

```lua
Remote.OnServerEvent:Connect(function(_, payload)
    Remote:FireAllClients(payload)
end)
```

- This turns one client into an attack surface for every other client.
