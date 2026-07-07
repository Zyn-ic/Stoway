# Functions, Tables, Operators, Scope, and Control Structures

## Key Concepts

- Functions are first-class values and can be stored, returned, and passed around.
- Closures capture locals from outer scopes as upvalues.
- Tables serve as arrays, dictionaries, records, namespaces, and object-like instances.
- Logical operators return operands, not forced booleans.
- Generic table iteration order is not guaranteed.

## Rules

- Prefer `local function name(...)` for named helpers.
- Use `:` when the function logically receives `self`; use `.` otherwise.
- Treat arrays and dictionaries as different shapes even though both are tables.
- Use `ipairs` for array-like traversal that should stop at the first hole.
- Use `pairs` or direct generalized iteration for dictionary-like traversal.
- Do not rely on order from dictionary traversal.
- Remember that extra function arguments are ignored and missing ones become `nil`.

## Patterns

### Closure over local state

```luau
local function makeCounter()
    local value = 0

    return function()
        value += 1
        return value
    end
end
```

### Array operations

```luau
local values = { "a", "b" }
values[#values + 1] = "c"
table.insert(values, "d")
local removed = table.remove(values, 2)
```

### Dictionary lookup with default

```luau
local counts = {}

local function increment(key)
    counts[key] = (counts[key] or 0) + 1
end
```

### Method syntax

```luau
local Buffer = {}
Buffer.__index = Buffer

function Buffer.new()
    return setmetatable({ items = {} }, Buffer)
end

function Buffer:push(value)
    self.items[#self.items + 1] = value
end
```

## Examples

### Truthiness and control flow

```luau
local value = ""

if value then
    print("empty string is still truthy")
end
```

### Numeric and generic loops

```luau
for i = 1, 3 do
    print(i)
end

for key, value in { a = 1, b = 2 } do
    print(key, value)
end
```

### Avoid boolean ternary emulation

```luau
local result = if maybeValue ~= nil then maybeValue else "fallback"
```
