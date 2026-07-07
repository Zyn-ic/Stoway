# Attributes

## Key Concepts

- Attributes are custom per-instance values stored directly on an instance.
- They are useful for lightweight state and configuration that should travel with the object.
- Clients cannot assume replicated attributes arrive in lockstep with unrelated signals or property changes.
- Attribute change signals are often the safest way to react to replicated state changes.

## Rules

- Use `SetAttribute(name, value)` to create or update an attribute.
- Use `GetAttribute(name)` for one value and `GetAttributes()` for the full dictionary.
- Delete an attribute by setting it to `nil`.
- Use `GetAttributeChangedSignal()` or `AttributeChanged` when behavior depends on seeing updates.
- Use `WaitForChild()` before reading from replicated instances whose existence is not guaranteed yet.

## Patterns

### Create and read attributes

```lua
local part = script.Parent

part:SetAttribute("Active", true)

local active = part:GetAttribute("Active")
print(active)
```

### Read all attributes

```lua
local attributes = script.Parent:GetAttributes()

for key, value in attributes do
    print(key, value)
end
```

### React to one attribute change

```lua
local part = script.Parent

part:GetAttributeChangedSignal("GrowthRate"):Connect(function()
    print(part:GetAttribute("GrowthRate"))
end)
```

## Examples

### Simple cooldown flag

```lua
local part = script.Parent

if not part:GetAttribute("Busy") then
    part:SetAttribute("Busy", true)
    task.wait(1)
    part:SetAttribute("Busy", false)
end
```

### Remove an attribute

```lua
script.Parent:SetAttribute("Busy", nil)
```
