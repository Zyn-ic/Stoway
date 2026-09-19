--!strict

--@author: yyumchi
--@date: 2026-09-19
--[[@description:
	Client entry LocalScript. Plain (non-init) file so Rojo syncs it as
	a regular child named "Start", sibling of StowayClientV3 — never
	fused with the directory (see init.client.luau removal).
]]

-- WaitForChild: siblings replicate separately, so Start can win the
-- race against the StowayClientV3 module on join. Never index directly.
local StowayClient = require(script.Parent:WaitForChild("StowayClientV3"))

StowayClient.Init()
