# Client-Server Runtime

## Key Concepts

- Roblox experiences are multiplayer by default and run in a client-server model.
- The server is the authority for shared experience state and keeps clients synchronized through replication.
- Each client gets its own runtime view of the experience and handles local player presentation.
- Edit-time objects in Studio become runtime objects on the server and then replicate to clients according to container rules.

## Rules

- Put shared world rules and durable game-state transitions on the server.
- Put input reading, local UI behavior, and camera control on the client.
- Do not assume the client sees every workspace object immediately, especially with streaming enabled.
- Do not assume a property change and a later signal arrive on the client in the same order unless the API guarantees it.
- Use client-server reasoning to decide placement before writing code.

## Patterns

### Divide responsibility by runtime side

- Server: spawn world objects, validate state changes, manage player-facing shared state.
- Client: read controls, drive camera, show local feedback, react to replicated state.
- Shared: constants and pure helpers in `ReplicatedStorage` modules.

### Replication-aware access

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedState = require(ReplicatedStorage:WaitForChild("SharedState"))
```

- Server-created or server-modified instances may not be available to clients immediately.
- Client code should use `WaitForChild()` when load order is uncertain.

### Client-local camera

```lua
local Workspace = game:GetService("Workspace")

local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
```

## Examples

### Shared constant module used on both sides

```lua
local Config = {
    WalkSpeed = 16,
}

return Config
```

### Server handles shared world state

```lua
local Workspace = game:GetService("Workspace")

Workspace.SpawnLocation.Transparency = 0
```
