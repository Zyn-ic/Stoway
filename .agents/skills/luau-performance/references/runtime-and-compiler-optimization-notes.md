# Runtime and Compiler Optimization Notes

## Key Concepts

- Luau uses a multi-pass compiler and a highly tuned bytecode interpreter.
- The compiler performs constant folding, peephole improvements, upvalue optimization, and limited interprocedural optimization within a module.
- Immutable upvalues are cheaper than mutable captured state.
- Closure creation can be optimized, but repeated closure allocation can still create pressure in hot paths.
- Small local functions may be inlined when profitable.
- In supported environments, selective native compilation can improve numeric or compute-heavy functions, but it has memory and tooling tradeoffs.

## Rules

- Prefer `local function` for small hot helpers that stay within one module.
- Avoid unnecessary mutation of captured values when closures run often.
- Keep hot functions simple enough that compiler optimizations remain available.
- Treat native compilation as an opt-in measurement exercise, not a default.
- Annotate important value types where an environment-specific compiler uses that information for specialization.

## Patterns

### Work with compiler assumptions

- Local function calls are easier to optimize than indirect function values.
- Module-local reasoning is stronger than cross-module reasoning.
- Pure environments preserve import-based builtin optimization and inlining opportunities.

### Reduce closure and upvalue cost

- Hoist reusable helper functions to module scope when they do not need per-iteration captures.
- Avoid recreating comparator or callback functions inside loops.
- Prefer immutable captures when practical so upvalue storage stays cheap.

### Use native compilation selectively when supported

- Good candidates are functions called many times that do substantial arithmetic or buffer-heavy work in Luau itself.
- Poor candidates are scripts dominated by Roblox API calls, cold setup code, or large functions with heavy complexity.
- Measure both runtime and memory impact.
- Remember that breakpoints can disable native execution for affected functions.

## Examples

### Hoist a reusable comparator

```luau
local function ascending(a, b)
    return a < b
end

local function sortValues(values)
    table.sort(values, ascending)
end
```

### Keep captures simple

```luau
local scale = 2

local function scaleValue(x)
    return x * scale
end
```

### Environment-specific native candidate

```luau
local function dot(ax, ay, az, bx, by, bz)
    return ax * bx + ay * by + az * bz
end
```
