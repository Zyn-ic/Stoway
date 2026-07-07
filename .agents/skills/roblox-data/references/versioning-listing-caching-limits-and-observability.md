# Versioning, Listing, Caching, Limits, and Observability

## Key Concepts

- Standard data stores automatically create version history on the first write to a key in each UTC hour.
- Older overwritten versions expire 30 days after a newer write replaces them. The latest version does not expire.
- `ListVersionsAsync()`, `GetVersionAsync()`, and `RemoveVersionAsync()` operate on version history.
- `GetAsync()` uses a local cache for about four seconds by default.
- Listing and version APIs fetch current backend state and do not use the `GetAsync()` cache.
- `UpdateAsync()` consumes both read and write budget.

## Rules

- Use versioning as the rollback path for standard data stores, not extra backup keys.
- Prefer prefixes for organization and for `ListKeysAsync()` filtering.
- Use uncached reads only when freshness matters more than budget conservation.
- Check `GetRequestBudgetForRequestType()` before bursty durable work.
- Treat throttles and internal errors as retryable with backoff.
- Do not rely on Studio data-store access against live data unless that is intentionally configured.

## Patterns

### Restore near a known incident time

1. List versions for the key in descending order up to the target timestamp.
2. Load the closest valid version.
3. Overwrite the live key with that version.

### Prefix listing

- `player/`
- `guild/`
- `season/2026/`

Use list queries to target a family of keys instead of inventing many store names.

### Cache-aware read strategy

- Normal read path: cached `GetAsync()` for lower budget cost.
- Freshness-critical path: `GetAsync()` with caching disabled.
- Cross-server write-read path: avoid assuming another server sees the new value immediately.

## Limits

### Data shape

- Data store name: 50 characters max.
- Key name: 50 characters max.
- Scope: 50 characters max.
- Value size: 4,194,304 bytes per key after serialization.
- Metadata total size: 300 characters across key-value pairs.

### Current server request budgets

- Standard get: `60 + players * 10` per minute.
- Standard set/write family: `60 + players * 10` per minute.
- Ordered sorted listing: `5 + players * 2` per minute.
- Ordered set/write family: `30 + players * 5` per minute.
- List and version families are smaller and should be treated as expensive.

### Throughput

- Per-key read throughput: 25 MB per minute.
- Per-key write throughput: 4 MB per minute.
- Throughput is rounded up to the next kilobyte per request.

## Observability

- Use the Data Stores dashboard for storage usage, request count by API, request count by status, and quota-usage charts.
- Separate standard versus ordered views when debugging.
- Use dashboard status distributions to tell apart normal load, throttling, and backend errors.

## Examples

### Disable cache for a freshness-critical read

```lua
local options = Instance.new("DataStoreGetOptions")
options.UseCache = false

local value = store:GetAsync(key, options)
```

### Budget gate before a write burst

```lua
local budget = DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
if budget <= 0 then
    return false
end
```
