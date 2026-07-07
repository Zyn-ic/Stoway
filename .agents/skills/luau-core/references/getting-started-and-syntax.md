# Getting Started and Syntax

## Key Concepts

- Luau is based on Lua 5.1 and adds selected language features instead of matching later Lua versions wholesale.
- Files usually use `.luau`, but the language rules here are about Luau itself, not any host runtime.
- Only `false` and `nil` are falsy.
- Luau has one numeric type at runtime: a double-precision number.

## Rules

- Prefer `local` for variables and functions.
- Use one-based indexing for arrays.
- `return`, `break`, and `continue` end the current block path.
- `continue` must be the last statement in its block path.
- Compound assignments such as `+=` are statements, not expressions.
- Prefer `if ... then ... else ...` expressions over `a and b or c`.
- Do not bring in type-system detail here beyond recognizing that type syntax exists; deep typing belongs elsewhere.

## Patterns

### Local function and local state

```luau
local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end

    return value
end
```

### Literal forms and simple expressions

```luau
local decimal = 1_000_000
local hex = 0xFF
local binary = 0b1010
local text = "line 1\nline 2"
local merged = "a" .. "b"
```

### `if` expression

```luau
local function sign(x)
    return if x < 0 then -1 elseif x > 0 then 1 else 0
end
```

### Compound assignment

```luau
local counts = { apples = 1 }
counts.apples += 2
```

## Examples

### General syntax shape

```luau
local total = 0

for i = 1, 5 do
    total += i
end

print(total)
```

### `continue` in a loop

```luau
for _, value in { -2, 0, 5 } do
    if value <= 0 then
        continue
    end

    print(value)
end
```
