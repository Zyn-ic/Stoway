# Scripting Overview

## Key Concepts

- Roblox scripting is Luau code attached to objects in the data model.
- A common core script shape is: get services, require modules, define local functions, connect events.
- Studio workflow matters: create scripts in Explorer, run playtests, inspect Output, and use Script Editor navigation.
- Roblox development is organized around runtime containers and object hierarchies, not just source files.

## Rules

- Prefer `local` variables and local helper functions inside scripts.
- Retrieve services once at the top with `game:GetService()`.
- Use Output, warnings, and playtests to validate script behavior quickly.
- Treat Explorer location as part of the script's behavior, not just organization.
- Keep core examples grounded in Studio workflows, not external tooling or deployment systems.

## Patterns

### Standard script structure

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedConfig = require(ReplicatedStorage:WaitForChild("SharedConfig"))

local function onPlayerAdded(player)
    print(player.Name, SharedConfig.RoundLength)
end

Players.PlayerAdded:Connect(onPlayerAdded)
```

### Output-driven debugging

- Use `print()` for simple flow checks.
- Use `warn()` when something is unexpected but non-fatal.
- Check Output during playtests instead of guessing whether code ran.

### Basic Studio workflow

- Insert the script under the correct container.
- Rename it descriptively.
- Playtest after each small change.
- Use Ctrl-click navigation and Find to follow references across scripts and modules.

## Examples

### First server script shape

```lua
local ServerScriptService = game:GetService("ServerScriptService")

print("Server startup from", ServerScriptService.Name)
```

### Read from a parented object

```lua
local part = script.Parent
part.Name = "Checkpoint"
```
