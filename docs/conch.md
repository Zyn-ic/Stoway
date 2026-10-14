# Debug Console

Conch debug console, Studio only (Backquote to toggle). Client and server
halves mount gated on `RunService:IsStudio()` — production gets no remotes,
no role, no commands.

All commands act on the calling player and replicate. Item ids are
exact-match names of templates in `ServerStorage.Tools`. UUID arguments must
be quoted; prefer `equip-slot <Hotbar|Storage> <slot>` over raw UUIDs. There
is no toggle for `BackpackEnabled`, so `addback` fails with
`BACKPACK_DISABLED` on defaults.

## Inspect

| Command | Does |
|---------|------|
| `inv` | Dump weight, limit, stack flags, hotbar, storage, equipped |
| `help` | List command names |

## Mutate

| Command | Does |
|---------|------|
| `add <id> [amount]` | Auto-place |
| `addback <id> [amount]` | Into the backpack |
| `addhot <id> [amount] [slot]` | Into the hotbar, optional slot |
| `remove <uuid> [amount]` | Partial or full removal |
| `drop <uuid> [amount]` | World-drop in front of the player |
| `swap <type> <slot> <type> <slot>` | Exchange two slots (stacks if allowed) |
| `move <type> <slot> <type> <slot>` | Positional transfer, never stacks |
| `split <uuid> <amount> [type] [slot]` | Divide a stack |
| `equip "uuid"` / `equip-slot <type> <slot>` | Equip (quotes required for UUIDs) |
| `unequip` | Empty the hand |
| `sort` | Sort storage now |
| `clear-inv` | Remove everything (`clear` alone is Conch's builtin) |

## Settings & UI

| Command | Does |
|---------|------|
| `toggle-stack` / `toggle-limit` / `toggle-sort` | Flip engine flags |
| `set-limit <n>` / `set-max-stack <n>` / `set-hotbar-slots <n>` | Tune capacity |
| `set-hotbar-type <Static\|Dynamic>` | Switch packing (auto-compacts) |
| `set-skin <Default\|Modern\|Metal\|Jailbreak>` | Switch skin (Jailbreak pairs its layout) |
| `set-layout <StandardHotbarStorage\|JailbreakHotbar> [skin]` | Switch engine live |
| `set-team <criminal\|cop\|prison>` | Stamp `Team` on every item |
