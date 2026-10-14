# Contributing

After this page you can change code without breaking the gates.

## Style

Modules follow the template in `AGENTS.md`: `--@author` / `--@date` /
`--[[@description:]]` header, ALL-CAPS section separators (`VARIABLES`,
`CONSTANTS`, `PRIVATE FUNCTIONS`, `PUBLIC FUNCTIONS`), functional style (no
OOP in CoreStore), static Instance-path requires (no relative paths, no
aliases, no pcall shims in production code).

## Gate

Type checking, from the repo root:

```
luau-lsp analyze --definitions="globalTypes.d.luau" --sourcemap="sourcemap.json" --ignore="**/Packages/**" src
```

Expected: **0 errors** outside vendored packages. (`rojo serve` keeps
`sourcemap.json` fresh; never regenerate it by hand.)

## Docs

This site builds with `mkdocs build --strict` — a broken link fails the
build. Preview with `mkdocs serve` while writing.
