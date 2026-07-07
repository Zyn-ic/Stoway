# Sandbox Constraints Relevant to Runtime Behavior

## Key Concepts

- Luau sandboxes globals by using per-script environment tables that read from a protected builtin global table.
- This isolation model enables optimizations such as imported global chains and specialized builtin dispatch in pure environments.
- Environment mutation features exist for compatibility, but they weaken optimization assumptions.
- Some environment and tooling features change how code executes even when semantics stay the same.

## Rules

- Keep performance-sensitive code in pure environments.
- Avoid `getfenv`, `setfenv`, and `loadstring` in hot modules.
- Do not depend on monkey-patching globals as an optimization technique.
- When measuring environment-specific compilation behavior, profile without active breakpoints.

## Patterns

### Understand pure versus impure environments

- Pure environments let Luau resolve many global access chains at load time.
- Calling `getfenv`, even only to read values, marks the environment impure.
- `setfenv` and `loadstring` also force deoptimization because they can change what globals mean.

### Work with sandboxed globals

- Prefer locals for hot dependencies instead of relying on writable globals.
- Treat globals as stable host-provided services, not as mutable hot-path state.
- Keep module interfaces explicit so performance-sensitive code does not need environment tricks.

### Account for tooling effects

- Debugging support is designed to minimize overhead in normal interpreted execution.
- In environments with native compilation, breakpoints can disable native execution for the affected function.
- Measure runtime behavior in conditions that match production as closely as practical.

## Examples

### Pure environment friendly helper

```luau
local function saturate(x)
    return math.min(math.max(x, 0), 1)
end
```

### Avoid environment mutation in hot code

```luau
local sqrt = math.sqrt

local function length2(x, y)
    return sqrt(x * x + y * y)
end
```
