# Compatibility Notes

## Key Concepts

- Luau starts from Lua 5.1 behavior and adopts selected ideas from later Lua versions.
- Luau is intentionally not a full superset of newer Lua releases.
- Compatibility questions often matter more than syntax similarity.

## Rules

- Assume Lua 5.1 baseline unless a Luau extension is known to exist.
- Do not assume `goto`, bitwise operators, integer-only arithmetic, or the full later-Lua library surface.
- Prefer `bit32` over bitwise operators when bit manipulation is needed in pure Luau.
- Remember that only selected later-Lua features were adopted, such as floor division and some string escape improvements.
- Call out environment-sensitive libraries early; sandboxed hosts may remove or restrict them.

## Patterns

### Supported or notable Luau additions

- `continue`
- Compound assignment operators
- `if` expressions
- Generalized iteration and `__iter`
- Floor division `//`
- Extra string escape forms such as `\x`, `\u{...}`, and `\z`

### Common unsupported assumptions

- `goto`
- Native bitwise operators
- Separate integer runtime type
- Guaranteed tail-call support
- Full `io`, `package`, `loadfile`, `dofile`, or unrestricted debug access

## Examples

### Prefer Luau `if` expressions over Lua idioms

```luau
local value = if input ~= nil then input else defaultValue
```

### Prefer `bit32` instead of operator syntax

```luau
local masked = bit32.band(0xFF, 0x0F)
```

### Do not assume `goto`

```luau
local found = false

for _, value in values do
    if value == target then
        found = true
        break
    end
end
```
