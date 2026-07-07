# Metatables and Userdata Concepts

## Key Concepts

- A metatable lets a table or userdata customize selected operations.
- Common metamethods include `__index`, `__newindex`, arithmetic operators, `__tostring`, `__len`, and `__iter`.
- `rawget`, `rawset`, and `rawlen` bypass metatable behavior.
- Userdata represents host-defined opaque values. In plain Luau discussion, treat userdata as external values with limited direct control.

## Rules

- Reach for metatables only when normal tables are no longer expressive enough.
- Prefer `__index` for shared methods and fallback lookup.
- Protect metatables with `__metatable` only when hiding mutation is part of the design.
- Use `raw*` operations only when bypassing metamethods is intentional.
- Avoid inventing broad operator overloading for simple records.
- Treat userdata support as conceptual unless the host explicitly exposes it.

## Patterns

### Shared methods via `__index`

```luau
local Point = {}
Point.__index = Point

function Point.new(x, y)
    return setmetatable({ x = x, y = y }, Point)
end

function Point:magnitudeSquared()
    return self.x * self.x + self.y * self.y
end
```

### Read fallback table

```luau
local defaults = { retries = 3 }
local options = setmetatable({}, { __index = defaults })
```

### Custom iteration

```luau
local reversed = setmetatable({ 10, 20, 30 }, {
    __iter = function(t)
        local index = #t + 1

        return function()
            index -= 1

            if index > 0 then
                return index, t[index]
            end
        end
    end,
})
```

## Examples

### `__tostring`

```luau
local Box = {}
Box.__index = Box

function Box.new(width, height)
    return setmetatable({ width = width, height = height }, Box)
end

function Box:__tostring()
    return string.format("Box(%d, %d)", self.width, self.height)
end
```

### Userdata boundary

```luau
local ok, value = pcall(function()
    return newproxy(true)
end)

if ok then
    local mt = getmetatable(value)
    mt.__tostring = function()
        return "opaque"
    end
end
```
