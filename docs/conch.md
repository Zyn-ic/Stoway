# Debug Console

Conch debug console, Studio only (Backquote to toggle). Client and server
halves mount gated on `RunService:IsStudio()` — production gets no remotes,
no role, no commands.

All commands act on the calling player and replicate. Item ids are
exact-match names of templates in `ServerStorage.Tools`. UUIDs contain a `.`
from `os.clock()`, and the console language truncates an unquoted token at
that dot, so **quote every UUID** (`remove "core-..."`). `inv` prints UUIDs
pre-quoted for copy-paste; prefer slot commands such as
`equip-slot <Hotbar|Storage> <slot>` where one exists. There is no toggle for
`BackpackEnabled`, so `addback` fails with `BACKPACK_DISABLED` on defaults.

## Inspect

| Command | Does |
|---------|------|
| `inv` | Dump weight, limit, stack flags, hotbar, storage, equipped (UUIDs quoted) |
| `help` | List command names |

## Mutate

| Command | Does |
|---------|------|
| `add <id> [amount]` | Auto-place |
| `addback <id> [amount]` | Into the backpack |
| `addhot <id> [amount] [slot]` | Into the hotbar, optional slot |
| `remove "uuid" [amount]` | Partial or full removal |
| `drop "uuid" [amount]` | World-drop in front of the player |
| `swap <type> <slot> <type> <slot>` | Exchange two slots (stacks if allowed) |
| `move <type> <slot> <type> <slot>` | Positional transfer, never stacks |
| `split "uuid" <amount> [type] [slot]` | Divide a stack |
| `equip "uuid"` / `equip-slot <type> <slot>` | Equip (quote UUIDs, or use a slot) |
| `unequip` | Empty the hand |
| `sort` | Sort storage now |
| `clear-inv` | Remove everything (`clear` alone is Conch's builtin) |

## Settings & UI

| Command | Does |
|---------|------|
| `toggle-stack` / `toggle-limit` / `toggle-sort` / `toggle-debug` | Flip engine flags (debug silences system print/warn) |
| `set-limit <n>` / `set-max-stack <n>` / `set-hotbar-slots <n>` | Tune capacity |
| `set-hotbar-type <Static\|Dynamic>` | Switch packing (auto-compacts) |
| `set-skin <Default\|Modern\|Metal\|Jailbreak\|Persona>` | Switch skin (Jailbreak + Persona pair with `JailbreakHotbar`) |
| `set-layout <StandardHotbarStorage\|JailbreakHotbar> [skin]` | Switch engine live |
| `set-team <criminal\|cop\|prison>` | Stamp `Team` on every item |
