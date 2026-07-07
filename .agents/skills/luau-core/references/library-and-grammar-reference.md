# Library and Grammar Reference

## Key Concepts

- Luau exposes a compact standard library centered on builtin types and utility globals.
- Hosts may restrict environment access; do not assume file-system or process libraries exist.
- The grammar for this skill focuses on runtime statements and expressions, not deep type syntax.

## Rules

- Prefer library functions when they directly express the operation.
- Use `assert`, `error`, `pcall`, and `xpcall` for explicit error paths.
- Use `table`, `string`, and `math` helpers instead of manual reimplementation when they improve clarity.
- Use `next`, `pairs`, `ipairs`, and direct `for ... in table do` intentionally based on traversal semantics.
- Do not assume `io`, `package`, unrestricted `os`, or unrestricted `debug` are available.

## Patterns

### Common globals

- `assert(value, message?)`
- `error(obj, level?)`
- `type(obj)` and `typeof(obj)`
- `pairs(table)` and `ipairs(table)`
- `pcall(fn, ...)` and `xpcall(fn, handler, ...)`
- `rawget`, `rawset`, `rawlen`
- `tostring`, `tonumber`, `select`, `unpack`

### Useful library choices

- `table.insert`, `table.remove`, `table.sort`, `table.concat`, `table.move`, `table.unpack`
- `string.format`, `string.gsub`, `string.gmatch`, `string.find`, `string.sub`
- `math.abs`, `math.floor`, `math.ceil`, `math.max`, `math.min`, `math.random`

### Runtime grammar reminders

- Assignment: `varlist = explist`
- Compound assignment: `var compoundop exp`
- Local declaration: `local bindinglist ['=' explist]`
- Loops: `while`, `repeat ... until`, numeric `for`, generic `for`
- Conditionals: `if ... then ... elseif ... else ... end`
- Last statements: `return`, `break`, `continue`
- Expressions include literals, function calls, table constructors, unary/binary operators, and `if` expressions

## Examples

### Error handling

```luau
local ok, result = pcall(function()
    assert(#"abc" == 3, "unexpected length")
    return math.max(1, 4, 2)
end)
```

### Library-focused table work

```luau
local values = { 3, 1, 2 }
table.sort(values)
local text = table.concat(values, ",")
```

### String iteration

```luau
for word in string.gmatch("alpha beta gamma", "%S+") do
    print(word)
end
```
