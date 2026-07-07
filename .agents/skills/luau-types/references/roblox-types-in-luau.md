# Roblox Types in Luau

## Key Concepts

- Roblox classes, datatypes, and enums are available to the Luau type checker by name.
- Inheritance is modeled, so subtype values can flow into parent-typed positions.
- The analyzer understands common constructors such as `Instance.new` and services returned by `game:GetService`.
- `IsA` can refine Roblox instance types in control flow.

## Rules

- Use Roblox names only as type information in this skill.
- Prefer the most specific useful Roblox type at the API boundary.
- Rely on inheritance when a parameter only needs a parent capability such as `Instance` or `BasePart`.
- Use `Enum.<Name>` for enum typing.
- Use `IsA` checks to narrow instance unions or parent types before accessing subtype members.
- Do not expand into networking, persistence, or broader Roblox architecture.

## Patterns

### Class and datatype annotations

```luau
--!strict

local part: Part = Instance.new("Part")
local position: Vector3 = part.Position
local material: Enum.Material = part.Material
```

### Accept a parent type when that is enough

```luau
--!strict

local function rename(instance: Instance, name: string)
    instance.Name = name
end
```

### Refine with `IsA`

```luau
--!strict

local function getTextLabelText(instance: Instance): string?
    if instance:IsA("TextLabel") then
        return instance.Text
    end

    return nil
end
```

## Examples

### Let Luau infer constructor result types

```luau
--!strict

local folder = Instance.new("Folder")
local asInstance: Instance = folder
```

### Narrow a broad input to a specific GUI type

```luau
--!strict

local function readGuiText(instance: Instance): string
    if instance:IsA("TextButton") or instance:IsA("TextBox") then
        return instance.Text
    end

    return ""
end
```
