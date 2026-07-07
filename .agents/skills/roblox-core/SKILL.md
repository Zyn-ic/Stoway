---
name: roblox-core
description: "Use for foundational Roblox experience development: deciding what runs on the client or server, where scripts and modules belong, how to structure reusable code, and how to handle everyday services, attributes, bindables, workspace objects, input, camera, raycasts, collisions, and CFrame-based gameplay scripting in Studio."
---

# roblox-core

## When to Use

Use this skill when the task is primarily about core Roblox runtime structure and everyday gameplay scripting:

- Choosing whether logic belongs on the client, server, or both.
- Deciding where `Script`, `LocalScript`, and `ModuleScript` instances should live.
- Organizing code across `ServerScriptService`, `ServerStorage`, `ReplicatedStorage`, `ReplicatedFirst`, `StarterPlayer`, `StarterGui`, and `Workspace`.
- Using services, module reuse, attributes, and bindables inside normal gameplay code.
- Working with common Studio scripting workflows like playtesting, Explorer layout, `WaitForChild()`, and Output-driven debugging.
- Implementing straightforward input, camera, raycasting, collision, and `CFrame` behavior as part of ordinary experience scripting.

Do not use this skill when the task is mainly about:

- Exhaustive engine API lookup or class-by-class reference browsing.
- Cross-boundary remote design, advanced remote security, or server-authority architecture.
- Persistence, memory stores, messaging, Open Cloud, OAuth, or external automation.

## Decision Rules

- Use this skill if the main question is structural: where code lives, what runs where, what replicates, or how to organize reusable Roblox logic.
- Use this skill for foundational engine patterns that appear in most experiences: services, modules, attributes, bindables, basic input, workspace access, collisions, raycasts, camera, and `CFrame`.
- If the task centers on `RemoteEvent`, `RemoteFunction`, trust boundaries, request validation, or multiplayer message design, hand off to `roblox-networking`.
- If the task is mainly "which API/member do I call" across a large Roblox surface area, hand off to `roblox-api`.
- If the task centers on saving, loading, quotas, versioning, cross-server state, or ephemeral shared state, hand off to `roblox-data`.
- If the task involves Open Cloud, web APIs, credentials, OAuth, or external tooling automation, hand off to `roblox-cloud` or `roblox-oauth`.
- If a request mixes core structure with out-of-scope systems, answer only the foundational Roblox portion and explicitly exclude the rest.
- If unsure, prefer the narrower interpretation and omit material that would overlap networking, data, cloud, or API-reference skills.

## Instructions

1. Start by identifying the runtime side for each responsibility:
   - Server for authoritative world state, spawning, rule enforcement, and shared simulation.
   - Client for player-local input, camera, moment-to-moment presentation, and local feedback.
   - Shared modules only when both sides need the same code or constants.
2. Place code in containers that match replication behavior:
   - `ServerScriptService` for server-only scripts and modules.
   - `ServerStorage` for server-only assets or modules that do not need to replicate.
   - `ReplicatedStorage` for shared modules and replicated assets.
   - `ReplicatedFirst` only for earliest client startup work.
   - `StarterPlayerScripts`, `StarterCharacterScripts`, `StarterGui`, and `StarterPack` for client behavior copied into each player.
3. Prefer explicit script intent:
   - Use `LocalScript` or `Script` with `RunContext = Client` for client code.
   - Use `Script` with `RunContext = Server` or normal server placement for server code.
   - Use `ModuleScript` for reusable logic and configuration.
4. Retrieve services once near the top of a script with `game:GetService()` and keep names aligned with service names.
5. Use `WaitForChild()` when accessing replicated objects from the client unless the load order is guaranteed by the container being used.
6. Treat `ModuleScript` return values as cached per Luau environment:
   - Require once per script and reuse the returned table or function.
   - Avoid circular requires.
   - Keep shared modules side-agnostic unless the module is intentionally server-only or client-only.
7. Use attributes for lightweight per-instance state and configuration that should live on the instance itself.
8. Use bindables only for communication on the same side of the client-server boundary. Prefer module-owned bindables when they simplify a local event API.
9. For input and camera code, keep implementation client-side and adapt to the player's active input mode rather than assuming desktop-only controls.
10. For workspace scripting:
    - Read and write object state through clear references.
    - Use raycasts for intentional spatial queries.
    - Use collision groups or part properties for collision behavior.
    - Use `CFrame` operations when orientation and relative transforms matter.
11. Keep examples and guidance at the foundational level. Do not drift into persistence, advanced networking security, or exhaustive reference lookups.

## Using References

- Open `references/scripting-overview.md` for the basic Roblox scripting workflow in Studio and the standard service-module-function-event script shape.
- Open `references/client-server-runtime.md` to reason about authority, replication, edit versus runtime data models, and what each side can safely assume.
- Open `references/script-locations-and-script-types.md` when deciding between `Script`, `LocalScript`, `ModuleScript`, run contexts, and container placement.
- Open `references/services.md` for the core `game:GetService()` pattern and which container or gameplay services matter most in foundational code.
- Open `references/modulescripts-and-reuse-patterns.md` for module caching, shared code placement, configuration modules, and encapsulation patterns.
- Open `references/attributes.md` for per-instance state, replication-order cautions, and change-detection patterns.
- Open `references/bindable-events.md` for same-side script communication, async events, sync callbacks, and argument-shape cautions.
- Open `references/input-overview.md` for client-side input handling and adapting to preferred input type across devices.
- Open `references/workspace-basics-camera-raycasting-collisions-and-cframes.md` for the most common world-facing runtime patterns.

## Checklist

- Each responsibility is assigned to the correct runtime side.
- Script and module placement matches replication and visibility needs.
- Shared code is in `ModuleScript` form instead of duplicated across scripts.
- Client code uses `WaitForChild()` where replication order is uncertain.
- Services are retrieved once and reused.
- Attributes are used for lightweight instance state, not arbitrary module data.
- Bindables are only used on one side of the client-server boundary.
- Input and camera code stays client-side.
- Raycasts, collisions, and `CFrame` operations are used intentionally for spatial logic.
- No advanced remote-security design is included.
- No persistence, Open Cloud, OAuth, or external API automation guidance is included.
- No exhaustive API catalog material is included.

## Common Mistakes

- Putting server-only logic in `ReplicatedStorage` or other replicated containers.
- Expecting a plain `Script` to run everywhere without considering location or `RunContext`.
- Using `LocalScript` where a shared `ModuleScript` should hold reusable logic.
- Assuming replicated objects already exist on the client and skipping `WaitForChild()`.
- Treating bindables as cross-network communication tools.
- Mutating a module return value without realizing the cached reference is reused within that environment.
- Using attributes for large structured data that belongs in a module or system object.
- Driving camera or input code from the server.
- Using `Touched` for non-physical overlap logic that should be a raycast or explicit spatial query.
- Moving parts with raw position logic when relative transforms or facing direction require `CFrame`.

## Examples

### Choose placement by responsibility

```lua
-- ServerScriptService/SpawnController
-- Spawns and manages shared world state on the server.
```

```lua
-- StarterPlayer/StarterPlayerScripts/InputController
-- Reads player input and drives local presentation on the client.
```

```lua
-- ReplicatedStorage/Shared/Constants
-- Shared module used by both sides.
local Constants = {
    MaxHealth = 100,
    RoundLength = 120,
}

return Constants
```

### Use the standard script shape

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundConfig = require(ReplicatedStorage:WaitForChild("RoundConfig"))

local function onPlayerAdded(player)
    print(player.Name, "joined; round length:", RoundConfig.RoundLength)
end

Players.PlayerAdded:Connect(onPlayerAdded)
```

### Keep client-only camera code local

```lua
local Workspace = game:GetService("Workspace")

local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(Vector3.new(0, 10, 20), Vector3.new(0, 5, 0))
camera.Focus = CFrame.new(0, 5, 0)
```

### Use attributes and bindables for local structure

```lua
local part = script.Parent
part:SetAttribute("Active", true)

local changed = Instance.new("BindableEvent")
changed.Event:Connect(function(state)
    print("State changed:", state)
end)

changed:Fire(part:GetAttribute("Active"))
```