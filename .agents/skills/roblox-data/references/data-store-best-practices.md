# Data Store Best Practices

## Key Concepts

- Durable storage design is mostly about atomicity, key layout, and storage hygiene.
- Related data usually belongs in one value object rather than many keys.
- Prefixes are the preferred way to organize new key spaces.
- Memory stores are better for caches and temporary coordination data.

## Rules

- Create fewer data stores and organize within them by keys or prefixes.
- Keep related user data together when the fields must move in lockstep.
- Use prefixes instead of new scopes for new systems unless legacy scope usage already exists.
- Delete test data and temporary event data instead of leaving permanent clutter.
- Prefer deleting by key over proliferating whole test data stores.

## Patterns

### Prefix-based key layout

- `player/12345/profile`
- `player/12345/loadout/1`
- `guild/9001/config`

Benefits:

- Easy `ListKeysAsync()` filtering.
- Predictable cleanup and migration targeting.
- Less reliance on scopes.

### Version-inside-value

```lua
{
    schemaVersion = 2,
    stats = {...},
    items = {...},
}
```

- Load path checks `schemaVersion`.
- Migration can happen in memory, then be written back once.

### Separate permanent from temporary

- Durable unlocks or inventory: standard data store.
- Temporary cache, lock, queue, or match state: memory store.

## Examples

### Keep one profile object per player

Bad pattern:

- `coins/<userId>`
- `inventory/<userId>`
- `settings/<userId>`

Better pattern:

```lua
{
    schemaVersion = 4,
    coins = 90,
    inventory = {"bow"},
    settings = {music = false},
}
```

### Use prefixes for profile variants

- `player/12345/profile/default`
- `player/12345/profile/mage`
- `player/12345/profile/tank`
