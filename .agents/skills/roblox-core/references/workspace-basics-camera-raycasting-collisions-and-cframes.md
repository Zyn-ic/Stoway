# Workspace Basics, Camera, Raycasting, Collisions, And CFrames

## Key Concepts

- `Workspace` contains the live 3D world: parts, terrain, models, attachments, and scripts acting on world objects.
- Each client has its own `Workspace.CurrentCamera`; camera control is therefore client-side.
- Raycasting is the standard way to query the world along a line with optional filtering.
- Collision behavior comes from part properties, touch events, and collision groups.
- `CFrame` combines position and rotation and is the normal tool for facing, offsetting, and orienting objects in 3D.

## Rules

- Access workspace through `game:GetService("Workspace")`, `workspace`, or `game.Workspace`; use one style consistently.
- Keep camera scripting in local scripts and use `CameraType = Scriptable` only when you intend to replace default behavior.
- Use `Workspace:Raycast()` for directed spatial checks instead of relying on touch events for everything.
- Use `CanTouch`, `CanCollide`, `CanQuery`, and collision groups intentionally; they control different behaviors.
- Remember that `Touched` depends on physical simulation and does not fire for every scripted overlap case.
- Use `CFrame.lookAt()`, `ToWorldSpace()`, and `Lerp()` when relative transforms matter more than raw coordinates.

## Patterns

### Basic workspace access

```lua
local Workspace = game:GetService("Workspace")
local baseplate = Workspace:WaitForChild("Baseplate")
```

### Scriptable camera

```lua
local Workspace = game:GetService("Workspace")

local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(Vector3.new(0, 12, 18), Vector3.new(0, 4, 0))
camera.Focus = CFrame.new(0, 4, 0)
```

### Basic raycast with filtering

```lua
local Workspace = game:GetService("Workspace")

local params = RaycastParams.new()
params.FilterDescendantsInstances = {script.Parent}
params.FilterType = Enum.RaycastFilterType.Exclude

local result = Workspace:Raycast(Vector3.zero, Vector3.new(0, -50, 0), params)
if result then
    print(result.Instance, result.Position)
end
```

### Touch detection with a simple guard

```lua
local part = script.Parent

part.Touched:Connect(function(otherPart)
    print(part.Name, "touched", otherPart.Name)
end)
```

### Relative transform with CFrame

```lua
local anchor = workspace.Anchor
local target = workspace.Target

target.CFrame = anchor.CFrame:ToWorldSpace(CFrame.new(0, 2, -4))
```

## Examples

### Point an object at another object

```lua
local turret = workspace.Turret
local goal = workspace.Goal

turret.CFrame = CFrame.lookAt(turret.Position, goal.Position)
```

### Collision group assignment

```lua
local PhysicsService = game:GetService("PhysicsService")
local part = workspace.Door

PhysicsService:RegisterCollisionGroup("Doors")
part.CollisionGroup = "Doors"
```
