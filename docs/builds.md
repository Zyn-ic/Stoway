# Production Builds

Non-production ships as-is: debug console, test harnesses, op-signal bus.
Production strips them. What you get is the example without the test suite —
then you build your own commands or your own tests on the seams below.

## What gets stripped

| Remove | Why | Call-site edits |
|---|---|---|
| `src/client/StowayClientV3/Tests/` | Observer harnesses; also runs for every player via project mapping | None — nothing requires it |
| `src/client/StowayClientV3/Signals.luau` | Op-signal bus nothing fires in production | `init.luau`: drop the require, `StowayClient.Signals`, `GetSignals()`, and the `ClientController.Init` argument; `ClientController`: drop the signals parameter and `bindSignals` |
| `src/server/Services/StowayServerV3_0_0/Debug/` | Conch console (Studio only by design) | `Server.server.luau`: drop the require + `RegisterAll`; `Start.client.luau`: drop the conch mount block |

Keep `Libraries/PlayerServiceSignals` — that is the production player-lifecycle
bus, not test machinery.

## Build your own

- **Chat commands:** the `Debug/` folder shape is the template — one module,
  `RegisterAll(stoway)`, one call in `Server.server.luau`. Ship yours, or
  ship none and drive everything through routes.
- **Tests:** the `Tests/` observers are the template — subscribe, peek, print,
  delete before committing.

## Ship checklist

Full list in the [trust model](trust.md): console Studio-only, Add\*/Update
policy decided, debug output removed, Tools + skin prefabs in the published
place, persistence hooked up if needed.
