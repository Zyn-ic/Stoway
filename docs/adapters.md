# Adapters

`registerAdapter` is the real server seam. Every route result — success or
failure, client-originated or not — is dispatched to every registered
adapter as `{ operation, replicate, result }`. Communications (the QuickNet
bridge) is just one adapter.

A 15-line adapter that logs every failure:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = game:GetService("ServerScriptService"):WaitForChild("Services")
local Stoway = require(Services:WaitForChild("StowayServerV3_0_0"))

Stoway.registerAdapter(function(player, signal)
	if not signal.result.ok then
		warn(("[Audit] %s failed for %s: %s"):format(
			signal.operation,
			player.Name,
			signal.result.error.message
		))
	end
end)
```

The same seam drives persistence (save on `removePlayer`'s returned state),
analytics, or admin tooling — without touching routes. See
[Persistence](persistence.md).
