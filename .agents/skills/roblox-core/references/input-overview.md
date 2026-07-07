# Input Overview

## Key Concepts

- Input handling is client-side work.
- Roblox supports keyboard and mouse, touch, gamepad, and other device inputs.
- `UserInputService.PreferredInput` is a practical way to adapt UI and controls to the player's active primary input mode.
- The Input Action System helps define gameplay actions independently from specific hardware buttons.

## Rules

- Read player input from client scripts, not server scripts.
- Adapt to preferred input instead of assuming desktop-only controls.
- Use action-oriented bindings when you need one gameplay action to map across multiple devices.
- Use `GetPropertyChangedSignal("PreferredInput")` to react when the player's active input mode changes.
- Keep core guidance at the overview level; do not turn this skill into a full per-device control catalog.

## Patterns

### Detect preferred input

```lua
local UserInputService = game:GetService("UserInputService")

local function updateInputMode()
    local preferredInput = UserInputService.PreferredInput

    if preferredInput == Enum.PreferredInput.Touch then
        print("Touch")
    elseif preferredInput == Enum.PreferredInput.Gamepad then
        print("Gamepad")
    else
        print("KeyboardAndMouse")
    end
end

updateInputMode()

UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateInputMode)
```

### Action-based thinking

- Define actions like jump, sprint, interact, or fire.
- Map those actions to multiple input types.
- Update on-screen prompts and UI based on preferred input.

## Examples

### Client-only input controller

```lua
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    print(input.UserInputType)
end)
```
