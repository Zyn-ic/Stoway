# Object-Oriented Typing

## Key Concepts

- Luau can type object-like modules built from tables and metatables, but `self` often needs explicit help.
- Separate instance data from class behavior.
- Derive the instance type from `setmetatable` with `typeof(...)` or the relevant type function form.
- Export the instance type when other modules consume it.

## Rules

- Define a data shape type first for instance fields.
- Derive and export the instance type from `setmetatable`.
- Annotate constructor returns with the instance type when compatibility matters.
- Annotate `self` explicitly on methods that operate on the shared class type.
- Keep class and instance typing aligned so method assumptions match constructor output.

## Patterns

### Separate data from behavior

```luau
--!strict

local Account = {}
Account.__index = Account

type AccountData = {
    name: string,
    balance: number,
}

export type Account = typeof(setmetatable({} :: AccountData, Account))
```

### Constructor with explicit return type

```luau
--!strict

function Account.new(name: string, balance: number): Account
    return setmetatable({
        name = name,
        balance = balance,
    }, Account)
end
```

### Method with explicit `self`

```luau
--!strict

function Account.deposit(self: Account, amount: number)
    self.balance += amount
end
```

## Examples

### Export a typed class instance shape

```luau
--!strict

export type Counter = typeof(setmetatable({} :: { value: number }, Counter))
```

### Keep method typing consistent with constructor output

```luau
--!strict

local counter = Counter.new(0)
Counter.increment(counter, 1)
counter:increment(1)
```
