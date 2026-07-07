---
name: luau-types
description: "Use for Luau type-system work focused on strictness modes, annotations, inference-aware API design, generics, refinements, advanced type patterns, and Roblox-aware type usage at the type level."
---

# luau-types

## When to Use

Use this skill when the task is primarily about Luau's type system:

- Choosing between `--!strict`, `--!nonstrict`, and other file type-checking modes.
- Adding or correcting type annotations on variables, functions, tables, and modules.
- Designing APIs that preserve inference instead of collapsing to `any`.
- Modeling data with generics, unions, intersections, optionals, and tagged unions.
- Typing object-like tables, metatable-backed modules, and exported module surfaces.
- Writing or reviewing type functions and other advanced type-level utilities.
- Using Roblox class, datatype, enum, or `IsA` knowledge only to improve static typing.

Do not use this skill when the task is mainly about:

- General Luau syntax, control flow, metatables, or standard-library usage outside typing concerns.
- Runtime performance, profiling, hot-path tuning, or allocation strategy.
- Roblox networking, replication, data storage, cloud APIs, or gameplay architecture.

## Decision Rules

- Use this skill if the core question is "what should this type be?" or "how should this code type-check over time?"
- Prefer `--!strict` guidance for new or actively maintained code unless the task explicitly targets transitional or legacy code.
- Prefer inference-preserving designs over annotation-heavy designs when the inferred shape stays precise and readable.
- Prefer explicit exported aliases at module boundaries when consumers should share a stable contract.
- Use generics when the relationship between inputs and outputs matters; do not replace that relationship with `any`.
- Use tagged unions plus refinements when a value can be one of several structured cases.
- If the task shifts into pure language syntax, hand off to `luau-core`.
- If the task shifts into optimization or runtime cost tradeoffs, hand off to `luau-performance`.
- If the task requires Roblox runtime architecture beyond type names and type refinement, use the appropriate `roblox/*` skill instead.
- If unsure, exclude anything that is not directly needed to improve typing correctness, maintainability, or analyzer behavior.

## Instructions

1. Start by identifying the file mode expectation:
   - `--!strict` for strong inference and early error detection.
   - `--!nonstrict` for transitional code where unresolved values would otherwise become noisy.
   - `--!nocheck` only when the task explicitly requires disabled analysis.
2. Preserve useful inference before adding annotations everywhere. Add annotations where they clarify intent, stabilize module contracts, constrain `self`, or prevent unwanted widening to `any`.
3. Prefer concrete aliases for shared shapes:
   - records for structured data,
   - indexers for dictionaries,
   - `{T}` for arrays,
   - exported aliases for module-facing contracts.
4. Use optionals, unions, and intersections deliberately:
   - `T?` for `T | nil`,
   - tagged unions for state machines or result-like values,
   - intersections to combine compatible table capabilities or function signatures.
5. Treat casts with `::` as a precision tool, not a bypass. Use them to narrow overly generic inference, not to hide unrelated-type errors.
6. Design generics around relationships:
   - preserve element type through transforms,
   - carry key/value relationships through containers,
   - avoid defaulting to `any` when a type parameter can express intent.
7. Model tables according to how Luau analyzes them:
   - unsealed tables can accumulate fields locally,
   - annotated or returned tables become sealed,
   - width subtyping applies to sealed records.
8. For object-like modules, separate instance data from class behavior, derive the instance type from `setmetatable`, and annotate `self` explicitly when methods need the shared class type.
9. Keep module API surfaces type-safe:
   - export named aliases for consumer-facing data,
   - keep implementation details internal,
   - choose signatures that infer caller types cleanly.
10. Use Roblox type knowledge only for annotations and refinements, such as `Instance`, `Part`, `Enum.Material`, datatypes, and `IsA`-driven narrowing.

## Using References

- Open `references/type-system-overview.md` for file modes, structural typing, annotations, casts, and module-boundary guidance.
- Open `references/basic-types-and-table-typing.md` for builtin types, special types like `any` and `unknown`, function signatures, table states, and indexers.
- Open `references/generics.md` for generic aliases, generic functions, defaults on aliases, and inference-preserving container patterns.
- Open `references/unions-and-intersections.md` for result shapes, tagged unions, discriminants, and safe intersection usage.
- Open `references/refinements.md` for truthy checks, `type(...)` guards, equality narrowing, compound conditions, and `assert`-based narrowing.
- Open `references/object-oriented-typing.md` for metatable-backed class typing, `self` annotations, constructor return types, and exported instance aliases.
- Open `references/type-functions.md` for analysis-time type computation, available libraries, and when advanced type-level transforms are justified.
- Open `references/roblox-types-in-luau.md` for Roblox class, datatype, enum, constructor, service, and `IsA` typing behavior.
- Do not open other skill references unless the request clearly crosses skill boundaries.

## Checklist

- The chosen type-checking mode matches the maintenance goal of the file.
- Public module contracts are explicit where reuse matters.
- Inference is preserved where it remains precise.
- `any` is avoided unless intentionally opting out.
- Tables are typed according to their actual shape and sealing behavior.
- Unions, intersections, and optionals reflect real states instead of vague catch-all types.
- Generic parameters encode input/output relationships that callers rely on.
- Method `self` typing is explicit where Luau cannot safely infer the shared class type.
- Roblox types are used only to improve typing, not to drift into unrelated Roblox architecture.
- No general syntax tutorial, performance advice, or networking/data/cloud guidance is included.

## Common Mistakes

- Leaving a variable unannotated in `--!nonstrict` and unintentionally turning it into `any`.
- Replacing a useful generic relationship with `any` or an overly broad union.
- Sealing a table too early with an annotation, then expecting to add fields later.
- Expecting method definitions with `:` to automatically share a precise `self` type across the whole class.
- Using `::` to force unrelated conversions instead of fixing the underlying type design.
- Building unions without a discriminant, then making downstream refinement difficult.
- Using intersections between incompatible primitives such as `string & number`.
- Mixing runtime Roblox architecture guidance into a type-only task.

## Examples

### Export a stable module contract

```luau
--!strict

export type User = {
    id: number,
    name: string,
    nickname: string?,
}

local M = {}

function M.makeUser(id: number, name: string): User
    return {
        id = id,
        name = name,
        nickname = nil,
    }
end

return M
```

### Preserve relationships with a generic function

```luau
--!strict

local function first<T>(items: {T}): T?
    return items[1]
end

local a = first({1, 2, 3}) -- number?
local b = first({"x", "y"}) -- string?
```

### Refine a tagged union

```luau
--!strict

type Loading = { kind: "loading" }
type Ready<T> = { kind: "ready", value: T }
type Failed = { kind: "failed", message: string }
type State<T> = Loading | Ready<T> | Failed

local function readValue(state: State<number>): number?
    if state.kind == "ready" then
        return state.value
    end

    return nil
end
```

### Type an object-like module with explicit `self`

```luau
--!strict

local Counter = {}
Counter.__index = Counter

type CounterData = {
    value: number,
}

export type Counter = typeof(setmetatable({} :: CounterData, Counter))

function Counter.new(initialValue: number): Counter
    return setmetatable({
        value = initialValue,
    }, Counter)
end

function Counter.increment(self: Counter, amount: number): number
    self.value += amount
    return self.value
end

return Counter
```
