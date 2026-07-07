# Type System Overview

## Key Concepts

- Luau is gradually typed: the analyzer combines inference and explicit annotations.
- File mode changes analyzer behavior:
  - `--!strict` keeps inference precise and reports more issues early.
  - `--!nonstrict` falls back to `any` more easily.
  - `--!nocheck` disables analysis for the file.
- Luau is structurally typed, especially for table shapes.
- Annotations document intent; casts with `::` adjust overly broad inferred types.

## Rules

- Prefer `--!strict` for new code and stable modules.
- Use `--!nonstrict` only when migrating code that cannot be made strict yet.
- Use `--!nocheck` only when analysis must be disabled intentionally.
- Annotate module boundaries, important locals, and signatures whose intent is not obvious from inference.
- Use casts only when one side is a subtype of the other or `any`; do not use them to hide design problems.
- Remember that casting a multi-return expression preserves only the first value.

## Patterns

### Use strict mode to catch drift early

```luau
--!strict

local total
total = 1
total = total + 2
```

### Annotate the contract, not every temporary

```luau
--!strict

type Person = {
    name: string,
    age: number,
}

local function greet(person: Person): string
    return "Hello, " .. person.name
end
```

### Cast only to recover precision

```luau
--!strict

local data = {
    names = {} :: {string},
}
```

## Examples

### Structural typing with optional fields

```luau
--!strict

type Basic = { x: number }
type Extended = { x: number, y: number? }

local value: Basic = { x = 1, y = 2 }
local widened: Extended = { x = 1 }
```

### Export a shared alias from a module

```luau
--!strict

export type Result = {
    ok: boolean,
    message: string?,
}
```
