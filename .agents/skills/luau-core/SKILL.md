---
name: luau-core
description: "Use for idiomatic, correct pure Luau language work focused on syntax, functions, tables, control flow, metatables, standard library behavior, and Lua compatibility details outside Roblox APIs, deep typing, or performance tuning."
---

# luau-core

## When to Use

Use this skill when the task is primarily about plain Luau language behavior:

- Writing or fixing pure Luau syntax.
- Choosing idiomatic control flow, variable scope, or function structure.
- Working with tables as arrays, dictionaries, or object-like values.
- Using the standard library correctly.
- Applying metatables for indexing, operators, iteration, or object-like patterns.
- Checking whether a Lua feature or idiom is compatible with Luau.

Do not use this skill when the task is mainly about:

- Luau type annotations, generics, inference, refinements, or strictness policy.
- Profiling, optimization strategy, or performance tradeoffs.
- Roblox engine APIs, services, events, classes, networking, data, or gameplay architecture.

## Decision Rules

- Use this skill if the answer can stay within pure Luau syntax, semantics, idioms, and standard library usage.
- If the task centers on type aliases, annotations, generics, exported types, or analyzer behavior, hand off to `luau-types`.
- If the task centers on allocation patterns, hot loops, benchmarking, profiling, or optimization strategy, hand off to `luau-performance`.
- If the task depends on `game`, `Instance`, services, remotes, datastores, UI, physics, or other Roblox runtime concepts, use the appropriate `roblox/*` skill instead.
- If a request mixes core language work with out-of-scope topics, answer only the pure Luau portion and explicitly exclude the rest.
- If unsure, prefer the narrower interpretation and omit material that could overlap another skill.

## Instructions

1. Treat Luau as Lua 5.1 plus selected Luau extensions. Do not assume Lua 5.2+ features unless Luau explicitly supports them.
2. Prefer `local` variables and `local function` declarations by default. Use globals only when the broader scope is required by the task.
3. Keep control flow direct. Prefer normal `if`, `elseif`, `else`, loops, `break`, and `continue` over clever boolean tricks.
4. Use Luau-specific syntax when it improves correctness or readability:
   - `if ... then ... else ...` expressions instead of `a and b or c` ternary emulation.
   - Compound assignment such as `+=` when the left side should only be evaluated once.
   - Generalized iteration `for k, v in table do` when iterating a table directly is the clearest form.
5. Model tables intentionally:
   - Arrays for ordered numeric sequences.
   - Dictionaries for keyed lookup.
   - Metatable-backed records only when custom behavior materially improves the API.
6. Use `:` for method definitions and calls that conceptually pass `self`; use `.` for plain function access.
7. Prefer built-in library functions over handwritten helpers when the standard library already expresses the operation clearly.
8. Use metatables sparingly and explicitly. Define only the metamethods needed for the abstraction and avoid surprising behavior.
9. When discussing compatibility, call out unsupported assumptions early, such as `goto`, bitwise operators, integer-only reasoning, or full Lua standard library access.
10. Keep all examples host-agnostic and pure Luau. Do not rely on Roblox engine objects or services.

## Using References

- Open `references/getting-started-and-syntax.md` for syntax forms, literals, assignments, expression forms, and Luau-only syntax additions.
- Open `references/functions-tables-operators-scope-and-control-structures.md` for the core execution model: functions, closures, tables, truthiness, iteration, and control flow.
- Open `references/metatables-and-userdata-concepts.md` for metamethod behavior, object-like table patterns, raw operations, and userdata boundaries.
- Open `references/library-and-grammar-reference.md` for standard-library selection and compact grammar reminders for statements and expressions.
- Open `references/compatibility-notes.md` when a request compares Luau with Lua or depends on version-specific behavior.
- Do not open or cite references outside this skill unless the task clearly crosses into another skill's scope.

## Checklist

- The solution is valid Luau syntax.
- Scope is explicit and defaults to `local`.
- Control flow is clear and uses the simplest correct construct.
- Table usage is intentional: array, dictionary, or metatable-backed record.
- Iteration choice matches the data shape.
- Standard library usage is correct and simpler than a custom helper.
- Any metatable behavior is minimal, predictable, and documented in code if non-obvious.
- No deep type-system material is included.
- No performance-tuning guidance is included.
- No Roblox engine APIs or architecture advice is included.

## Common Mistakes

- Treating `0` or `""` as falsy. In Luau, only `false` and `nil` are falsy.
- Using `a and b or c` as a ternary replacement when `b` can be `false` or `nil`.
- Assuming arrays are zero-based instead of one-based.
- Mixing method and function syntax, such as defining with `:` and calling with `.`.
- Relying on dictionary iteration order.
- Forgetting that missing function arguments become `nil` and extra arguments are ignored.
- Using globals where locals or closures are the correct fit.
- Overusing metatables for simple data containers.
- Assuming newer Lua features like `goto`, bitwise operators, or integer semantics exist in Luau.

## Examples

### Use `if` expressions instead of boolean ternary tricks

```luau
local function labelScore(score)
    return if score >= 100 then "high" else "normal"
end
```

### Prefer locals and straightforward control flow

```luau
local function firstPositive(values)
    for _, value in values do
        if value > 0 then
            return value
        end
    end

    return nil
end
```

### Use tables intentionally

```luau
local queue = {}

queue[#queue + 1] = "a"
queue[#queue + 1] = "b"

local first = table.remove(queue, 1)
```

### Use method syntax for object-like tables

```luau
local Counter = {}
Counter.__index = Counter

function Counter.new()
    return setmetatable({ value = 0 }, Counter)
end

function Counter:increment()
    self.value += 1
    return self.value
end
```

### Add metatables only when behavior is deliberate

```luau
local Range = {}
Range.__index = Range

function Range.new(minimum, maximum)
    return setmetatable({ minimum = minimum, maximum = maximum }, Range)
end

function Range:contains(value)
    return value >= self.minimum and value <= self.maximum
end

function Range:__tostring()
    return string.format("[%d, %d]", self.minimum, self.maximum)
end
```
