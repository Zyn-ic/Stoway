# Trust model

After this page you know what the server enforces, what canon leaves open,
and what to close before shipping.

The server owns the truth. The client predicts and converges.

## What the server enforces

- Every request goes through the same route as server code, under a
  per-player lock.
- CoreStore validates slots, amounts, capacity, and stacking.
- `Drop` honors `Droppable`; templates must exist in `ServerStorage.Tools`.
- The debug console exists only in Studio (no remotes, role, or commands in
  a live server).

## What canon leaves open (decide before shipping)

!!! warning "Client-supplied items and metadata"
    The client-facing `AddItem`, `AddToBackpack`, `AddToHotbar`, and
    `UpdateMetadata` events forward `input` / `updates` to the routes with no
    key policy. A modified client can mint any template tool with any
    metadata, or rewrite metadata on its own items. Remove those listeners, or
    enforce a server-side allowlist/denylist before you rely on any
    metadata-driven rule.

- Failure corrections (a FullSync behind every failed op) are not rate
  limited; only `RequestInventorySync` has the 15 s per-player throttle.
- Nothing persists. State lives for the session (see
  [Persistence](persistence.md)).

## Ship checklist

- [ ] Console confirmed Studio-only
- [ ] Client Add*/UpdateMetadata removed or policy-gated
- [ ] Debug prints/warns removed
- [ ] Tools folder and skin prefabs present in the published place
- [ ] Persistence hooked up, if your game needs it
