# Services

## Key Concepts

- Services expose built-in Roblox engine functionality through `game:GetService()`.
- A common foundational pattern is: get services, require modules, define local functions, connect events.
- Some services are container services such as `Workspace`, `ReplicatedStorage`, and `ServerScriptService`.
- Other services are gameplay helpers such as `Players`, `RunService`, `CollectionService`, and `UserInputService`.

## Rules

- Retrieve each service once per script and reuse the local reference.
- Keep the variable name aligned with the service name for readability.
- Choose services based on responsibility, then place the script where that responsibility belongs.
- Use `WaitForChild()` when a service child may not be replicated yet to the current runtime side.
- Avoid turning this skill into exhaustive service-by-service API lookup.

## Patterns

### Standard service retrieval

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
```

### Use container services intentionally

- `Workspace` for live world objects.
- `ReplicatedStorage` for shared modules and replicated assets.
- `ReplicatedFirst` for earliest client startup content.
- `ServerScriptService` and `ServerStorage` for server-only logic and assets.

### Common foundational services

- `Players` for player lifecycle events.
- `RunService` for frame-step or context checks.
- `UserInputService` for local input detection.
- `PhysicsService` for collision groups when collision behavior needs structure.

## Examples

### Connect a player lifecycle event

```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    print("Joined:", player.Name)
end)
```

### Access workspace through a service reference

```lua
local Workspace = game:GetService("Workspace")

local baseplate = Workspace:WaitForChild("Baseplate")
print(baseplate.Name)
```
