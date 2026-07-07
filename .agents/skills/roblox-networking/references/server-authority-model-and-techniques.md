# Server Authority Model And Techniques

## Key Concepts

- In a server-authority model, the server is the source of truth and clients primarily contribute inputs.
- Responsiveness comes from client prediction, then rollback and resimulation when predictions are wrong.
- Competitive or exploit-sensitive gameplay benefits from this structure.
- Roblox's current server-authority APIs are beta-specific and should be treated accordingly.

## Rules

- Keep the authoritative game state on the server.
- Let clients send inputs, not final simulation outcomes.
- Separate core simulation from rendering, animation, and effects.
- Expect mispredictions and build systems that tolerate correction.
- Use remote events for discrete messages even in authoritative systems, but keep authority on the server.

## Patterns

### Prediction-aware structure

- Simulation logic updates state.
- Render logic reads synchronized state and plays local presentation.
- Corrections should update state first, then visuals react.

### Latency-conscious design

- Prefer mechanics that tolerate delay and correction.
- Use delayed or state-based feedback when instant all-or-nothing actions produce obvious artifacts.
- Forward only the inputs or small synchronized state needed to reproduce behavior.

### Shared simulation module

```lua
local RunService = game:GetService("RunService")

local Simulation = {}

function Simulation.Initialize()
    RunService:BindToSimulation(function(deltaTime)
        -- Read synchronized inputs and update core state.
    end)
end

return Simulation
```

## Examples

### Good authoritative contract

- Client sends throttle, steering, or action input.
- Server decides movement, collisions, scoring, and legality.

### Render-side response

```lua
RunService.RenderStepped:Connect(function()
    -- Read synchronized state and play sounds or VFX.
end)
```
